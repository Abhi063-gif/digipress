import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/services/pdf_render_service.dart';
import '../../../core/widgets/skeleton.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PageCurlViewer
//
//  A high-fidelity page-turn viewer implementing a realistic diagonal curl
//  from the top-right corner, similar to Apple Books / high-end readers.
//
//  Key features:
//    • Bezier-curved page deformation (no cylindrical rod)
//    • Diagonal peeling revealed via CustomPainter
//    • Dynamic highlights and depth-based shadows
//    • Ultra-smooth zoom with gesture priority handling
// ─────────────────────────────────────────────────────────────────────────────

class PageCurlViewer extends StatefulWidget {
  final PdfRenderService renderer;
  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const PageCurlViewer({
    super.key,
    required this.renderer,
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  State<PageCurlViewer> createState() => PageCurlViewerState();
}

enum FlipDirection { forward, backward, none }

class PageCurlViewerState extends State<PageCurlViewer>
    with SingleTickerProviderStateMixin {
  late int _page;
  int? _nextPage;
  FlipDirection _flipDir = FlipDirection.none;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _ctrl;
  double _dragX = 0.0;
  double _startX = 0.0;
  double _startY = 0.0; // used to reject vertical-dominant swipes
  bool _isDragging = false;

  // ── Zoom State ────────────────────────────────────────────────────────────
  // Manual zoom/pan — replaces TransformationController + InteractiveViewer.
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  Offset _panOffset = Offset.zero;
  Offset _basePanOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _page = widget.page;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _ctrl.addListener(() => setState(() {}));
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && _nextPage != null) {
        debugPrint('[CURL] animation complete to page $_nextPage');
        setState(() {
          _page = _nextPage!;
          _nextPage = null;
          _flipDir = FlipDirection.none;
          _isDragging = false;
        });
        widget.onPageChanged(_page);
        widget.renderer.updateWindow(_page);
      } else if (status == AnimationStatus.dismissed ||
          status == AnimationStatus.completed) {
        if (mounted) setState(() => _isDragging = false);
      }
    });
    widget.renderer.updateWindow(_page);
  }

  @override
  void didUpdateWidget(PageCurlViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // REACTIVE SYNC: If the parent page changed, animate to it
    if (widget.page != oldWidget.page && widget.page != _page) {
      debugPrint(
        '[CURL] Page sync update: ${oldWidget.page} -> ${widget.page}',
      );
      _triggerFlip(widget.page);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerFlip(int targetPage) {
    debugPrint('[CURL] animation start to page $targetPage');
    if (targetPage == _page ||
        targetPage < 1 ||
        targetPage > widget.totalPages) {
      return;
    }
    // Guard: already animating to this exact target
    if (_nextPage == targetPage && _ctrl.isAnimating) return;

    if (_ctrl.isAnimating) _ctrl.stop();

    // Reset zoom/pan before flipping
    setState(() {
      _currentScale = 1.0;
      _panOffset = Offset.zero;
      _nextPage = targetPage;
      _flipDir = targetPage > _page
          ? FlipDirection.forward
          : FlipDirection.backward;
      _isDragging = false;
    });
    _ctrl.forward(from: 0);
  }

  // ── Gesture Handlers ──────────────────────────────────────────────────────
  //
  // Key design: NO edge-zone restriction.
  // Direction is inferred from swipe movement (left=forward, right=backward).
  // _isDragging is NOT set in onScaleStart; we wait for clear horizontal
  // intent in onScaleUpdate (dx > 20px AND dx > dy) to avoid false triggers
  // from vertical scrolls or accidental taps.

  void _onScaleStart(ScaleStartDetails details) {
    if (_ctrl.isAnimating) return;

    _gestureStartFocal = details.localFocalPoint;
    _basePanOffset = _panOffset;
    _baseScale = _currentScale;

    if (details.pointerCount >= 2) {
      debugPrint('[CURL] Pinch-zoom started (×$_currentScale)');
      return;
    }

    if (_currentScale > 1.01) {
      debugPrint('[CURL] Pan-while-zoomed started');
      return;
    }

    // Snapshot start position — direction determined in _onScaleUpdate
    // once horizontal intent is clear (avoids triggering on vertical scrolls).
    _startX = details.localFocalPoint.dx;
    _startY = details.localFocalPoint.dy;
    _dragX = _startX;
    // Do NOT set _isDragging here.
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      // Multi-finger pinch zoom
      final newScale = (_baseScale * details.scale).clamp(1.0, 5.0);
      final delta = details.localFocalPoint - _gestureStartFocal;
      setState(() {
        _currentScale = newScale;
        if (newScale > 1.0) {
          _panOffset = _basePanOffset + delta;
          _clampPanOffset();
        }
      });
      return;
    }

    if (_currentScale > 1.01) {
      // Pan while zoomed
      final delta = details.localFocalPoint - _gestureStartFocal;
      setState(() {
        _panOffset = _basePanOffset + delta;
        _clampPanOffset();
      });
      return;
    }

    final dx = details.localFocalPoint.dx - _startX;
    final dy = details.localFocalPoint.dy - _startY;

    if (_isDragging) {
      // Already committed — just track finger position
      setState(() => _dragX = details.localFocalPoint.dx);
      return;
    }

    // Determine intent:
    // • Need at least 5px horizontal movement (was 8px)
    // • Horizontal must dominate over vertical (ratio 1.2:1)
    if (dx.abs() < 5) return;
    if (dy.abs() > dx.abs() * 1.1) {
      // If it's vertical-ish, don't trigger curl
      return;
    }

    // Leftward swipe → forward (next page)
    if (dx < 0 && _page < widget.totalPages) {
      debugPrint('[CURL] Swipe-COMMIT Forward (dx=${dx.toStringAsFixed(1)})');
      setState(() {
        _flipDir = FlipDirection.forward;
        _nextPage = _page + 1;
        _isDragging = true;
        _dragX = details.localFocalPoint.dx;
      });
    }
    // Rightward swipe → backward (previous page)
    else if (dx > 0 && _page > 1) {
      debugPrint('[CURL] Swipe-COMMIT Backward (dx=${dx.toStringAsFixed(1)})');
      setState(() {
        _flipDir = FlipDirection.backward;
        _nextPage = _page - 1;
        _isDragging = true;
        _dragX = details.localFocalPoint.dx;
      });
    }
  }

  void _clampPanOffset() {
    if (_currentScale <= 1.0) {
      _panOffset = Offset.zero;
      return;
    }

    final size = context.size;
    if (size == null) return;

    final currentImg = widget.renderer.getImage(_page);
    double w = size.width;
    double h = size.height;

    if (currentImg != null) {
      double scale = min(size.width / currentImg.width, size.height / currentImg.height);
      w = currentImg.width * scale;
      h = currentImg.height * scale;
    }

    // Max offset is half of the "overflowing" part of the rendered image
    final maxDx = (w * (_currentScale - 1)) / 2;
    final maxDy = (h * (_currentScale - 1)) / 2;

    setState(() {
      _panOffset = Offset(
        _panOffset.dx.clamp(-maxDx, maxDx),
        _panOffset.dy.clamp(-maxDy, maxDy),
      );
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Snap zoom back if nearly 1×
    if (_currentScale < 1.01) {
      setState(() {
        _currentScale = 1.0;
        _panOffset = Offset.zero;
      });
    } else {
      // Clamp pan offset on end to ensure we're not out of bounds
      _clampPanOffset();
    }

    if (!_isDragging) return;

    final width = context.size?.width ?? MediaQuery.of(context).size.width;
    final distance = (_dragX - _startX).abs();
    final progress = (distance / (width * 0.65)).clamp(0.0, 1.0);

    // Flick detection: high velocity can trigger a flip even with short distance
    final velocityX = details.velocity.pixelsPerSecond.dx;
    final isFlickForward =
        _flipDir == FlipDirection.forward && velocityX < -500;
    final isFlickBackward =
        _flipDir == FlipDirection.backward && velocityX > 500;
    final isFlick = isFlickForward || isFlickBackward;

    debugPrint(
      '[CURL] onScaleEnd: dist=${distance.toStringAsFixed(1)} prog=${progress.toStringAsFixed(2)} v=${velocityX.toStringAsFixed(0)}',
    );
    setState(() => _isDragging = false);

    if (progress > 0.15 || isFlick) {
      // Far enough OR fast enough — complete the flip
      _ctrl.forward(from: progress.clamp(0.0, 1.0));
    } else {
      // Not far enough — snap back
      _ctrl.reverse(from: progress.clamp(0.0, 1.0));
      setState(() {
        _nextPage = null;
        _flipDir = FlipDirection.none;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.renderer,
      builder: (context, _) {
        final currentImg = widget.renderer.getImage(_page);
        final nextImg = _nextPage != null
            ? widget.renderer.getImage(_nextPage!)
            : null;
        final isTurning = _isDragging || _ctrl.isAnimating;

        if (currentImg == null) widget.renderer.ensurePage(_page);
        if (_nextPage != null && nextImg == null) {
          widget.renderer.ensurePage(_nextPage!);
        }

        // ── GestureDetector is the ROOT widget ────────────────────────────
        // HitTestBehavior.opaque absorbs ALL pointer events before any parent
        // Scrollable can claim them. onScale* handles both curl and pinch-zoom
        // in a single recognizer — no arena conflict.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {},
          onDoubleTap: () {
            if (_ctrl.isAnimating) return;
            setState(() {
              if (_currentScale > 1.01) {
                _currentScale = 1.0;
                _panOffset = Offset.zero;
              } else {
                _currentScale = 2.5;
                _panOffset = Offset.zero;
              }
            });
          },
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Layer 1: Page image with manual zoom/pan ───────────────
              ClipRect(
                child: Transform(
                  transform: Matrix4.translationValues(
                    _panOffset.dx,
                    _panOffset.dy,
                    0,
                  )..scaleByDouble(_currentScale, _currentScale, 1.0, 1.0),
                  alignment: Alignment.center,
                  child: Center(
                    child: currentImg != null
                        ? RawImage(
                            image: currentImg,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          )
                        : const _PageShimmer(),
                  ),
                ),
              ),

              // ── Layer 2: Curl overlay — purely visual, no input ────────
              if (isTurning && currentImg != null)
                IgnorePointer(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: PageCurlPainter(
                      currentImage: currentImg,
                      nextImage: nextImg,
                      progress: _isDragging ? null : _ctrl.value,
                      dragX: _isDragging ? _dragX : null,
                      startX: _isDragging ? _startX : null,
                      direction: _flipDir,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painter: Realistic Diagonal Page Curl
// ─────────────────────────────────────────────────────────────────────────────

class PageCurlPainter extends CustomPainter {
  final ui.Image currentImage;
  final ui.Image? nextImage;
  final double? progress; // 0.0 to 1.0
  final double? dragX;
  final double? startX;
  final FlipDirection direction;

  PageCurlPainter({
    required this.currentImage,
    this.nextImage,
    this.progress,
    this.dragX,
    this.startX,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = ui.FilterQuality.high;

    // 1. Calculate progress (t)
    double t;
    if (dragX != null && startX != null) {
      final distance = direction == FlipDirection.forward
          ? (startX! - dragX!)
          : (dragX! - startX!);
      t = (distance / (size.width * 0.85)).clamp(0.0, 1.0);
    } else {
      t = progress ?? 0.0;
    }

    // 2. Base case: no turn
    if (t <= 0.001 || direction == FlipDirection.none) {
      _drawImage(canvas, size, currentImage, paint);
      return;
    }

    // 3. Calculate rendered bounds of the image (BoxFit.contain)
    double imgScale = min(size.width / currentImage.width, size.height / currentImage.height);
    double w = currentImage.width * imgScale;
    double h = currentImage.height * imgScale;
    double left = (size.width - w) / 2;
    double top = (size.height - h) / 2;
    final rect = Rect.fromLTWH(left, top, w, h);

    // 4. Draw casting shadow on the flat page underneath
    // The flat page underneath is on the right of the pivot 'left'.
    final double shadowOpacity = (sin(t * pi) * 0.28).clamp(0.0, 1.0);
    if (shadowOpacity > 0.0) {
      final shadowPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(left, top),
          Offset(left + w * 0.4 * (1 - t + 0.2), top),
          [
            Colors.black.withValues(alpha: shadowOpacity),
            Colors.transparent,
          ],
        );
      canvas.save();
      canvas.clipRect(rect);
      canvas.drawRect(rect, shadowPaint);
      canvas.restore();
    }

    // 5. Draw flat page underneath
    if (direction == FlipDirection.forward) {
      if (nextImage != null) {
        _drawImage(canvas, size, nextImage!, paint);
      } else {
        canvas.drawRect(
          rect,
          Paint()..color = const Color(0xFFF8F6F1),
        );
      }
    } else {
      _drawImage(canvas, size, currentImage, paint);
    }

    // 6. Draw 3D Rotating Page
    final double angle = direction == FlipDirection.forward
        ? -t * pi
        : -pi + t * pi;

    canvas.save();
    
    // Clip to canvas area
    canvas.clipRect(Offset.zero & size);

    final matrix = Matrix4.identity()
      ..translate(left, top + h / 2) // move pivot to origin
      ..setEntry(3, 2, -0.0012) // 3D perspective
      ..rotateY(angle) // rotate around Y-axis
      ..translate(-left, -(top + h / 2)); // move back
      
    canvas.transform(matrix.storage);

    // Draw the rotating page content
    if (direction == FlipDirection.forward) {
      _drawImage(canvas, size, currentImage, paint);
    } else {
      if (nextImage != null) {
        _drawImage(canvas, size, nextImage!, paint);
      }
    }

    // Draw shading overlay on the rotating page to simulate 3D lighting
    final double shadingOpacity = (sin(t * pi) * 0.42).clamp(0.0, 1.0);
    if (shadingOpacity > 0.0) {
      final shadingPaint = Paint()
        ..color = Colors.black.withValues(alpha: shadingOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, shadingPaint);
    }

    // Draw page edge line highlight for a realistic paper edge
    final edgePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08 * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, edgePaint);

    canvas.restore();
  }

  void _drawImage(Canvas canvas, Size size, ui.Image img, Paint paint) {
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    double scale = min(size.width / img.width, size.height / img.height);
    double w = img.width * scale;
    double h = img.height * scale;
    final dst = Rect.fromLTWH(
      (size.width - w) / 2,
      (size.height - h) / 2,
      w,
      h,
    );
    canvas.drawImageRect(img, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant PageCurlPainter oldDelegate) => true;
}

class _PageShimmer extends StatelessWidget {
  const _PageShimmer();

  @override
  Widget build(BuildContext context) {
    // NOTE: This widget is placed inside a Center → no unbounded height.
    // Use fixed heights only; Expanded is not valid here (no Flex ancestor
    // with a finite height constraint at this call-site).
    return const Shimmer(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkeletonBox(height: 20, radius: 4),
            SizedBox(height: 16),
            SkeletonBox(height: 12, radius: 4),
            SizedBox(height: 8),
            SkeletonBox(width: 200, height: 12, radius: 4),
            SizedBox(height: 32),
            SkeletonBox(height: 120, radius: 8),
          ],
        ),
      ),
    );
  }
}

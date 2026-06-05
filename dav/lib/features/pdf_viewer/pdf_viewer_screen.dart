import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/services/api_service.dart';
import '../../core/services/cache_manager.dart';
import '../../core/services/download_manager.dart';
import '../../core/services/local_db_service.dart';
import '../../core/services/pdf_render_service.dart';
import '../../core/providers/pdf_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/skeleton.dart';
import 'widgets/page_curl_viewer.dart';
import 'package:provider/provider.dart';
import 'package:background_downloader/background_downloader.dart';
import 'dart:async';

// ─────────────────────────────────────────────────────────────────────────────
//  Constants
// ─────────────────────────────────────────────────────────────────────────────
const _deepLinkBase = 'https://digipress.app/pdf';

// ─────────────────────────────────────────────────────────────────────────────
//  Entry widget
// ─────────────────────────────────────────────────────────────────────────────
class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String pdfUrl;
  final int? pubId;
  final bool offlineMode;

  const PdfViewerScreen({
    super.key,
    required this.title,
    this.pdfUrl = '',
    this.pubId,
    this.offlineMode = false,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen>
    with TickerProviderStateMixin {
  // ── PDF controller ────────────────────────────────────────────────────────
  final PdfViewerController _pdfCtrl = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 1;
  bool _pdfLoading = true;

  // ── Bookmark ──────────────────────────────────────────────────────────────
  bool _isBookmarked = false;
  static const _prefKey = 'pdf_bookmark_';

  // ── Download ──────────────────────────────────────────────────────────────
  final bool _isDownloading = false;

  // ── View Mode Persistence ─────────────────────────────────────────────────
  static const _modePrefKey = 'pdf_view_mode';
  bool _isFlipMode = false;

  // ── Flip mode (PageCurlViewer + PdfRenderService) ─────────────────────────
  PdfRenderService? _renderSvc;
  final GlobalKey<PageCurlViewerState> _flipKey = GlobalKey();
  bool _flipReady = false;
  bool _isFlipAnimating = false; // lock: ignore chip taps while curl plays

  // ── Shared ────────────────────────────────────────────────────────────────
  bool _isImage = false;

  // Strip scroll
  final ScrollController _stripScroll = ScrollController();
  String _effectivePdfUrl = '';
  String? _taskId;
  String? _localPath;
  bool _isCached = false;

  @override
  void initState() {
    super.initState();
    _checkFileType();
    _loadBookmark();
    _effectivePdfUrl = _getEffectiveUrl(widget.pdfUrl);

    if (widget.pubId != null) {
      ApiService().saveHistory(widget.pubId!);
      LocalDbService().insertHistory({
        'pdf_id': widget.pubId!,
        'title': widget.title,
        'file_url': _effectivePdfUrl,
        'last_opened': DateTime.now().toIso8601String(),
        'category': 'Document',
      });
    }

    _setupInitialState();
  }

  Future<void> _setupInitialState() async {
    await _loadViewMode();
    await _initPdf();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isFlipMode = prefs.getBool(_modePrefKey) ?? true;
      });
    }
  }

  Future<void> _saveViewMode(bool isFlip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modePrefKey, isFlip);
  }

  Future<void> _initRenderService() async {
    debugPrint(
      '[PdfViewerScreen] _initRenderService called. path: $_localPath, mode: $_isFlipMode',
    );
    if (_renderSvc != null || _localPath == null) {
      debugPrint(
        '[PdfViewerScreen] _initRenderService early return: svc=${_renderSvc != null}, path=${_localPath != null}',
      );
      return;
    }

    await Future.delayed(const Duration(milliseconds: 100));

    _renderSvc = PdfRenderService();
    _renderSvc!.addListener(() {
      if (!mounted) return;
      setState(() {
        if (_renderSvc!.isOpen) _totalPages = _renderSvc!.totalPages;
      });
    });

    try {
      await _renderSvc!.open(_localPath!);
      if (mounted) {
        setState(() {
          _totalPages = _renderSvc!.totalPages;
          _flipReady = true;
        });
        _renderSvc!.updateWindow(_currentPage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pdfLoading = false);
        debugPrint('[PdfViewerScreen] Failed to init render service: $e');
      }
    }
  }

  Future<void> _initPdf() async {
    if (widget.offlineMode) {
      setState(() {
        _localPath = widget.pdfUrl;
        _isCached = true;
        _pdfLoading = false;
      });
      if (_isFlipMode) _initRenderService();
      return;
    }

    final pdfProvider = context.read<PdfProvider>();
    final cachedFile = await CacheManager().getCachedFile(_effectivePdfUrl);

    if (cachedFile != null || pdfProvider.isCached(_effectivePdfUrl)) {
      final file =
          cachedFile ?? await CacheManager().getCachedFile(_effectivePdfUrl);
      if (file != null && mounted) {
        setState(() {
          _localPath = file.path;
          _isCached = true;
          _pdfLoading = false;
        });
        if (_isFlipMode) {
          _initRenderService();
        }
      }
    } else {
      if (mounted) {
        final pdfProvider = context.read<PdfProvider>();
        final id = await pdfProvider.download(
          _effectivePdfUrl,
          title: widget.title,
        );
        setState(() {
          _taskId = id;
        });
      }
    }
  }

  void _checkFileType() {
    final url = widget.pdfUrl.toLowerCase();
    if (url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.webp')) {
      setState(() {
        _isImage = true;
        _pdfLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfCtrl.dispose();
    _stripScroll.dispose();
    _renderSvc?.dispose();
    super.dispose();
  }

  // ── Bookmark persistence ──────────────────────────────────────────────────
  String get _bookmarkPrefKey => '$_prefKey${widget.pubId ?? widget.title}';

  Future<void> _loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isBookmarked = prefs.getBool(_bookmarkPrefKey) ?? false);
    final savedPage = prefs.getInt('${_bookmarkPrefKey}_page') ?? 1;
    if (_isBookmarked && savedPage > 1) {
      if (mounted) setState(() => _currentPage = savedPage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pdfCtrl.jumpToPage(savedPage);
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final newVal = !_isBookmarked;
    await prefs.setBool(_bookmarkPrefKey, newVal);
    await prefs.setInt('${_bookmarkPrefKey}_page', _currentPage);
    setState(() => _isBookmarked = newVal);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newVal
                ? 'Bookmarked — page $_currentPage saved'
                : 'Bookmark removed',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: newVal ? AppColors.primary : AppColors.textSecondary,
        ),
      );
    }
  }

  // ── Share ─────────────────────────────────────────────────────────────────
  Future<void> _handleShare() async {
    final link = '$_deepLinkBase?id=${widget.pubId ?? 0}';
    Share.share(
      '📄 Check out "${widget.title}" on DigiPress!\n\n$link',
      subject: widget.title,
    );
    if (widget.pubId != null) ApiService().logShare(widget.pubId!);
  }

  // ── Download ──────────────────────────────────────────────────────────────
  Future<void> _handleDownload() async {
    if (_isCached && _localPath != null) {
      final success = await DownloadManager().copyToPublicDownloads(
        _localPath!,
        widget.title,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Saved to device Downloads'
                  : 'Failed to save to Downloads',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (success && widget.pubId != null) {
        ApiService().saveDownload(widget.pubId!);
        LocalDbService().insertDownload({
          'pdf_id': widget.pubId!,
          'title': widget.title,
          'file_url': _effectivePdfUrl,
          'local_path': _localPath!,
          'category': 'Document',
          'download_timestamp': DateTime.now().toIso8601String(),
        });
      }
      return;
    }

    final id = await DownloadManager().downloadPdfExplicit(
      _effectivePdfUrl,
      title: widget.title,
      pubId: widget.pubId,
    );
    setState(() => _taskId = id);

    if (widget.pubId != null) {
      final expectedPath = await CacheManager().getLocalPath(_effectivePdfUrl);
      ApiService().saveDownload(widget.pubId!);
      LocalDbService().insertDownload({
        'pdf_id': widget.pubId!,
        'title': widget.title,
        'file_url': _effectivePdfUrl,
        'local_path': expectedPath,
        'category': 'Document',
        'download_timestamp': DateTime.now().toIso8601String(),
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download started to device gallery'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Navigate to page ──────────────────────────────────────────────────────
  //
  // FIX: Added _scrollStripToPage call (was missing).
  // In flip mode, we only call setState — PageCurlViewer.didUpdateWidget
  // detects widget.page changed and calls _triggerFlip, which runs the
  // animated curl. Do NOT call _pdfCtrl.jumpToPage in flip mode.
  void _goToPage(int page) {
    debugPrint(
      '[PdfViewerScreen] _goToPage($page), mode: $_isFlipMode, hasState: ${_flipKey.currentState != null}',
    );
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    // Animation lock: while a curl is playing, ignore new chip taps.
    // This prevents rapid taps from skipping pages or corrupting state.
    if (_isFlipMode && _isFlipAnimating) {
      debugPrint('[PdfViewerScreen] _goToPage($page) blocked — animation in progress');
      return;
    }

    if (_isFlipMode) _isFlipAnimating = true;
    setState(() => _currentPage = page);

    if (!_isFlipMode) {
      _pdfCtrl.jumpToPage(page);
    }

    _scrollStripToPage(page);
  }

  void _scrollStripToPage(int page) {
    const chipW = 38.0;
    final offset = (page - 1) * chipW - (chipW * 2);
    if (_stripScroll.hasClients) {
      _stripScroll.animateTo(
        offset.clamp(0.0, _stripScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  String? _pdfError;

  @override
  Widget build(BuildContext context) {
    final pdfProvider = context.watch<PdfProvider>();

    if (!_isCached &&
        (_taskId != null || pdfProvider.isCached(_effectivePdfUrl))) {
      final update = _taskId != null ? pdfProvider.getUpdate(_taskId!) : null;
      final isComplete =
          (update is TaskStatusUpdate &&
              update.status == TaskStatus.complete) ||
          pdfProvider.isCached(_effectivePdfUrl);

      if (isComplete) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final file = await CacheManager().getCachedFile(_effectivePdfUrl);
          if (file != null && mounted) {
            setState(() {
              _localPath = file.path;
              _isCached = true;
              _pdfLoading = false;
            });
            if (_isFlipMode) _initRenderService();
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildPdfArea()),
          _buildPageStrip(),
          if (_taskId != null &&
              !pdfProvider.isCached(_effectivePdfUrl) &&
              !_isCached)
            _DownloadBar(progress: pdfProvider.getProgress(_taskId!)),
          _buildBottomActions(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black12,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.textPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (!_pdfLoading && !_isImage && _totalPages > 1) ...[
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                _isFlipMode ? Icons.auto_stories_rounded : Icons.view_day_rounded,
                key: ValueKey(_isFlipMode),
                color: AppColors.primary,
                size: 24,
              ),
            ),
            onPressed: () async {
              final newMode = !_isFlipMode;
              if (newMode) {
                // Switch to Flip Mode
                setState(() => _isFlipMode = true);
                _saveViewMode(true);
                if (_renderSvc == null && _localPath != null) {
                  setState(() => _pdfLoading = true);
                  await _initRenderService();
                  setState(() => _pdfLoading = false);
                }
              } else {
                // Switch to Normal Mode
                setState(() => _isFlipMode = false);
                _saveViewMode(false);
                _pdfCtrl.zoomLevel = 1.0;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _pdfCtrl.jumpToPage(_currentPage);
                });
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ActionBtn(
              icon: Icons.ios_share_rounded,
              label: 'Share',
              onTap: _handleShare,
            ),
            _ActionBtn(
              icon: _isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: _isBookmarked ? 'Bookmarked' : 'Bookmark',
              color: _isBookmarked ? AppColors.primary : null,
              onTap: _toggleBookmark,
            ),
            _ActionBtn(
              icon: Icons.download_rounded,
              label: 'Download',
              loading: _isDownloading,
              onTap: _isDownloading ? null : _handleDownload,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageStrip() {
    if (_isImage || _totalPages <= 1) return const SizedBox.shrink();
    return Container(
      height: 60,
      color: Colors.white,
      child: ListView.builder(
        controller: _stripScroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _totalPages,
        itemBuilder: (_, i) {
          final page = i + 1;
          final isActive = page == _currentPage;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              debugPrint('[PdfViewerScreen] Chip tapped: page $page');
              _goToPage(page);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 8),
              width: 36,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? AppColors.primary : const Color(0xFFE5E7EB),
                  width: 1.2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  '$page',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onPdfLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _totalPages = details.document.pages.count;
      _currentPage = _pdfCtrl.pageNumber > 0 ? _pdfCtrl.pageNumber : 1;
      _pdfLoading = false;
    });
  }

  void _onPdfError(PdfDocumentLoadFailedDetails details) {
    debugPrint('PDF LOAD ERROR: ${details.error} - ${details.description}');
    debugPrint('FAILED URL: ${widget.pdfUrl}');
    setState(() {
      _pdfError = 'Could not load PDF.\n${details.description}';
      _pdfLoading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${details.description}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('PDF Load Failed'),
                  content: Text(
                    'URL: ${widget.pdfUrl}\n\nError: ${details.description}',
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() => _currentPage = details.newPageNumber);
    _scrollStripToPage(details.newPageNumber);
    if (_isBookmarked) {
      SharedPreferences.getInstance().then(
        (p) => p.setInt('${_bookmarkPrefKey}_page', _currentPage),
      );
    }
  }

  String _getEffectiveUrl(String url) {
    String trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http')) {
      if (trimmed.contains('cloudinary.com')) {
        return trimmed.replaceFirst('http://', 'https://');
      }
      return trimmed;
    }
    final base = ApiService.baseUrl.endsWith('/')
        ? ApiService.baseUrl.substring(0, ApiService.baseUrl.length - 1)
        : ApiService.baseUrl;
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$base$path';
  }

  Widget _buildPdfArea() {
    if (widget.pdfUrl.isEmpty) {
      return _buildPlaceholder('No PDF attached to this publication.');
    }
    if (_pdfError != null) return _buildPlaceholder(_pdfError!);

    if (_isImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            _effectivePdfUrl,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Shimmer(
                child: SkeletonBox(height: double.infinity, radius: 0),
              );
            },
            errorBuilder: (context, error, stackTrace) =>
                _buildPlaceholder('Could not load image.'),
          ),
        ),
      );
    }

    if (!_isCached) {
      final pdfProvider = context.watch<PdfProvider>();
      final progress = _taskId != null
          ? pdfProvider.getProgress(_taskId!)
          : 0.0;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.downloading_rounded,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Downloading document for offline viewing...',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                color: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Text('${(progress * 100).toStringAsFixed(0)}%'),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isFlipMode)
          _buildFlipPageView()
        else
          SfPdfViewer.file(
            File(_localPath!),
            controller: _pdfCtrl,
            enableDoubleTapZooming: true,
            enableTextSelection: false,
            pageLayoutMode: PdfPageLayoutMode.continuous,
            scrollDirection: PdfScrollDirection.vertical,
            canShowScrollHead: false,
            canShowScrollStatus: false,
            canShowPaginationDialog: false,
            onDocumentLoaded: _onPdfLoaded,
            onDocumentLoadFailed: _onPdfError,
            onPageChanged: _onPageChanged,
          ),
        if (_pdfLoading)
          Positioned.fill(
            child: Shimmer(
              child: Container(
                color: const Color(0xFFEEEEEE),
                padding: const EdgeInsets.all(20),
                child: const SkeletonBox(height: double.infinity, radius: 8),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the premium book-flip view.
  ///
  /// FIX: Wrapped in [NotificationListener] that returns `true` for every
  /// [ScrollNotification]. This prevents any scroll notification from
  /// bubbling up to ancestor Scrollables, eliminating "ScrollIdentify: on
  /// fling" logs that were caused by parent scroll containers winning the
  /// gesture arena.
  ///
  /// The primary gesture fix lives in [PageCurlViewer] itself, which now
  /// wraps its entire surface in a [GestureDetector] with
  /// [HitTestBehavior.opaque] + [onScaleStart/Update/End].
  Widget _buildFlipPageView() {
    if (_renderSvc?.error != null) {
      return _buildPlaceholder(_renderSvc!.error!);
    }

    if (!_flipReady || _renderSvc == null) {
      return const _PageShimmerFull();
    }

    // ── Scroll isolation ──────────────────────────────────────────────────
    // NotificationListener absorbs all ScrollNotifications so no parent
    // ListView / SingleChildScrollView can intercept fling events.
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true, // absorb — do not bubble
      child: PageCurlViewer(
        key: _flipKey,
        renderer: _renderSvc!,
        page: _currentPage,
        totalPages: _totalPages,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
            _isFlipAnimating = false; // unlock: animation completed
          });
          _scrollStripToPage(page);
          if (_isBookmarked) {
            SharedPreferences.getInstance().then(
              (p) => p.setInt('${_bookmarkPrefKey}_page', page),
            );
          }
        },
      ),
    );
  }

  Widget _buildPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_rounded,
              size: 72,
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Full-screen shimmer while PdfRenderService opens the document
// ─────────────────────────────────────────────────────────────────────────────
class _PageShimmerFull extends StatelessWidget {
  const _PageShimmerFull();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        color: const Color(0xFFEEEEEE),
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            SkeletonBox(height: 18, radius: 4),
            SizedBox(height: 16),
            SkeletonBox(height: 12, radius: 4),
            SizedBox(height: 8),
            SkeletonBox(width: 200, height: 12, radius: 4),
            SizedBox(height: 8),
            SkeletonBox(height: 12, radius: 4),
            SizedBox(height: 32),
            SkeletonBox(height: 130, radius: 6),
            SizedBox(height: 24),
            SkeletonBox(height: 12, radius: 4),
            SizedBox(height: 8),
            SkeletonBox(width: 180, height: 12, radius: 4),
          ],
        ),
      ),
    );
  }
}

class _DownloadBar extends StatelessWidget {
  final double progress;
  const _DownloadBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.download_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                'Downloading…',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 4,
              color: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom action button
// ─────────────────────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.color,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = color ?? AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    icon,
                    size: 22,
                    color: onTap == null ? AppColors.textHint : active,
                  ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: onTap == null ? AppColors.textHint : active,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



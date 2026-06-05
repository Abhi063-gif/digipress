import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

/// Renders individual PDF pages as JPEG byte arrays using native platform APIs.
///
/// Architecture:
///   • One [PdfDocument] is opened for the entire session.
///   • Only [windowSize] pages around the current page are kept in [_cache].
///   • Pages outside the window are evicted automatically by [updateWindow].
///   • All rendering is done via pdfx (Android PdfRenderer / iOS PDFKit),
///     running on a background isolate — no UI-thread stalls.
///
/// Usage:
///   final svc = PdfRenderService();
///   await svc.open(filePath);          // open document
///   await svc.updateWindow(1);          // preload first ±windowSize pages
///   final bytes = svc.cached(1);       // get rendered bytes (may be null)
///   svc.addListener(() { ... });        // rebuild when a page finishes
class PdfRenderService extends ChangeNotifier {
  // ── Internal state ──────────────────────────────────────────────────────────
  PdfDocument? _doc;
  final Map<int, Uint8List> _cache   = {};
  final Map<int, ui.Image>  _imageCache = {};
  final Set<int>            _pending = {}; 
  bool                      _isRendering = false;
  final List<int>           _renderQueue = [];

  int     _totalPages = 0;
  bool    _isOpen     = false;
  bool    _disposed   = false;
  String? _error;
  /// Last path successfully opened — avoids redundant native reopen.
  String? _openPath;
  bool    _openInProgress = false;

  // ── Public getters ───────────────────────────────────────────────────────────
  int     get totalPages => _totalPages;
  bool    get isOpen     => _isOpen;
  String? get error      => _error;

  // ── Open / Close ─────────────────────────────────────────────────────────────

  /// Opens the PDF at [filePath].  Must be a local file path (not a URL).
  ///
  /// Idempotent: if [filePath] is already the open document, does nothing
  /// (no native reopen). Serialized so concurrent callers cannot double-open.
  Future<void> open(String filePath) async {
    if (_disposed) return;
    if (_isOpen && _openPath == filePath && _doc != null) {
      debugPrint('[PdfRenderService] already open, skip: $filePath');
      return;
    }

    while (_openInProgress) {
      await Future<void>.delayed(const Duration(milliseconds: 8));
      if (_disposed) return;
    }
    _openInProgress = true;

    debugPrint('[PdfRenderService] opening: $filePath');
    try {
      if (_doc != null) {
        try {
          await _doc!.close();
        } catch (_) {}
        _doc = null;
      }
      _cache.clear();
      _imageCache.clear();
      _pending.clear();
      _renderQueue.clear();
      _isRendering = false;

      _doc = await PdfDocument.openFile(filePath);
      _totalPages = _doc!.pagesCount;
      _openPath = filePath;
      debugPrint('[PdfRenderService] opened. pages: $_totalPages');
      _isOpen = true;
      _error = null;
      _notify();
    } catch (e) {
      _error = 'Could not open PDF: $e';
      _openPath = null;
      _isOpen = false;
      _doc = null;
      debugPrint('[PdfRenderService] open error: $e');
      _notify();
    } finally {
      _openInProgress = false;
    }
  }

  // ── Cache access ──────────────────────────────────────────────────────────────

  /// Returns cached JPEG bytes for [pageNumber], or null if not yet rendered.
  Uint8List? cached(int pageNumber) => _cache[pageNumber];

  /// Returns a decoded ui.Image for [pageNumber].
  ui.Image? getImage(int pageNumber) => _imageCache[pageNumber];

  /// True if [pageNumber] is already rendered and ready.
  bool isReady(int pageNumber) => _cache.containsKey(pageNumber);

  // ── Render control ────────────────────────────────────────────────────────────

  /// Triggers background rendering of [pageNumber] if not already cached.
  /// Returns without blocking; listeners are notified when done.
  void ensurePage(int pageNumber) {
    if (!_isOpen || _doc == null || _disposed) return;
    if (pageNumber < 1 || pageNumber > _totalPages) return;
    if (_cache.containsKey(pageNumber) ||
        _pending.contains(pageNumber) ||
        _renderQueue.contains(pageNumber)) return;

    _renderQueue.add(pageNumber);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isRendering || _renderQueue.isEmpty || _disposed || _doc == null) {
      return;
    }

    _isRendering = true;
    final pageNumber = _renderQueue.removeAt(0);
    _pending.add(pageNumber);

    try {
      debugPrint('[PdfRenderService] Rendering page $pageNumber...');
      final page = await _doc!.getPage(pageNumber);
      // Target ≈ 3500 px wide — 4K-equivalent quality for ultra-sharp zooming.
      // This provides absolute clarity even at maximum 5x zoom levels.
      const target = 3500.0;
      final scale = target / page.width;

      final img = await page.render(
        width: (page.width * scale).toInt().toDouble(),
        height: (page.height * scale).toInt().toDouble(),
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
        quality: 100,
      );
      await page.close();

      if (!_disposed && img != null) {
        _cache[pageNumber] = img.bytes;

        // Also decode to ui.Image for high-perf animations
        final codec = await ui.instantiateImageCodec(img.bytes);
        final frame = await codec.getNextFrame();
        if (!_disposed) {
          _imageCache[pageNumber] = frame.image;
          debugPrint('[PdfRenderService] Page $pageNumber ready.');
          _notify();
        }
      }
    } catch (e) {
      debugPrint('[PdfRenderService] render error page $pageNumber: $e');
    } finally {
      _pending.remove(pageNumber);
      _isRendering = false;
      // Process next in queue
      Future.microtask(_processQueue);
    }
  }

  // ── Sliding window ────────────────────────────────────────────────────────────

  /// Evicts pages outside [center ± windowSize] and preloads missing ones.
  /// Call this every time the current page changes.
  ///
  /// Default [windowSize] of 1 keeps three pages decoded (center ± 1) for smooth
  /// page-turn animation while conserving memory for high-res rendering.
  void updateWindow(int center, {int windowSize = 1}) {
    if (!_isOpen) return;
    final lo = (center - windowSize).clamp(1, _totalPages);
    final hi = (center + windowSize).clamp(1, _totalPages);

    // Evict pages that are outside the window
    _cache.removeWhere((p, _) => p < lo || p > hi);
    _imageCache.removeWhere((p, _) => p < lo || p > hi);

    // Render any missing pages in the window
    for (int p = lo; p <= hi; p++) {
      ensurePage(p);
    }
  }

  // ── ChangeNotifier helpers ────────────────────────────────────────────────────

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cache.clear();
    _imageCache.clear();
    _pending.clear();
    _renderQueue.clear();
    _openPath = null;
    _doc?.close();
    super.dispose();
  }
}

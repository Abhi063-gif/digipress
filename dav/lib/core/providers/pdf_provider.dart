import 'package:flutter/material.dart';
import 'package:background_downloader/background_downloader.dart';
import '../services/download_manager.dart';
import '../services/cache_manager.dart';

class PdfProvider with ChangeNotifier {
  final Map<String, TaskUpdate> _activeTasks = {};
  final Set<String> _cachedUrls = {};

  PdfProvider() {
    _init();
  }

  void _init() {
    DownloadManager().updateStream.listen((update) {
      _activeTasks[update.task.taskId] = update;
      
      if (update is TaskStatusUpdate) {
        if (update.status == TaskStatus.complete) {
          // When a download task completes, mark as cached
          if (update.task is DownloadTask) {
            _cachedUrls.add(update.task.url);
          }
          _activeTasks.remove(update.task.taskId);
        } else if (update.status == TaskStatus.failed || update.status == TaskStatus.canceled) {
          _activeTasks.remove(update.task.taskId);
        }
      }
      
      notifyListeners();
    });
  }

  /// Returns the latest update for a given task ID.
  TaskUpdate? getUpdate(String taskId) => _activeTasks[taskId];

  /// Returns the progress (0.0 to 1.0) for a given task ID.
  double getProgress(String taskId) {
    final update = _activeTasks[taskId];
    if (update is TaskProgressUpdate) {
      return update.progress;
    }
    return 0.0;
  }

  /// Checks if a task is currently active (running or paused).
  bool isTaskActive(String taskId) {
    final update = _activeTasks[taskId];
    if (update is TaskStatusUpdate) {
      return update.status == TaskStatus.running || update.status == TaskStatus.paused;
    }
    return _activeTasks.containsKey(taskId);
  }

  /// Refreshes the cache status for a URL.
  Future<void> checkCache(String url) async {
    final cached = await CacheManager().isFileCached(url);
    if (cached) {
      _cachedUrls.add(url);
      notifyListeners();
    }
  }

  bool isCached(String url) => _cachedUrls.contains(url);

  /// Starts a download and returns the taskId.
  Future<String> download(String url, {String? title}) async {
    final taskId = await DownloadManager().downloadPdf(url, title: title);
    notifyListeners();
    return taskId;
  }

  /// Starts an upload and returns the taskId.
  Future<String> upload({
    required String url,
    required String filePath,
    required Map<String, String> fields,
    required Map<String, String> headers,
  }) async {
    final taskId = await DownloadManager().uploadPdf(
      url: url,
      filePath: filePath,
      fields: fields,
      headers: headers,
    );
    notifyListeners();
    return taskId;
  }
}

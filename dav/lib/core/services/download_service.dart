import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadTask {
  final String url;
  final String destination;
  double progress;
  bool isCompleted;
  String? error;

  DownloadTask({
    required this.url,
    required this.destination,
    this.progress = 0,
    this.isCompleted = false,
    this.error,
  });
}

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final Map<String, DownloadTask> _activeTasks = {};
  
  // Stream to notify UI of progress updates
  final _progressController = StreamController<Map<String, DownloadTask>>.broadcast();
  Stream<Map<String, DownloadTask>> get progressStream => _progressController.stream;

  Map<String, DownloadTask> get activeTasks => _activeTasks;

  Future<String?> downloadPdf(String url, String fileName) async {
    if (_activeTasks.containsKey(url)) return null;

    try {
      final dir = await getApplicationDocumentsDirectory();
      // On Windows, getApplicationDocumentsDirectory() is typically C:\Users\user\Documents
      final dest = '${dir.path}/$fileName';
      
      final task = DownloadTask(url: url, destination: dest);
      _activeTasks[url] = task;
      _notify();

      await _dio.download(
        url,
        dest,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            task.progress = received / total;
            _notify();
          }
        },
      );

      task.isCompleted = true;
      task.progress = 1.0;
      _notify();
      
      // Remove from active tasks after a delay or keep for status
      Future.delayed(const Duration(seconds: 5), () {
        _activeTasks.remove(url);
        _notify();
      });

      return dest;
    } catch (e) {
      _activeTasks[url]?.error = e.toString();
      _notify();
      return null;
    }
  }

  void _notify() {
    _progressController.add(Map.from(_activeTasks));
  }

  bool isDownloading(String url) => _activeTasks.containsKey(url);
  double getProgress(String url) => _activeTasks[url]?.progress ?? 0;
}

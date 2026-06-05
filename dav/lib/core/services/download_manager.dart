import 'dart:async';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart' as dio;
import 'api_service.dart';
import 'cache_manager.dart';

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final _updateController = StreamController<TaskUpdate>.broadcast();
  Stream<TaskUpdate> get updateStream => _updateController.stream;

  final Map<String, String> _urlToTaskId = {};
  final Map<String, DownloadTask> _taskMap = {};

  /// Initializes the downloader and sets up listeners.
  Future<void> init() async {
    FileDownloader().configureNotification(
      running: const TaskNotification('Downloading', 'file: {filename}'),
      complete: const TaskNotification('Download Complete', 'file: {filename}'),
      error: const TaskNotification('Download Failed', 'file: {filename}'),
      paused: const TaskNotification('Paused', 'file: {filename}'),
      progressBar: true,
    );

    FileDownloader().configureNotificationForGroup(
      'upload',
      running: const TaskNotification('Uploading PDF...', 'file: {filename}'),
      complete: const TaskNotification('Upload Complete', 'file: {filename}'),
      error: const TaskNotification('Upload Failed', 'file: {filename}'),
      progressBar: true,
    );

    // Use updates stream for broader compatibility and reliability in v8
    FileDownloader().updates.listen((update) async {
      if (update is TaskStatusUpdate) {
        if (update.status == TaskStatus.complete) {
          // Check if this was an explicit download that needs to be copied to public folder
          // We can use the displayName or a metadata field to identify it
          if (update.task.group == 'explicit') {
            final path = await update.task.filePath();
            copyToPublicDownloads(path, update.task.displayName);
          } else if (update.task.group == 'upload' || update.task is UploadTask) {
            // Trigger backend notifications globally
            ApiService().notifyUploadSuccess();
            
            // Clean up the temporary upload file
            try {
              final path = await update.task.filePath();
              final file = File(path);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (_) {}
          }
        } else if (update.status == TaskStatus.failed || update.status == TaskStatus.canceled) {
            // Clean up on failure too
            if (update.task.group == 'upload' || update.task is UploadTask) {
              try {
                final path = await update.task.filePath();
                final file = File(path);
                if (await file.exists()) {
                  await file.delete();
                }
              } catch (_) {}
            }
        }
        debugPrint('Task ${update.task.taskId} status: ${update.status}');
      } else if (update is TaskProgressUpdate) {
        // debugPrint('Task ${update.task.taskId} progress: ${update.progress}');
      }
      _updateController.add(update);
    });
  }

  /// Validates URL accessibility before starting downloader.
  Future<bool> verifyUrl(String url) async {
    try {
      final response = await dio.Dio().head(url);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('URL verification failed: $e');
      if (e is dio.DioException) {
        if (e.response?.statusCode == 401) {
          throw '401: Unauthorized access to PDF.';
        } else if (e.response?.statusCode == 403) {
          throw '403: Forbidden access to PDF.';
        } else if (e.response?.statusCode == 404) {
          throw '404: PDF not found.';
        }
      }
      return false;
    }
  }

  /// Starts a background download.
  Future<String> downloadPdf(String url, {String? title}) async {
    // 1. Validate accessibility
    try {
      final isValid = await verifyUrl(url);
      if (!isValid) throw 'PDF URL is not accessible (Status not 200).';
    } catch (e) {
      debugPrint('Download aborted: $e');
      rethrow;
    }

    final path = await CacheManager().getLocalPath(url);
    final fileName = path.split('/').last;

    final bool isCloudinary = url.contains('cloudinary.com');

    final task = DownloadTask(
      url: url,
      filename: fileName,
      headers: {
        // ONLY send token to OUR server, NEVER to Cloudinary
        if (!isCloudinary && ApiService().token != null)
          'Authorization': 'Bearer ${ApiService().token}',
      },
      directory: 'pdf_cache',
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      retries: 3,
      allowPause: true,
      displayName: title ?? fileName,
    );

    _urlToTaskId[url] = task.taskId;
    _taskMap[task.taskId] = task;
    await FileDownloader().enqueue(task);
    return task.taskId;
  }

  /// Starts a background upload.
  Future<String> uploadPdf({
    required String url,
    required String filePath,
    required Map<String, String> fields,
    required Map<String, String> headers,
  }) async {
    final originalFileName = filePath.split('/').last;
    final safeFileName = originalFileName.replaceAll(RegExp(r'[^\w\.]'), '_');

    // background_downloader expects files to be in its baseDirectory.
    // FilePicker returns a path in the cache directory.
    // So we copy the file to the documents directory first.
    final dir = await getApplicationDocumentsDirectory();
    final tempDir = Directory('${dir.path}/temp_upload');
    if (!await tempDir.exists()) await tempDir.create();
    
    final tempFile = File('${tempDir.path}/$safeFileName');
    await File(filePath).copy(tempFile.path);

    final task = UploadTask(
      url: url,
      filename: safeFileName,
      directory: 'temp_upload',
      baseDirectory: BaseDirectory.applicationDocuments,
      headers: headers,
      fields: fields,
      fileField: 'pdf_file',
      updates: Updates.statusAndProgress,
      retries: 3,
      group: 'upload', // Assign to upload group for custom notifications
    );

    await FileDownloader().enqueue(task);
    return task.taskId;
  }

  String? getTaskIdForUrl(String url) => _urlToTaskId[url];

  Future<void> pauseTask(String taskId) async {
    final task = _taskMap[taskId];
    if (task != null) {
      await FileDownloader().pause(task);
    }
  }

  Future<void> resumeTask(String taskId) async {
    final task = _taskMap[taskId];
    if (task != null) {
      await FileDownloader().resume(task);
    }
  }

  Future<void> cancelTask(String taskId) async {
    await FileDownloader().cancelTasksWithIds([taskId]);
  }

  /// Starts a background download, saves to internal cache, AND copies to public Downloads folder.
  Future<String> downloadPdfExplicit(String url, {int? pubId, String title = 'document'}) async {
    // 1. Validate accessibility
    try {
      final isValid = await verifyUrl(url);
      if (!isValid) throw 'PDF URL is not accessible (Status not 200).';
    } catch (e) {
      debugPrint('Explicit Download aborted: $e');
      rethrow;
    }

    // Include ID in filename so we can track history when reading offline
    final prefix = pubId != null ? '[$pubId] ' : '';
    final cleanTitle = title.replaceAll(RegExp(r'[^\w]'), '_');
    final fileName = '$prefix$cleanTitle.pdf';
    
    final bool isCloudinary = url.contains('cloudinary.com');

    // 2. Download to internal pdf_cache first
    final task = DownloadTask(
      url: url,
      filename: fileName,
      headers: {
        // ONLY send token to OUR server, NEVER to Cloudinary
        if (!isCloudinary && ApiService().token != null)
          'Authorization': 'Bearer ${ApiService().token}',
      },
      baseDirectory: BaseDirectory.applicationDocuments,
      directory: 'pdf_cache', 
      updates: Updates.statusAndProgress,
      retries: 3,
      allowPause: true,
      displayName: title,
      group: 'explicit', // Used by global listener to trigger public copy
    );

    await FileDownloader().enqueue(task);
    return task.taskId;
  }

  /// Copies an existing cached file to the public Downloads folder.
  Future<bool> copyToPublicDownloads(String filePath, String title) async {
    try {
      final fileName = '${title.replaceAll(RegExp(r'[^\w]'), '_')}.pdf';
      final dir = await getApplicationDocumentsDirectory();
      
      // background_downloader expects the file to be in the baseDirectory/directory
      // So we copy the cached file to a known 'temp_export' folder inside documents
      final tempDir = Directory('${dir.path}/temp_export');
      if (!await tempDir.exists()) await tempDir.create();
      
      final tempFile = File('${tempDir.path}/$fileName');
      await File(filePath).copy(tempFile.path);
      
      // Create a task that points to this temp file
      final moveTask = DownloadTask(
        url: 'dummy',
        filename: fileName,
        directory: 'temp_export',
        baseDirectory: BaseDirectory.applicationDocuments,
      );
      
      final result = await FileDownloader().moveToSharedStorage(moveTask, SharedStorage.downloads);
      return result != null;
    } catch (e) {
      debugPrint('Error copying to public downloads: $e');
      return false;
    }
  }
}

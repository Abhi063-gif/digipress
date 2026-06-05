import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  /// Returns the local file if it exists in the documents directory.
  /// The [url] is used to derive the filename.
  Future<File?> getCachedFile(String url) async {
    final fileName = _getFileNameFromUrl(url);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/pdf_cache/$fileName');

    
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Checks if a file is already downloaded and exists locally.
  Future<bool> isFileCached(String url) async {
    final file = await getCachedFile(url);
    return file != null;
  }

  /// Returns the local path where a file should be saved.
  Future<String> getLocalPath(String url) async {
    final fileName = _getFileNameFromUrl(url);
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/pdf_cache/$fileName';

  }

  /// Deletes a cached file if it exists.
  Future<void> deleteCachedFile(String url) async {
    final file = await getCachedFile(url);
    if (file != null) {
      await file.delete();
    }
  }

  /// Utility to get a safe filename from a URL.
  String _getFileNameFromUrl(String url) {
    if (url.isEmpty) return 'unknown_file';
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        String lastSegment = uri.pathSegments.last;
        return lastSegment.replaceAll(RegExp(r'[^\w\.]'), '_');
      }
      // If no path segments, use a hash of the URL or a default name
      return 'file_${url.hashCode}.pdf';
    } catch (e) {
      return 'file_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }
  }
}

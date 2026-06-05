import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_db_service.dart';

/// Central API client for UniPage.
/// Set [useMockMode] to true to bypass the backend and test UI locally.
class ApiService {
  // ── MOCK MODE ───────────────────────────────────────────────────────────────
  // Set to FALSE once your PHP backend is running.
  static const bool useMockMode = false;

  // ── Base URL ────────────────────────────────────────────────────────────────
  // 👇 PASTE YOUR DEV TUNNEL URL BELOW (no trailing slash)
  // Example: 'https://abc123-80.usw3.devtunnels.ms/clg_magzine/backend'
  //
  // Options:
  //   Dev Tunnel  → 'https://<your-tunnel-id>.devtunnels.ms/clg_magzine/backend'
  //   Android Emu → 'http://10.0.2.2/clg_magzine/backend'
  //   Physical Dev→ 'http://<your-pc-local-ip>/clg_magzine/backend'
  static const String baseUrl = 'https://www.mydigipress.in';

  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  // ── Upload Event Bus ───────────────────────────────────────────────────────
  final _uploadEventController = StreamController<void>.broadcast();
  Stream<void> get onUploadSuccess => _uploadEventController.stream;

  void notifyUploadSuccess() {
    _uploadEventController.add(null);
  }

  // ── Delete Event Bus ───────────────────────────────────────────────────────
  final _deleteEventController = StreamController<void>.broadcast();
  Stream<void> get onPublicationDeleted => _deleteEventController.stream;

  void notifyPublicationDeleted() {
    _deleteEventController.add(null);
  }

  late final dio.Dio _dio;

  ApiService._internal() {
    _dio = dio.Dio(
      dio.BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 60), // Allow more time for uploads
        headers: {'Accept': 'application/json'},
      ),
    );

    // Add interceptor for auth token
    _dio.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  // ── In-memory cache of logged-in user ──────────────────────────────────────
  String? _token;
  Map<String, dynamic>? _user;

  String? get token => _token;
  Map<String, dynamic>? get currentUser => _user;
  bool get isLoggedIn => _token != null;
  bool get isAdmin => (_user?['role'] ?? '') == 'admin';

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (userJson != null) _user = jsonDecode(userJson);
  }

  Future<void> _saveSession(String token, Map<String, dynamic> user) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user', jsonEncode(user));
  }

  Future<void> clearSession() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  // ── Central GET with timeout ───────────────────────────────────────────────
  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _dio.get(path);
      // ignore: avoid_print
      print('[GET] $path → HTTP ${response.statusCode}');

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
      return {'status': 'error', 'message': 'Invalid response format'};
    } on dio.DioException catch (e) {
      // ignore: avoid_print
      print('[GET ERROR] $path → $e');
      return _handleDioError(e);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  // ── Central POST with timeout ──────────────────────────────────────────────
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post(path, data: body);
      // ignore: avoid_print
      print('[POST] $path → HTTP ${response.statusCode}');

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
      return {'status': 'error', 'message': 'Invalid response format'};
    } on dio.DioException catch (e) {
      // ignore: avoid_print
      print('[POST ERROR] $path → $e');
      return _handleDioError(e);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  Map<String, dynamic> _handleDioError(dio.DioException e) {
    String message = 'Network error: ${e.message}';

    if (e.type == dio.DioExceptionType.connectionTimeout ||
        e.type == dio.DioExceptionType.receiveTimeout ||
        e.type == dio.DioExceptionType.sendTimeout) {
      message = 'Connection timed out. Your WiFi might be too slow or restricted.';
    } else if (e.type == dio.DioExceptionType.connectionError) {
      message = 'Could not connect to server. Check if your WiFi has internet or blocks our domain.';
    } else if (e.error.toString().contains('HandshakeException')) {
      message = 'SSL Security Error. This WiFi might be intercepting your connection.';
    } else if (e.error.toString().contains('SocketException')) {
      message = 'No internet connection or server unreachable on this WiFi.';
    }

    if (e.response?.data != null && e.response?.data is Map) {
      return Map<String, dynamic>.from(e.response!.data);
    }

    return {'status': 'error', 'message': message};
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  AUTH
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'status': 'success',
        'message':
            'Registration successful. Please verify your email with the OTP sent.',
        'user_id': 1,
      };
    }
    final resp = await _post('/api/auth/register.php', {
      'name': name,
      'email': email,
      'password': password.trim(),
    });
    return resp;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
    String? purpose,
  }) async {
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      return {'status': 'success', 'message': 'Email verified successfully.'};
    }
    final resp = await _post('/api/auth/verify_otp.php', {
      'email': email,
      'otp': otp,
      'purpose': ?purpose,
    });
    return resp;
  }

  /// Login → stores token + user (with role) locally.
  /// In mock mode: a4abhi078@gmail.com with Abhi@123 logs in as admin.
  /// Any other email/password combo logs in as a regular user.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? fcmToken,
  }) async {
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 1));

      final isAdminLogin =
          email.toLowerCase() == 'a4abhi078@gmail.com' &&
          password == 'Abhi@123';

      final mockUser = {
        'id': isAdminLogin ? 1 : 2,
        'name': isAdminLogin ? 'Admin' : email.split('@').first,
        'email': email.toLowerCase(),
        'role': isAdminLogin ? 'admin' : 'user',
      };
      const mockToken = 'mock_token_for_testing';
      await _saveSession(mockToken, mockUser);
      return {'status': 'success', 'token': mockToken, 'user': mockUser};
    }

    final data = await _post('/api/auth/login.php', {
      'email': email,
      'password': password.trim(),
      'fcm_token': fcmToken,
    });
    if (data['status'] == 'success') {
      await _saveSession(
        data['token'],
        Map<String, dynamic>.from(data['user']),
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> sendOtp({required String email}) async {
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'status': 'success',
        'message': 'If this email is registered, an OTP has been sent.',
      };
    }
    return await _post('/api/auth/send_otp.php', {'email': email});
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      return {'status': 'success', 'message': 'Password reset successfully.'};
    }
    return await _post('/api/auth/reset_password.php', {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  PUBLICATIONS
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getPublicationById(int id) async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      final all = [
        {
          'id': 1,
          'title': 'UniVoice Annual Magazine 2025',
          'category': 'Magazine',
          'category_id': 1,
          'pdf_url': '',
          'cover_url': '',
          'pages': 52,
          'uploaded_by': 'Admin',
          'created_at': '2025-04-10 09:00:00',
        },
        {
          'id': 2,
          'title': 'Spring Semester Magazine – Tech Edition',
          'category': 'Magazine',
          'category_id': 1,
          'pdf_url': '',
          'cover_url': '',
          'pages': 38,
          'uploaded_by': 'Admin',
          'created_at': '2025-03-22 11:30:00',
        },
        {
          'id': 3,
          'title': 'Cultural Fest Highlights 2024',
          'category': 'Magazine',
          'category_id': 1,
          'pdf_url': '',
          'cover_url': '',
          'pages': 28,
          'uploaded_by': 'Admin',
          'created_at': '2024-12-05 10:15:00',
        },
      ];
      final publication = all.firstWhere(
        (p) => p['id'] == id,
        orElse: () => {'id': -1, 'title': 'Not Found'},
      );
      if (publication['id'] == -1) {
        return {'status': 'error', 'message': 'Publication not found'};
      }
      return {'status': 'success', 'publication': publication};
    }
    return await _get('/api/pdf/get.php?id=$id');
  }

  Future<Map<String, dynamic>> getPublications({
    int? categoryId,
    int page = 1,
  }) async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      final all = [
        {
          'id': 1,
          'title': 'UniVoice Annual Magazine 2025',
          'category': 'Magazine',
          'category_id': 1,
          'pdf_url': '',
          'cover_url': '',
          'pages': 52,
          'uploaded_by': 'Admin',
          'created_at': '2025-04-10 09:00:00',
        },
        {
          'id': 2,
          'title': 'Spring Semester Magazine – Tech Edition',
          'category': 'Magazine',
          'category_id': 1,
          'pdf_url': '',
          'cover_url': '',
          'pages': 38,
          'uploaded_by': 'Admin',
          'created_at': '2025-03-22 11:30:00',
        },
        {
          'id': 3,
          'title': 'Cultural Fest Highlights 2024',
          'category': 'Magazine',
          'category_id': 1,
          'pdf_url': '',
          'cover_url': '',
          'pages': 28,
          'uploaded_by': 'Admin',
          'created_at': '2024-12-05 10:15:00',
        },
        {
          'id': 4,
          'title': 'End-Semester Exam Schedule – April 2025',
          'category': 'Notice',
          'category_id': 2,
          'pdf_url': '',
          'cover_url': '',
          'pages': 4,
          'uploaded_by': 'Admin',
          'created_at': '2025-04-01 08:00:00',
        },
        {
          'id': 5,
          'title': 'Annual Sports Day – Participation Guidelines',
          'category': 'Notice',
          'category_id': 2,
          'pdf_url': '',
          'cover_url': '',
          'pages': 3,
          'uploaded_by': 'Admin',
          'created_at': '2025-03-15 09:30:00',
        },
        {
          'id': 6,
          'title': 'Mandatory Seminar: AI & Digital Literacy',
          'category': 'Notice',
          'category_id': 2,
          'pdf_url': '',
          'cover_url': '',
          'pages': 2,
          'uploaded_by': 'Admin',
          'created_at': '2025-03-10 10:00:00',
        },
        {
          'id': 7,
          'title': 'Placement Drive – Q4 Schedule 2025',
          'category': 'Notice',
          'category_id': 2,
          'pdf_url': '',
          'cover_url': '',
          'pages': 2,
          'uploaded_by': 'Admin',
          'created_at': '2025-02-28 08:00:00',
        },
        {
          'id': 8,
          'title': 'University Prospectus 2025-26',
          'category': 'Prospectus',
          'category_id': 3,
          'pdf_url': '',
          'cover_url': '',
          'pages': 170,
          'uploaded_by': 'Admin',
          'created_at': '2025-01-15 10:00:00',
        },
        {
          'id': 9,
          'title': 'Engineering Department Prospectus',
          'category': 'Prospectus',
          'category_id': 3,
          'pdf_url': '',
          'cover_url': '',
          'pages': 90,
          'uploaded_by': 'Admin',
          'created_at': '2024-12-20 09:00:00',
        },
        {
          'id': 10,
          'title': 'AI in Education – Research Journal Vol.12',
          'category': 'Research',
          'category_id': 4,
          'pdf_url': '',
          'cover_url': '',
          'pages': 85,
          'uploaded_by': 'Admin',
          'created_at': '2025-02-10 11:00:00',
        },
        {
          'id': 11,
          'title': 'Blockchain in Academic Records – Study',
          'category': 'Research',
          'category_id': 4,
          'pdf_url': '',
          'cover_url': '',
          'pages': 60,
          'uploaded_by': 'Admin',
          'created_at': '2025-01-20 10:00:00',
        },
        {
          'id': 12,
          'title': 'B.Tech Computer Science Syllabus 2025',
          'category': 'Syllabus',
          'category_id': 5,
          'pdf_url': '',
          'cover_url': '',
          'pages': 22,
          'uploaded_by': 'Admin',
          'created_at': '2025-03-01 08:00:00',
        },
        {
          'id': 13,
          'title': 'MBA Programme Syllabus – Semester 1',
          'category': 'Syllabus',
          'category_id': 5,
          'pdf_url': '',
          'cover_url': '',
          'pages': 18,
          'uploaded_by': 'Admin',
          'created_at': '2025-02-15 09:00:00',
        },
      ];
      final filtered = categoryId == null
          ? all
          : all.where((p) => p['category_id'] == categoryId).toList();
      return {
        'status': 'success',
        'publications': filtered,
        'pagination': {
          'total': filtered.length,
          'page': page,
          'limit': 20,
          'total_pages': 1,
        },
      };
    }
    var path = '/api/pdf/list.php?page=$page';
    if (categoryId != null) path += '&category_id=$categoryId';
    return await _get(path);
  }

  Future<Map<String, dynamic>> uploadPdf({
    required String title,
    required String description,
    required int categoryId,
    required String filePath,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 2));
      return {
        'status': 'success',
        'message': 'Publication uploaded successfully (mock).',
        'publication': {'id': 99, 'title': title, 'pdf_url': ''},
      };
    }

    try {
      final fileName = filePath.split('/').last;
      final formData = dio.FormData.fromMap({
        'title': title,
        'description': description,
        'category_id': categoryId,
        'pdf_file': await dio.MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/api/pdf/upload.php',
        data: formData,
        onSendProgress: onProgress,
      );

      if (response.data is Map<String, dynamic>) {
        if (response.data['status'] == 'success') {
          notifyUploadSuccess();
        }
        return response.data;
      } else {
        // Fallback for non-json responses
        return {
          'status': 'error',
          'message':
              'Invalid server response: ${response.data.toString().substring(0, 100)}',
        };
      }
    } on dio.DioException catch (e) {
      // ignore: avoid_print
      print('[UPLOAD ERROR] $e');

      String message = 'Upload failed: ${e.message}';
      if (e.type == dio.DioExceptionType.connectionTimeout ||
          e.type == dio.DioExceptionType.sendTimeout) {
        message =
            'Connection timed out. The file might be too large or your network is slow.';
      } else if (e.response?.data != null && e.response?.data is Map) {
        message = e.response?.data['message'] ?? message;
      }

      return {'status': 'error', 'message': message};
    } catch (e) {
      return {'status': 'error', 'message': 'An unexpected error occurred: $e'};
    }
  }

  Future<void> triggerNotifications(int pubId) async {
    if (useMockMode) return;
    try {
      await _post('/api/pdf/trigger_notifications.php', {'pub_id': pubId});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> deletePublication(int id) async {
    if (useMockMode) return {'status': 'success'};
    try {
      final response = await _post('/api/pdf/delete.php', {'id': id});
      return response;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  CATEGORIES
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getCategories() async {
    if (useMockMode) {
      return {
        'status': 'success',
        'categories': [
          {'id': 1, 'name': 'Magazine'},
          {'id': 2, 'name': 'Notice'},
          {'id': 3, 'name': 'Prospectus'},
          {'id': 4, 'name': 'Research'},
          {'id': 5, 'name': 'Syllabus'},
        ],
      };
    }
    return await _get('/api/categories/list.php');
  }

  Future<Map<String, dynamic>> addCategory({required String name}) async {
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      return {
        'status': 'success',
        'message': 'Category created.',
        'category': {'id': 99, 'name': name},
      };
    }
    return await _post('/api/categories/add.php', {'name': name});
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getNotifications() async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      return {
        'status': 'success',
        'notifications': [
          {
            'id': 1,
            'title': 'UniVoice Annual Magazine 2025 Released!',
            'body':
                'The latest edition of UniVoice is live. Featuring student success stories, research highlights, and creative writing from our best contributors.',
            'category': 'Magazine',
            'is_read': false,
            'created_at': '2025-04-10 09:00:00',
          },
          {
            'id': 2,
            'title': 'End-Semester Exam Schedule – April 2025',
            'body':
                'The official timetable for April end-semester exams is now published. Please verify your subject codes and hall ticket details immediately.',
            'category': 'Notice',
            'is_read': false,
            'created_at': '2025-04-01 08:00:00',
          },
          {
            'id': 3,
            'title': 'Mandatory Seminar: AI & Digital Literacy',
            'body':
                'All first-year students must attend the upcoming seminar on AI in education. Attendance is compulsory. Download the schedule from the Notices section.',
            'category': 'Notice',
            'is_read': false,
            'created_at': '2025-03-10 10:00:00',
          },
          {
            'id': 4,
            'title': 'University Prospectus 2025-26 Available',
            'body':
                'The updated university prospectus for the academic year 2025-26 has been published. It includes revised curricula, fee structures, and hostel guidelines.',
            'category': 'Prospectus',
            'is_read': true,
            'created_at': '2025-01-15 10:00:00',
          },
          {
            'id': 5,
            'title': 'New Research Journal: AI in Education Vol.12',
            'body':
                'Faculty research journal Vol.12 is now available. This edition focuses on the integration of AI tools in modern academic environments.',
            'category': 'Research',
            'is_read': true,
            'created_at': '2025-02-10 11:00:00',
          },
          {
            'id': 6,
            'title': 'B.Tech CS Syllabus 2025 Updated',
            'body':
                'The revised B.Tech Computer Science syllabus for 2025 batch has been uploaded. Students are advised to download and review the updated course structure.',
            'category': 'Syllabus',
            'is_read': true,
            'created_at': '2025-03-01 08:00:00',
          },
        ],
        'unread_count': 3,
      };
    }
    return await _get('/api/notifications/list.php');
  }

  Future<Map<String, dynamic>> clearNotifications() async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return {'status': 'success', 'message': 'Notifications cleared (mock).'};
    }
    return await _post('/api/notifications/clear.php', {});
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  PROFILE
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getProfile() async {
    if (useMockMode) {
      return {
        'status': 'success',
        'user':
            _user ?? {'id': 0, 'name': 'Guest', 'email': '', 'role': 'user'},
      };
    }
    final resp = await _get('/api/user/profile.php');
    if (resp['status'] == 'success' && resp['user'] != null) {
      // Keep token the same, just update user info
      await _saveSession(_token!, Map<String, dynamic>.from(resp['user']));
    }
    return resp;
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  PROFILE & HISTORY
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> updateProfile({
    required String userType,
    String? department,
    String? className,
    String? rollNumber,
  }) async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      return {'status': 'success', 'message': 'Profile updated locally.'};
    }
    final resp = await _post('/api/user/update_profile.php', {
      'user_type': userType,
      'department': department,
      'class_name': className,
      'roll_number': rollNumber,
    });
    // Refresh local profile
    if (resp['status'] == 'success') {
      await getProfile();
    }
    return resp;
  }

  Future<void> logRead(int pubId) async {
    if (useMockMode) {
      debugPrint('MOCK: Logged read for pub $pubId');
      return;
    }
    if (_token == null) {
      debugPrint('LOG READ: Skip (No token)');
      return;
    }
    try {
      final resp = await _post('/api/user/log_read.php', {'pub_id': pubId});
      debugPrint('LOG READ: Success for $pubId - ${resp['message']}');
    } catch (e) {
      debugPrint('LOG READ ERROR: $e');
    }
  }

  Future<void> logShare(int pubId) async {
    if (useMockMode) return;
    try {
      await _post('/api/user/logShare.php', {'pub_id': pubId});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getReadingHistory() async {
    if (useMockMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      return {'status': 'success', 'history': []};
    }
    return await _get('/api/user/reading_history.php');
  }

  // ── NEW SYNC APIs ─────────────────────────────────────────────────────────

  Future<void> saveDownload(int pubId) async {
    if (useMockMode) return;
    try {
      await _post('/api/user/saveDownload.php', {'pub_id': pubId});
    } catch (_) {}
  }

  Future<void> saveHistory(int pubId) async {
    if (useMockMode) return;
    try {
      await _post('/api/user/saveHistory.php', {'pub_id': pubId});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getDownloads() async {
    if (useMockMode) return {'status': 'success', 'downloads': []};
    return await _get('/api/user/getDownloads.php');
  }

  Future<Map<String, dynamic>> getHistory() async {
    if (useMockMode) return {'status': 'success', 'history': []};
    return await _get('/api/user/getHistory.php');
  }

  Future<void> syncData() async {
    if (_token == null || useMockMode) return;
    try {
      final dbService = LocalDbService();

      // 1. Sync downloads from server to local
      final dlResp = await getDownloads();
      if (dlResp['status'] == 'success') {
        final List dls = dlResp['downloads'] ?? [];
        for (var item in dls) {
          final existing = await dbService.getDownload(item['pdf_id']);
          if (existing == null) {
            // Found on server, but not locally. Add placeholder.
            await dbService.insertDownload({
              'pdf_id': item['pdf_id'],
              'title': item['title'] ?? 'Document',
              'file_url': item['file_url'] ?? '',
              'local_path':
                  '', // Empty because it's not downloaded on this device yet
              'category': item['category'],
              'download_timestamp':
                  item['timestamp'] ?? DateTime.now().toIso8601String(),
            });
          }
        }
      }

      // 2. Sync history from server to local
      final histResp = await getHistory();
      if (histResp['status'] == 'success') {
        final List hist = histResp['history'] ?? [];
        for (var item in hist) {
          await dbService.insertHistory({
            'pdf_id': item['pdf_id'],
            'title': item['title'] ?? 'Document',
            'file_url': item['file_url'] ?? '',
            'last_opened':
                item['last_opened'] ?? DateTime.now().toIso8601String(),
            'category': item['category'],
          });
        }
      }
    } catch (e) {
      debugPrint('Sync Error: $e');
    }
  }

  /// Silently sends the device FCM token to the backend to store on the user record.
  /// Called on login and whenever the token refreshes.
  Future<void> updateFcmToken(String fcmToken) async {
    if (_token == null) return; // Not logged in — skip
    if (useMockMode) return;
    try {
      await _post('/api/user/update_fcm.php', {'fcm_token': fcmToken});
    } catch (_) {}
  }
}

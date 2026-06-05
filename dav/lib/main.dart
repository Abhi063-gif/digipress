import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'core/services/api_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/pdf_viewer/pdf_viewer_screen.dart';
import 'package:provider/provider.dart';
import 'core/providers/pdf_provider.dart';
import 'core/services/download_manager.dart';
import 'core/services/network_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // No UI here — Android will show the notification automatically
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Restore saved session (token + user) from SharedPreferences
  await ApiService().loadSession();

  // Initialize Background Services
  await DownloadManager().init();
  await NetworkService().init();

  if (ApiService().isLoggedIn) {
    ApiService().syncData();
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => PdfProvider())],
      child: const DigiPressApp(),
    ),
  );
}

class DigiPressApp extends StatefulWidget {
  const DigiPressApp({super.key});

  @override
  State<DigiPressApp> createState() => _DigiPressAppState();
}

class _DigiPressAppState extends State<DigiPressApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initFcm();
  }

  Future<void> _initFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request notification permission (Android 13+ / iOS)
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Get and send FCM token to backend
      final token = await messaging.getToken();
      if (token != null) {
        ApiService().updateFcmToken(token);
      }

      // Refresh token when it changes
      messaging.onTokenRefresh.listen((newToken) {
        ApiService().updateFcmToken(newToken);
      }).onError((err) {
        debugPrint('[FCM] Token refresh error: $err');
      });

      // Foreground notification — show a SnackBar
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null && navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        if (notification.body != null)
                          Text(
                            notification.body!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1D4ED8),
              duration: const Duration(seconds: 4),
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      });

      // Tapped notification when app is in background (brought to foreground)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final pubIdStr = message.data['pub_id'];
        if (pubIdStr != null) {
          final id = int.tryParse(pubIdStr);
          if (id != null) _openPdfFromDeepLink(id);
        }
      });

      // Tapped notification that launched the app from terminated state
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        final pubIdStr = initial.data['pub_id'];
        if (pubIdStr != null) {
          final id = int.tryParse(pubIdStr);
          if (id != null) {
            Future.delayed(
              const Duration(seconds: 1),
              () => _openPdfFromDeepLink(id),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[FCM] Initialization error: $e');
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle incoming links when the app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // Handle link when app is started from a cold state
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        // Give the app a moment to build its initial UI before navigating
        Future.delayed(const Duration(seconds: 1), () {
          _handleDeepLink(initialUri);
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _handleDeepLink(Uri uri) async {
    if (uri.path == '/pdf' || uri.pathSegments.contains('pdf')) {
      final idStr = uri.queryParameters['id'];
      if (idStr != null) {
        final id = int.tryParse(idStr);
        if (id != null) {
          _openPdfFromDeepLink(id);
        }
      }
    }
  }

  Future<void> _openPdfFromDeepLink(int id) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    // Show loading indicator
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resp = await ApiService().getPublicationById(id);
      final navCtx = navigatorKey.currentContext;
      if (navCtx == null) return;
      Navigator.pop(navCtx); // Remove loading

      if (resp['status'] == 'success') {
        final pub = resp['publication'];
        Navigator.push(
          navCtx,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              title: pub['title'] ?? 'Document',
              pdfUrl: pub['pdf_url'] ?? '',
              pubId: pub['id'],
              offlineMode: false,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(navCtx).showSnackBar(
          SnackBar(content: Text(resp['message'] ?? 'Failed to load document')),
        );
      }
    } catch (e) {
      final navCtx = navigatorKey.currentContext;
      if (navCtx == null) return;
      Navigator.pop(navCtx); // Remove loading
      ScaffoldMessenger.of(
        navCtx,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiPress',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Always start with SplashScreen — it decides where to go
      home: const SplashScreen(),
    );
  }
}

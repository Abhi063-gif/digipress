import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/skeleton.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  bool _isSilentLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Reduce refresh frequency to 60s to avoid overwhelming the dev tunnel
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _silentLoad());
  }

  Future<void> _silentLoad() async {
    if (_isSilentLoading) return;
    _isSilentLoading = true;
    try {
      final data = await ApiService().getNotifications();
      if (!mounted) return;
      if (data['status'] == 'success') {
        setState(() {
          _items = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
        });
      } else {
        final message = data['message']?.toString() ?? '';
        if (message.toLowerCase().contains('unauthorized')) {
          await ApiService().clearSession();
          if (!mounted) return;
          setState(() {
            _items = [];
          });
        }
      }
    } catch (_) {
    } finally {
      _isSilentLoading = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService().getNotifications();
      if (!mounted) return;
      if (data['status'] == 'success') {
        setState(() {
          _items = List<Map<String, dynamic>>.from(
              data['notifications'] ?? []);
          _isLoading = false;
        });
      } else {
        final message = data['message']?.toString() ?? '';
        if (message.toLowerCase().contains('unauthorized')) {
          await ApiService().clearSession();
          if (!mounted) return;
          setState(() {
            _items = [];
            _error = null;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data['message'] ?? 'Failed to load notifications';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Network error: $e'; _isLoading = false; });
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Do you want to delete all notifications from your feed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete All', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await ApiService().clearNotifications();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final newCount = _items.where((n) => !(n['is_read'] as bool? ?? true)).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text(
                'Clear All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                size: 20, color: AppColors.textPrimary),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildSkeleton()
            : _error != null
                ? _buildError()
                : _buildList(newCount),
      ),
    );
  }

  // ── Shimmer skeleton ──────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          // Header skeleton
          Row(
            children: const [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 130, height: 14, radius: 6),
                  SizedBox(height: 6),
                  SkeletonBox(width: 200, height: 10, radius: 4),
                ],
              ),
              Spacer(),
              SkeletonBox(width: 56, height: 26, radius: 20),
            ],
          ),
          const SizedBox(height: 18),
          // 5 notification card skeletons
          for (int i = 0; i < 5; i++) const SkeletonNotificationCard(),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loaded list ───────────────────────────────────────────────────────────
  Widget _buildList(int newCount) {
    if (_items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Updates',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Stay informed with campus publications',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (newCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$newCount New',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        ..._items.map((n) => _NotificationCard(item: n)),
        const SizedBox(height: 16),
        const Column(
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 32, color: AppColors.textHint),
            SizedBox(height: 8),
            Text(
              "You've reached the end of your feed.",
              style: TextStyle(fontSize: 12.5, color: AppColors.textHint),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notification card
// ---------------------------------------------------------------------------
class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NotificationCard({required this.item});

  String get _category => item['category'] as String? ?? '';
  bool get _isNew => !(item['is_read'] as bool? ?? true);
  String get _title => item['title'] as String? ?? '';
  String get _body => item['body'] as String? ?? '';
  String get _timeAgo {
    final raw = item['created_at'] as String? ?? '';
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return raw.split(' ').first;
    }
  }

  Color get _chipColor {
    switch (_category.toLowerCase()) {
      case 'notice': return const Color(0xFFFEE2E2);
      case 'syllabus': return const Color(0xFFFEF3C7);
      case 'research': return const Color(0xFFD1FAE5);
      case 'prospectus': return const Color(0xFFEDE9FE);
      default: return AppColors.primaryLight;
    }
  }

  Color get _chipTextColor {
    switch (_category.toLowerCase()) {
      case 'notice': return const Color(0xFFDC2626);
      case 'syllabus': return const Color(0xFFD97706);
      case 'research': return const Color(0xFF059669);
      case 'prospectus': return const Color(0xFF7C3AED);
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isNew
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _chipColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.article_outlined,
                        size: 12, color: _chipTextColor),
                    const SizedBox(width: 4),
                    Text(
                      _category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _chipTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.access_time_rounded,
                  size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _timeAgo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textHint),
                ),
              ),
              if (_isNew) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (item['pdf_url'] != null && item['pdf_url'].toString().isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(
                          title: _title,
                          pdfUrl: item['pdf_url'],
                          pubId: int.tryParse(item['pub_id'].toString()),
                          offlineMode: false,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No PDF associated with this notification')),
                    );
                  }
                },
                child: const Text(
                  'View PDF Document',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined,
                    size: 16, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

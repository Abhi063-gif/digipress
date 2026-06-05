import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';

class ManagePublicationsScreen extends StatefulWidget {
  const ManagePublicationsScreen({super.key});

  @override
  State<ManagePublicationsScreen> createState() => _ManagePublicationsScreenState();
}

class _ManagePublicationsScreenState extends State<ManagePublicationsScreen> {
  final api = ApiService();
  List<Map<String, dynamic>> _publications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPublications();
  }

  Future<void> _loadPublications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await api.getPublications();
      if (!mounted) return;
      if (data['status'] == 'success') {
        setState(() {
          _publications = List<Map<String, dynamic>>.from(data['publications'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Failed to load library';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Connection error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deletePublication(int id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Publication', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "$title"? This will remove it from both the app and Cloudinary storage.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleting...'), duration: Duration(seconds: 1)));
      final resp = await api.deletePublication(id);
      if (!mounted) return;

      if (resp['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication deleted successfully')));
        api.notifyPublicationDeleted();
        _loadPublications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${resp['message']}')));
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> get _groupedPubs {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var pub in _publications) {
      final cat = pub['category'] ?? 'Uncategorized';
      if (!grouped.containsKey(cat)) grouped[cat] = [];
      grouped[cat]!.add(pub);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Manage Library', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _loadPublications, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadPublications, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _publications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_books_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text('Your digital library is empty', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                      itemCount: _groupedPubs.length,
                      itemBuilder: (ctx, index) {
                        final entry = _groupedPubs.entries.elementAt(index);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 20, 0, 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4, height: 16,
                                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    entry.key.toUpperCase(),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 1.1),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${entry.value.length})',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.5)),
                                  ),
                                ],
                              ),
                            ),
                            ...entry.value.map((pub) => _buildPubTile(pub)),
                          ],
                        );
                      },
                    ),
    );
  }

  Widget _buildPubTile(Map<String, dynamic> pub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 24),
        ),
        title: Text(
          pub['title'] ?? 'Untitled Publication',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 10, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                pub['created_at']?.toString().split(' ').first ?? 'Unknown',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            onPressed: () => _deletePublication(pub['id'] as int, pub['title'] ?? 'this publication'),
          ),
        ),
      ),
    );
  }
}

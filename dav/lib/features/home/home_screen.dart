import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/skeleton.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _publications = [];
  List<String> _categories = ['All'];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  StreamSubscription? _uploadSubscription;
  StreamSubscription? _deleteSubscription;
  bool _isSilentLoading = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _loadPublications();
    // Auto-refresh when an upload is successful elsewhere in the app
    _uploadSubscription = ApiService().onUploadSuccess.listen((_) {
      _loadPublications();
    });
    _deleteSubscription = ApiService().onPublicationDeleted.listen((_) {
      _loadPublications();
    });
    // Refresh every 60s to stay updated without spamming dev tunnel
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _silentLoad(),
    );
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await ApiService().getCategories();
      if (data['status'] == 'success' && data['categories'] != null) {
        final List<dynamic> cats = data['categories'];
        if (mounted) {
          setState(() {
            _categories = ['All', ...cats.map((c) => c['name'].toString())];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _silentLoad() async {
    if (_isSilentLoading) return;
    _isSilentLoading = true;
    try {
      final data = await ApiService().getPublications();
      if (!mounted) return;
      if (data['status'] == 'success') {
        setState(() {
          _publications = List<Map<String, dynamic>>.from(
            data['publications'] ?? [],
          );
        });
      }
    } catch (_) {
    } finally {
      _isSilentLoading = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _uploadSubscription?.cancel();
    _deleteSubscription?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPublications() async {
    _fetchCategories(); // Refresh categories too
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService().getPublications();
      if (!mounted) return;
      if (data['status'] == 'success') {
        setState(() {
          _publications = List<Map<String, dynamic>>.from(
            data['publications'] ?? [],
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Failed to load';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Network error: $e';
          _isLoading = false;
        });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_isSearching && _searchController.text.isNotEmpty) {
      return _searchResults;
    }
    return _selectedCategory == 'All'
        ? _publications
        : _publications
              .where((p) => p['category'] == _selectedCategory)
              .toList();
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
        });
        return;
      }

      final results = _publications
          .map((pub) {
            int score = 0;
            final title = (pub['title'] ?? '').toString().toLowerCase();
            final category = (pub['category'] ?? '').toString().toLowerCase();
            final q = query.toLowerCase();

            // 1. Exact title match or prefix match (highest)
            if (title == q) {
              score += 150;
            } else if (title.startsWith(q))
              score += 100;
            // 2. Substring match
            else if (title.contains(q))
              score += 50;

            // 3. Category match
            if (category.contains(q)) score += 30;

            // 4. Keyword match (matching individual words)
            final keywords = title.split(RegExp(r'[\s\-]'));
            if (keywords.any((k) => k.startsWith(q))) score += 20;

            return {'pub': pub, 'score': score};
          })
          .where((m) => (m['score'] as int) > 0)
          .toList();

      // Sort by score descending
      results.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

      if (mounted) {
        setState(() {
          _searchResults = results
              .map((m) => m['pub'] as Map<String, dynamic>)
              .toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPublications,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── App bar ──────────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: AppColors.background,
                floating: true,
                automaticallyImplyLeading: false,
                leading: _isSearching
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: Center(
                          child: Image.asset(
                            'assets/college-logo.png',
                            height: 38,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                leadingWidth: 60,
                centerTitle: true,
                title: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search publications...',
                          hintStyle: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSearching = false;
                                _searchController.clear();
                                _searchResults = [];
                              });
                            },
                          ),
                        ),
                      )
                    : const Text(
                        'DAV DigiPress',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.8,
                        ),
                      ),
                actions: _isSearching
                    ? []
                    : [
                        IconButton(
                          onPressed: () => setState(() => _isSearching = true),
                          icon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                        IconButton(
                          onPressed: _loadPublications,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Category chips ─────────────────────────────────────────
                    if (!_isSearching)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final cat = _categories[i];
                              final sel = cat == _selectedCategory;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedCategory = cat),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: sel
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: sel
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    if (!_isSearching) const SizedBox(height: 20),

                    // ── Featured banner (Dynamic) ─────────────────────────
                    if (!_isSearching && _publications.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: GestureDetector(
                          onTap: () {
                            if (_publications.isNotEmpty) {
                              final latest = _publications.first;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfViewerScreen(
                                    title: latest['title'] ?? 'Magazine',
                                    pdfUrl: latest['pdf_url'] ?? '',
                                    pubId: int.tryParse(
                                      latest['id'].toString(),
                                    ),
                                    offlineMode: false,
                                  ),
                                ),
                              );
                            }
                          },
                          child: _FeaturedBanner(
                            latestPub: _publications.first,
                          ),
                        ),
                      ),
                    if (!_isSearching && _publications.isNotEmpty)
                      const SizedBox(height: 24),

                    // ── Header (Dynamic Title) ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Text(
                            _isSearching
                                ? 'Search Results'
                                : 'Recently Uploaded',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (!_isLoading)
                            Text(
                              '${_filtered.length} item${_filtered.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),

              // ── Content ───────────────────────────────────────────────────────
              if (_isLoading)
                SliverToBoxAdapter(
                  child: Shimmer(
                    child: Column(
                      children: [
                        // Banner skeleton
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: const SkeletonBanner(),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: const [
                              SkeletonBox(width: 140, height: 14, radius: 6),
                              Spacer(),
                              SkeletonBox(width: 50, height: 12, radius: 6),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Grid skeleton (6 cards)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.72,
                                ),
                            itemCount: 6,
                            itemBuilder: (_, _) => const SkeletonPubCard(),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 48,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadPublications,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 48,
                          color: AppColors.textHint,
                        ),
                        SizedBox(height: 12),
                        Text(
                          _isSearching && _searchController.text.isNotEmpty
                              ? 'No results found for "${_searchController.text}"'
                              : 'No publications found.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                    delegate: SliverChildBuilderDelegate((_, i) {
                      if (i >= _filtered.length) return null;
                      final pub = _filtered[i];
                      return _PubCardWidget(
                        pub: pub,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PdfViewerScreen(
                              title: pub['title'] ?? '',
                              pdfUrl: pub['pdf_url'] ?? '',
                              pubId: int.tryParse(pub['id'].toString()),
                              offlineMode: false,
                            ),
                          ),
                        ),
                      );
                    }, childCount: _filtered.length),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Featured Banner (Premium Design) ───────────────────────────────────────────
class _FeaturedBanner extends StatelessWidget {
  final Map<String, dynamic>? latestPub;
  const _FeaturedBanner({this.latestPub});

  @override
  Widget build(BuildContext context) {
    final title =
        latestPub?['title'] ?? 'Academic Frontiers:\nModern Insights 2024';
    final category = latestPub?['category'] ?? 'LATEST RELEASE';

    return Container(
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Explore our newest digital collection',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'READ NOW',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Color(0xFF1D4ED8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Publication Card (Premium Detail Design) ───────────────────────────────────
class _PubCardWidget extends StatelessWidget {
  final Map<String, dynamic> pub;
  final VoidCallback onTap;

  const _PubCardWidget({required this.pub, required this.onTap});

  Color get _categoryColor {
    switch (pub['category']) {
      case 'Notice':
        return const Color(0xFFDC2626);
      case 'Prospectus':
        return const Color(0xFF7C3AED);
      case 'Research':
        return const Color(0xFF059669);
      case 'Syllabus':
        return const Color(0xFFD97706);
      default:
        return AppColors.primary;
    }
  }

  Color get _bgColor {
    switch (pub['category']) {
      case 'Notice':
        return const Color(0xFFDC2626);
      case 'Prospectus':
        return const Color(0xFF5C6BC0);
      case 'Research':
        return const Color(0xFF78909C);
      case 'Syllabus':
        return const Color(0xFFEF8C00);
      default:
        return const Color(0xFF1D7FEC);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = (pub['created_at'] as String? ?? '').split(' ').first;
    final pages = pub['pages'] != null && pub['pages'] != 0
        ? '${pub['pages']} PAGES'
        : 'PDF';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Badges
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13),
                      ),
                      color: _bgColor,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 44,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  // Pages badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        pages,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // PDF icon top right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Information section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pub['category'] ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _categoryColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pub['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 10,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          date,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

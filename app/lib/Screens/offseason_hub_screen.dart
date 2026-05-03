import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Providers/api_service.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class OffseasonHubScreen extends ConsumerStatefulWidget {
  const OffseasonHubScreen({super.key});

  @override
  ConsumerState<OffseasonHubScreen> createState() => _OffseasonHubScreenState();
}

class _OffseasonHubScreenState extends ConsumerState<OffseasonHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingNews = true;
  List<dynamic> _news = [];

  bool _isLoadingDraft = true;
  List<dynamic> _prospects = [];

  bool _isLoadingFA = true;
  List<dynamic> _freeAgents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final api = ref.read(apiServiceProvider);

    api.fetchOffseasonNews().then((data) {
      if (mounted) {
        setState(() {
          _news = data?['news'] ?? [];
          _isLoadingNews = false;
        });
      }
    });

    api.fetchDraftProspects().then((data) {
      if (mounted) {
        setState(() {
          _prospects = data?['prospects'] ?? [];
          _isLoadingDraft = false;
        });
      }
    });

    api.fetchFreeAgents().then((data) {
      if (mounted) {
        setState(() {
          _freeAgents = data?['free_agents'] ?? [];
          _isLoadingFA = false;
        });
      }
    });
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null) return;
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.bgSecondary,
        elevation: 0,
        title: Text(
          'Offseason',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.textSecondary),
            onPressed: () {
              setState(() {
                _isLoadingNews = true;
                _isLoadingDraft = true;
                _isLoadingFA = true;
              });
              _loadData();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentOrange,
          indicatorWeight: 2.5,
          labelColor: AppColors.accentOrange,
          unselectedLabelColor: context.textMuted,
          labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'News'),
            Tab(text: 'Draft 2026'),
            Tab(text: 'Free Agency'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewsTab(),
          _buildDraftTab(),
          _buildFreeAgencyTab(),
        ],
      ),
    );
  }

  // ── News Tab ────────────────────────────────────────────────────────────────

  Widget _buildNewsTab() {
    if (_isLoadingNews) {
      return Center(child: CircularProgressIndicator(color: AppColors.accentOrange));
    }
    if (_news.isEmpty) {
      return _buildEmptyState(
        icon: Icons.article_outlined,
        title: 'No news available',
        description: 'Check back later for the latest offseason updates.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _news.length,
      itemBuilder: (context, index) {
        final article = _news[index];
        return _NewsCard(
          article: article,
          onTap: () => _launchUrl(article['link']),
        );
      },
    );
  }

  // ── Draft Tab ────────────────────────────────────────────────────────────────

  Widget _buildDraftTab() {
    if (_isLoadingDraft) {
      return Center(child: CircularProgressIndicator(color: AppColors.accentOrange));
    }
    if (_prospects.isEmpty) {
      return _buildEmptyState(
        icon: Icons.school_outlined,
        title: 'No prospects yet',
        description: 'Draft prospect rankings will appear here once available.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prospects.length,
      itemBuilder: (context, index) {
        final prospect = _prospects[index];
        return _DraftCard(rank: index + 1, prospect: prospect);
      },
    );
  }

  // ── Free Agency Tab ──────────────────────────────────────────────────────────

  Widget _buildFreeAgencyTab() {
    if (_isLoadingFA) {
      return Center(child: CircularProgressIndicator(color: AppColors.accentOrange));
    }
    if (_freeAgents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.monetization_on_outlined,
        title: 'No free agents yet',
        description: 'Free agent tracker will be active once the offseason begins.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _freeAgents.length,
      itemBuilder: (context, index) {
        final fa = _freeAgents[index];
        return _FreeAgentCard(player: fa);
      },
    );
  }

  // ── Shared empty state ───────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: context.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── News Card ──────────────────────────────────────────────────────────────────

class _NewsCard extends StatelessWidget {
  final dynamic article;
  final VoidCallback onTap;

  const _NewsCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article['image_url'] != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    article['image_url'],
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildImagePlaceholder(context),
                  ),
                )
              else
                _buildImagePlaceholder(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article['source'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          (article['source'] as String).toUpperCase(),
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.accentOrange,
                          ),
                        ),
                      ),
                    Text(
                      article['headline'] ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    if (article['description'] != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        article['description'],
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: context.textSecondary,
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      article['published_at'] ?? '',
                      style: GoogleFonts.dmSans(fontSize: 11, color: context.textMuted),
                    ),
                    Text(
                      'Read more →',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        height: 100,
        width: double.infinity,
        color: context.bgSecondary,
        child: Icon(Icons.article_outlined, size: 36, color: context.textMuted),
      ),
    );
  }
}

// ── Draft Card ─────────────────────────────────────────────────────────────────

class _DraftCard extends StatelessWidget {
  final int rank;
  final dynamic prospect;

  const _DraftCard({required this.rank, required this.prospect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pick badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$rank',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentBlue,
                    height: 1,
                  ),
                ),
                Text(
                  'Pick',
                  style: GoogleFonts.dmSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentBlue,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prospect['name'] ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${prospect['school'] ?? ''} · ${prospect['strengths'] ?? ''}',
                  style: GoogleFonts.dmSans(fontSize: 12, color: context.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Position + pick badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3)),
                ),
                child: Text(
                  prospect['position'] ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentOrange,
                  ),
                ),
              ),
              if (prospect['projected_pick'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  prospect['projected_pick'],
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Free Agent Card ────────────────────────────────────────────────────────────

class _FreeAgentCard extends StatelessWidget {
  final dynamic player;

  const _FreeAgentCard({required this.player});

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}';
    return parts.first.isNotEmpty ? parts.first[0] : '?';
  }

  @override
  Widget build(BuildContext context) {
    final name = player['name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Player avatar with initials
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.bgSecondary,
              border: Border.all(color: context.borderColor),
            ),
            child: Center(
              child: Text(
                _initials(name),
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${player['previous_team'] ?? ''} · ${player['status'] ?? ''}',
                  style: GoogleFonts.dmSans(fontSize: 12, color: context.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    player['position'] ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Contract value
          Text(
            player['projected_contract'] ?? '',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.accentGreen,
            ),
          ),
        ],
      ),
    );
  }
}

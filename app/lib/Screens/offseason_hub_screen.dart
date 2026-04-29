import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Providers/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class OffseasonHubScreen extends ConsumerStatefulWidget {
  const OffseasonHubScreen({super.key});

  @override
  ConsumerState<OffseasonHubScreen> createState() => _OffseasonHubScreenState();
}

class _OffseasonHubScreenState extends ConsumerState<OffseasonHubScreen> with SingleTickerProviderStateMixin {
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
    
    // Load News
    api.fetchOffseasonNews().then((data) {
      if (mounted) {
        setState(() {
          _news = data?['news'] ?? [];
          _isLoadingNews = false;
        });
      }
    });

    // Load Draft
    api.fetchDraftProspects().then((data) {
      if (mounted) {
        setState(() {
          _prospects = data?['prospects'] ?? [];
          _isLoadingDraft = false;
        });
      }
    });

    // Load FA
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
      appBar: AppBar(
        title: const Text('NBA Offseason Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          labelColor: Colors.orangeAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.article), text: 'News'),
            Tab(icon: Icon(Icons.school), text: 'Draft 2026'),
            Tab(icon: Icon(Icons.monetization_on), text: 'Free Agency'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildNewsTab(),
            _buildDraftTab(),
            _buildFreeAgencyTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsTab() {
    if (_isLoadingNews) {
      return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
    }
    if (_news.isEmpty) {
      return const Center(child: Text('No news available.', style: TextStyle(color: Colors.white70)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _news.length,
      itemBuilder: (context, index) {
        final article = _news[index];
        return Card(
          color: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () => _launchUrl(article['link']),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (article['image_url'] != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      article['image_url'],
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(height: 100, child: Icon(Icons.broken_image, color: Colors.white54)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article['headline'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article['description'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraftTab() {
    if (_isLoadingDraft) {
      return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _prospects.length,
      itemBuilder: (context, index) {
        final prospect = _prospects[index];
        return Card(
          color: Colors.white.withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              backgroundImage: prospect['image_url'] != null ? NetworkImage(prospect['image_url']) : null,
              child: prospect['image_url'] == null ? Text(prospect['position'], style: const TextStyle(color: Colors.white)) : null,
            ),
            title: Text(prospect['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('${prospect['school']} • ${prospect['strengths']}', style: const TextStyle(color: Colors.white70)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Projected', style: TextStyle(color: Colors.white54, fontSize: 10)),
                Text(prospect['projected_pick'], style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFreeAgencyTab() {
    if (_isLoadingFA) {
      return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _freeAgents.length,
      itemBuilder: (context, index) {
        final fa = _freeAgents[index];
        return Card(
          color: Colors.white.withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.greenAccent.withOpacity(0.2),
              child: Text(fa['position'], style: const TextStyle(color: Colors.greenAccent)),
            ),
            title: Text(fa['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('Prev: ${fa['previous_team']} • ${fa['status']}', style: const TextStyle(color: Colors.white70)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Est. Value', style: TextStyle(color: Colors.white54, fontSize: 10)),
                Text(fa['projected_contract'], style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Models/game.dart';
import '../Providers/games_provider.dart';
import '../Providers/user_provider.dart';
import '../Widgets/team_logo.dart';
import '../theme/app_theme.dart';
import 'game_detail_screen.dart';
import 'profile_screen.dart';

/// Screen showing all of today's games with prediction access
class TodayGamesScreen extends ConsumerWidget {
  const TodayGamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(gamesProvider);

    return Scaffold(
      backgroundColor: context.bgPrimary,
      
      drawer: _AppDrawer(),
      appBar: AppBar(
        backgroundColor: context.bgSecondary,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.accentOrange, AppColors.accentYellow],
          ).createShader(bounds),
          child: Text(
            // center the text
            'NBA Predictions',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: context.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              // adding left side hamburger menu icon
              icon: gamesAsync.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.textSecondary,
                      ),
                    )
                  : Icon(Icons.refresh, color: context.textSecondary),
              onPressed: gamesAsync.isLoading
                  ? null
                  : () => _onRefresh(context, ref),
            ),
          ),
        ],
      ),
      body: gamesAsync.when(
        data: (state) =>
            _buildGamesList(context, ref, state.games, state.isRefreshing),
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.accentOrange),
        ),
        error: (error, _) => _buildError(context, ref, error.toString()),
      ),
    );
  }

  Future<void> _onRefresh(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(gamesProvider.notifier).refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.errorRed,
          ),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(gamesProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList(
    BuildContext context,
    WidgetRef ref,
    List<Game> games,
    bool isRefreshing,
  ) {
    if (games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_basketball,
              size: 48,
              color: context.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No games today',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: context.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _onRefresh(context, ref),
      color: AppColors.accentOrange,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: games.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader(context, games.length);
          }
          final game = games[index - 1];
          return _GameCard(game: game);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int gameCount) {
    final now = DateTime.now();
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final dateString = '${monthNames[now.month - 1]} ${now.day}, ${now.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text(
            dateString.toUpperCase(),
            style: GoogleFonts.spaceMono(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: context.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.borderColor, Colors.transparent],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$gameCount games',
              style: GoogleFonts.spaceMono(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.accentBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final Game game;

  const _GameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameDetailScreen(game: game),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Teams
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TeamRow(
                            team: game.homeTeam,
                            isAway: false,
                          ),
                          const SizedBox(height: 8),
                          _TeamRow(
                            team: game.awayTeam,
                            isAway: true,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: context.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Prediction hint
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.public,
                        size: 16,
                        color: AppColors.accentGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to see model prediction',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Footer with time and status
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: context.borderColor),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${game.date} • ${game.time}',
                        style: GoogleFonts.spaceMono(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                      _StatusBadge(status: game.status, isLive: game.isLive),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String team;
  final bool isAway;

  const _TeamRow({
    required this.team,
    required this.isAway,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TeamLogo(
          teamName: team,
          size: 32,
          backgroundColor: context.bgSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isAway ? '@ $team' : team,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isLive;

  const _StatusBadge({
    required this.status,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    final statusLower = status.toLowerCase();
    if (isLive) {
      bgColor = AppColors.liveRed.withOpacity(0.15);
      textColor = AppColors.liveRed;
    } else if (statusLower == 'final') {
      bgColor = context.textMuted.withOpacity(0.15);
      textColor = context.textSecondary;
    } else {
      bgColor = AppColors.accentBlue.withOpacity(0.15);
      textColor = AppColors.accentBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.liveRed,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            status.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// App drawer with user profile information
class _AppDrawer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Drawer(
      backgroundColor: context.bgSecondary,
      child: Column(
        children: [
          // User profile header
          userProfileAsync.when(
            data: (profile) => _buildDrawerHeader(context, profile),
            loading: () => _buildDrawerHeader(context, null, isLoading: true),
            error: (_, __) => _buildDrawerHeader(context, null),
          ),
          
          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                _DrawerItem(
                  icon: Icons.sports_basketball_outlined,
                  label: 'Today\'s Games',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // App version at bottom
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'NBA Predictions v1.0.0',
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  color: context.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, dynamic profile, {bool isLoading = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentOrange.withOpacity(0.15),
            AppColors.accentYellow.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: context.borderColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile photo
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentOrange.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentOrange.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: isLoading
                    ? Container(
                        color: context.bgCard,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentOrange,
                          ),
                        ),
                      )
                    : profile?.photoUrl != null && profile!.photoUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: profile.photoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildInitialsAvatar(context, profile.initials),
                            errorWidget: (_, __, ___) => _buildInitialsAvatar(context, profile.initials),
                          )
                        : _buildInitialsAvatar(context, profile?.initials ?? ''),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // User name
          if (isLoading)
            Container(
              width: 120,
              height: 20,
              decoration: BoxDecoration(
                color: context.bgCard,
                borderRadius: BorderRadius.circular(4),
              ),
            )
          else
            Text(
              profile?.displayName.isNotEmpty == true 
                  ? profile!.displayName 
                  : 'Welcome',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          const SizedBox(height: 4),
          
          // Username
          if (isLoading)
            Container(
              width: 80,
              height: 14,
              decoration: BoxDecoration(
                color: context.bgCard,
                borderRadius: BorderRadius.circular(4),
              ),
            )
          else if (profile != null)
            Text(
              '@${profile.username}',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.accentBlue,
              ),
            )
          else
            Text(
              'Tap to view profile',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: context.textMuted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(BuildContext context, String initials) {
    return Container(
      color: context.bgCard,
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : '?',
          style: GoogleFonts.dmSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.accentOrange,
          ),
        ),
      ),
    );
  }
}

/// Individual drawer menu item
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: context.textSecondary,
          size: 22,
        ),
      ),
      title: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: context.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: context.textMuted,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

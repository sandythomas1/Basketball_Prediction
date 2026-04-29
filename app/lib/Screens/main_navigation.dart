import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Providers/games_provider.dart';
import '../Providers/playoff_provider.dart';
import '../theme/app_theme.dart';
import 'today_games_screen.dart';
import 'live_games_screen.dart';
import 'finished_games_screen.dart';
import 'playoff_games_today_screen.dart';
import 'playoff_bracket_screen.dart';
import 'bracket_simulator_screen.dart';
import 'offseason_hub_screen.dart';

/// Main navigation shell with bottom navigation bar
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final hasLiveGames = ref.watch(hasLiveGamesProvider);
    final playoffsActive = ref.watch(playoffsActiveProvider);

    // Kick off the bracket/status fetch so playoffsActiveProvider gets set.
    ref.watch(playoffBracketProvider);

    // Build the tab screens list dynamically based on playoff status.
    final screens = [
      const TodayGamesScreen(),
      const LiveGamesScreen(),
      const FinishedGamesScreen(),
      const OffseasonHubScreen(),
      if (playoffsActive) const PlayoffGamesTodayScreen(),
      const BracketSimulatorScreen(),
    ];

    // Clamp index in case playoffs tab appears/disappears mid-session.
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.bgSecondary,
          border: Border(
            top: BorderSide(
              color: context.borderColor,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.article_outlined,
                  activeIcon: Icons.article,
                  label: 'Today',
                  isSelected: safeIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.check_circle_outline,
                  activeIcon: Icons.check_circle,
                  label: 'Live',
                  isSelected: safeIndex == 1,
                  showBadge: hasLiveGames,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  label: 'Finished',
                  isSelected: safeIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.beach_access_outlined,
                  activeIcon: Icons.beach_access,
                  label: 'Offseason',
                  isSelected: safeIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                if (playoffsActive)
                  _NavItem(
                    icon: Icons.emoji_events_outlined,
                    activeIcon: Icons.emoji_events,
                    label: 'Playoffs',
                    isSelected: safeIndex == 4,
                    onTap: () => setState(() => _currentIndex = 4),
                  ),
                _NavItem(
                  icon: Icons.account_tree_outlined,
                  activeIcon: Icons.account_tree,
                  label: 'Madness',
                  isSelected: safeIndex == (playoffsActive ? 5 : 4),
                  onTap: () => setState(() => _currentIndex = (playoffsActive ? 5 : 4)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    this.showBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentOrange.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 24,
                  color: isSelected
                      ? AppColors.accentOrange
                      : context.textSecondary,
                ),
                if (showBadge)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: _PulsingDot(),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppColors.accentOrange
                    : context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.liveRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.liveRed.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

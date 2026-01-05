import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Providers/games_provider.dart';
import 'today_games_screen.dart';
import 'live_games_screen.dart';
import 'finished_games_screen.dart';

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
    // Watch hasLiveGames for the badge
    final hasLiveGames = ref.watch(hasLiveGamesProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          TodayGamesScreen(),
          LiveGamesScreen(),
          FinishedGamesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: hasLiveGames,
              child: const Icon(Icons.play_circle_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: hasLiveGames,
              child: const Icon(Icons.play_circle),
            ),
            label: 'Live',
          ),
          const NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Finished',
          ),
        ],
      ),
    );
  }
}

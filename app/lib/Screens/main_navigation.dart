import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Models/game.dart';
import 'today_games_screen.dart';
import 'live_games_screen.dart';
import 'finished_games_screen.dart';

/// Main navigation shell with bottom navigation bar
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  List<Game> _allGames = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastFetchTime;

  // Rate limiting: minimum 30 seconds between API calls
  static const Duration _minFetchInterval = Duration(seconds: 30);

  // Cache duration: refresh data after 2 minutes
  static const Duration _cacheDuration = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  bool _canFetch() {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) >= _minFetchInterval;
  }

  bool _shouldRefreshCache() {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) >= _cacheDuration;
  }

  Future<void> _fetchGames({bool forceRefresh = false}) async {
    // Rate limiting check
    if (!forceRefresh && !_canFetch()) {
      debugPrint('Rate limited: Please wait before refreshing');
      return;
    }

    // Use cached data if still fresh
    if (!forceRefresh && !_shouldRefreshCache() && _allGames.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard',
            ),
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timed out'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] as List<dynamic>? ?? [];

        final List<Game> games = [];

        for (final event in events) {
          try {
            final competitions = event['competitions'] as List<dynamic>?;
            if (competitions == null || competitions.isEmpty) continue;

            final competition = competitions[0];
            final competitors = competition['competitors'] as List<dynamic>?;
            if (competitors == null || competitors.length < 2) continue;

            // Find home and away teams
            String homeTeam = '';
            String awayTeam = '';
            String homeScore = '';
            String awayScore = '';

            for (final competitor in competitors) {
              final team = competitor['team'];
              final teamName = team?['displayName'] ?? 'Unknown';
              final score = competitor['score'] ?? '';

              if (competitor['homeAway'] == 'home') {
                homeTeam = teamName;
                homeScore = score;
              } else {
                awayTeam = teamName;
                awayScore = score;
              }
            }

            // Parse date and time
            final dateStr = event['date'] as String? ?? '';
            final gameDateTime = DateTime.tryParse(dateStr)?.toLocal();
            final formattedDate = gameDateTime != null
                ? '${_getMonthName(gameDateTime.month)} ${gameDateTime.day}'
                : 'TBD';
            final formattedTime = gameDateTime != null
                ? '${_formatHour(gameDateTime.hour)}:${gameDateTime.minute.toString().padLeft(2, '0')} ${gameDateTime.hour >= 12 ? 'PM' : 'AM'}'
                : 'TBD';

            // Get game status
            final status = event['status']?['type']?['description'] ?? 'Scheduled';

            // Generate mock prediction data for demo
            // In production, this would come from your prediction API
            final homeWinProb = _generateMockPrediction(homeTeam, awayTeam);
            final confidenceTier = _getConfidenceTier(homeWinProb);
            final favoredTeam = homeWinProb >= 0.5 ? homeTeam : awayTeam;
            final homeElo = _generateMockElo(homeTeam);
            final awayElo = _generateMockElo(awayTeam);

            games.add(Game(
              homeTeam: homeTeam,
              awayTeam: awayTeam,
              date: formattedDate,
              time: formattedTime,
              status: status,
              homeScore: homeScore,
              awayScore: awayScore,
              homeWinProb: homeWinProb,
              awayWinProb: 1 - homeWinProb,
              confidenceTier: confidenceTier,
              favoredTeam: favoredTeam,
              homeElo: homeElo,
              awayElo: awayElo,
            ));
          } catch (e) {
            debugPrint('Error parsing game: $e');
            continue;
          }
        }

        setState(() {
          _allGames = games;
          _isLoading = false;
          _lastFetchTime = DateTime.now();
        });
      } else if (response.statusCode == 429) {
        // Rate limited by API
        setState(() {
          _errorMessage = 'Too many requests. Please try again later.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load games (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Mock prediction generator - replace with actual API call
  double _generateMockPrediction(String homeTeam, String awayTeam) {
    // Generate based on team name hash for consistent results
    final hash = (homeTeam.hashCode + awayTeam.hashCode).abs();
    return 0.35 + (hash % 30) / 100.0; // Range: 0.35 - 0.65
  }

  // Mock Elo generator - replace with actual API call
  double _generateMockElo(String team) {
    final hash = team.hashCode.abs();
    return 1350 + (hash % 400).toDouble(); // Range: 1350 - 1750
  }

  String _getConfidenceTier(double homeWinProb) {
    final prob = homeWinProb >= 0.5 ? homeWinProb : (1 - homeWinProb);
    if (prob >= 0.65) return 'Strong Favorite';
    if (prob >= 0.58) return 'Moderate Favorite';
    if (prob >= 0.52) return 'Lean Favorite';
    return 'Toss-Up';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12';
    if (hour > 12) return (hour - 12).toString();
    return hour.toString();
  }

  Future<void> _onRefresh() async {
    if (!_canFetch()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait before refreshing again'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    await _fetchGames(forceRefresh: true);
  }

  // Filter games for live only (in progress)
  List<Game> get _liveGames {
    return _allGames.where((g) => g.isLive).toList();
  }

  // Filter games for finished only
  List<Game> get _finishedGames {
    return _allGames.where((g) => g.isFinal).toList();
  }

  // Check if there are any live games
  bool get _hasLiveGames {
    return _allGames.any((g) => g.isLive);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TodayGamesScreen(
            games: _allGames,
            isLoading: _isLoading,
            errorMessage: _errorMessage,
            onRefresh: _onRefresh,
          ),
          LiveGamesScreen(
            games: _liveGames,
            isLoading: _isLoading,
            errorMessage: _errorMessage,
            onRefresh: _onRefresh,
          ),
          FinishedGamesScreen(
            games: _finishedGames,
            isLoading: _isLoading,
            errorMessage: _errorMessage,
            onRefresh: _onRefresh,
          ),
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
              isLabelVisible: _hasLiveGames,
              child: const Icon(Icons.play_circle_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: _hasLiveGames,
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


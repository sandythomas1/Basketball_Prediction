// home screen for all nba matchups
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Game {
  final String homeTeam;
  final String awayTeam;
  final String date;
  final String time;
  final String status;
  final String homeScore;
  final String awayScore;

  Game({
    required this.homeTeam,
    required this.awayTeam,
    required this.date,
    required this.time,
    required this.status,
    this.homeScore = '',
    this.awayScore = '',
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Game> _games = [];
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
    if (!forceRefresh && !_shouldRefreshCache() && _games.isNotEmpty) {
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

            games.add(Game(
              homeTeam: homeTeam,
              awayTeam: awayTeam,
              date: formattedDate,
              time: formattedTime,
              status: status,
              homeScore: homeScore,
              awayScore: awayScore,
            ));
          } catch (e) {
            debugPrint('Error parsing game: $e');
            continue;
          }
        }

        setState(() {
          _games = games;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait before refreshing again'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    await _fetchGames(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NBA Games Today'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _onRefresh,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchGames(forceRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_games.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_basketball,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No games scheduled today',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        itemCount: _games.length,
        itemBuilder: (context, index) {
          final game = _games[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.awayTeam,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@ ${game.homeTeam}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (game.status != 'Scheduled' && game.homeScore.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              game.awayScore,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              game.homeScore,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${game.date} • ${game.time}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(game.status),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          game.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return Colors.green;
      case 'final':
        return Colors.grey;
      case 'scheduled':
      default:
        return Colors.blue;
    }
  }
}

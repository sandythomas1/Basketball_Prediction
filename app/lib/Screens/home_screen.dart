// home screen for all nba matchups 
import 'package:flutter/material.dart';
import 'game_detail_screen.dart';
import '../Models/games.dart';

// use model from games.dart
class Game {
  final String homeTeam;
  final String awayTeam;
  final String date;
  final String time;
  final double percentage;

  Game(this.homeTeam, this.awayTeam, this.date, this.time, this.percentage);
}

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  // Mock data for testing
  final List<Game> games = [
    Game('Lakers', 'Celtics', 'Oct 25', '7:30 PM', 0.655467),
    Game('Warriors', 'Suns', 'Oct 25', '10:00 PM', 0.92),
    Game('Nuggets', 'Heat', 'Oct 26', '8:00 PM', 0.50),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NBA Games Today'),
      ),
      body: ListView.builder(
        itemCount: games.length,
        itemBuilder: (context, index) {
          return InkWell(
           onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameDetailScreen(game: games[index]),
              ),
            );
          },
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${games[index].homeTeam} vs ${games[index].awayTeam}'),
                    Column(
                      children: [
                        Text('${games[index].time} (pst)'),
                        Text('${games[index].date}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ); 
  }
}
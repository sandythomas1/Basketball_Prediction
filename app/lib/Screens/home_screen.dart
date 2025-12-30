// home screen for all nba matchups 
import 'package:flutter/material.dart';

// A simple temporary data structure
class Game {
  final String homeTeam;
  final String awayTeam;
  final String date;
  final String time;

  Game(this.homeTeam, this.awayTeam, this.date, this.time);
}

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  // Mock data for testing
  final List<Game> games = [
    Game('Lakers', 'Celtics', 'Oct 25', '7:30 PM'),
    Game('Warriors', 'Suns', 'Oct 25', '10:00 PM'),
    Game('Nuggets', 'Heat', 'Oct 26', '8:00 PM'),
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
              // Navigate to game details screen
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
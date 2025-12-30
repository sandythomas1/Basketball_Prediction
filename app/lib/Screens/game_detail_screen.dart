import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:pie_chart/pie_chart.dart';

class GameDetailScreen extends StatelessWidget {
  final Game game;

  const GameDetailScreen({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${game.homeTeam} vs ${game.awayTeam}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'Win Probability',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            // Probability Section for Home Team
            // pub dev pie chart
            PieChart(
              dataMap: {
                game.homeTeam: game.percentage,
                game.awayTeam: 1.0 - game.percentage, // Logic: 100% minus home win chance
              },
              chartValuesOptions: const ChartValuesOptions(
                //showChartValuesOutside: true,
                showChartValuesInPercentage: true,
                decimalPlaces: 0, // Keeps it at 65% instead of 0.7
              ),
            ),
            // const SizedBox(height: 20),
            // // Probability Section for Away Team
            // // pub dev pie chart
            // _buildProbabilityRow(game.awayTeam, 0.35), // Mock 35%
          ],
        ),
      ),
    );
  }
}
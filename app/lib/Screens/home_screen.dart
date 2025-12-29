// home screen for all nba matchups 
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NBA Games Today'),
      ),
      body: const Center(
        child: Text('List of Games'),
      ),
    );
  }
}
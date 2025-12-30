import 'package:flutter/material.dart';
import 'Screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NBA Matchups',
      theme: ThemeData(
        // Define the default brightness and colors.
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 102, 105, 76)),
        //primaryColor: const Color.fromARGB(255, 41, 17, 126),
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}
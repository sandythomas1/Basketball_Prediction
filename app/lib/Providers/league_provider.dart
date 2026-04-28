import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the currently selected league ('nba' or 'wnba').
final leagueProvider = StateProvider<String>((ref) => 'nba');

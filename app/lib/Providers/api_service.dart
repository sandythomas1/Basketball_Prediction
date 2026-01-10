import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// API Service for handling all HTTP requests
class ApiService {
  /// Production API URL (Render)
  static const String _productionUrl = 'https://nba-prediction-api-nq5b.onrender.com';

  /// FastAPI base URL - uses production in release, localhost in debug
  String get fastApiBaseUrl {
    // Use production URL for release builds
    if (!kDebugMode) {
      return _productionUrl;
    }
    
    // Debug mode: use localhost
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://localhost:8000';
    }
  }

  static const String espnBaseUrl =
      'https://site.api.espn.com/apis/site/v2/sports/basketball/nba';

  /// Fetch today's games from ESPN API
  Future<Map<String, dynamic>> fetchEspnScoreboard() async {
    final response = await http
        .get(
          Uri.parse('$espnBaseUrl/scoreboard'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('ESPN API timed out'),
        );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 429) {
      throw Exception('Too many requests. Please try again later.');
    } else {
      throw Exception('Failed to load games (${response.statusCode})');
    }
  }

  /// Fetch predictions from FastAPI backend
  Future<Map<String, dynamic>?> fetchPredictions() async {
    try {
      final response = await http
          .get(
            Uri.parse('$fastApiBaseUrl/predict/today'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Prediction API timed out'),
          );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Prediction API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Failed to fetch predictions: $e');
      return null;
    }
  }
}

/// Provider for the API service
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});


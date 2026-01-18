import 'dart:convert';
// ignore: unused_import - needed when using LOCAL DEVELOPMENT mode
import 'dart:io' show Platform;
// ignore: unused_shown_name - kIsWeb needed when using LOCAL DEVELOPMENT mode
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// API Service for handling all HTTP requests
class ApiService {
  // ===========================================================================
  // API CONFIGURATION - Toggle between Production and Local Development
  // ===========================================================================
  //
  // PRODUCTION MODE (default):
  //   - Uses Render-hosted API at https://nba-prediction-api-nq5b.onrender.com
  //   - Note: Free tier may take 30-60s to wake from cold start
  //
  // LOCAL DEVELOPMENT MODE:
  //   1. Start your local API server:
  //      cd C:\Users\sandy\Desktop\dev\Basketball_Prediction
  //      python -m uvicorn src.api.main:app --reload --port 8000
  //
  //   2. Comment out the PRODUCTION line and uncomment the LOCAL line below:
  //
  // ===========================================================================

  /// PRODUCTION - Uses Render-hosted API (DEFAULT)
  // static const String _baseUrl = 'https://nba-prediction-api-nq5b.onrender.com';

  /// LOCAL DEVELOPMENT - Uncomment below and comment out PRODUCTION above
  static String get _baseUrl {
    // Web browser: use localhost directly
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    // Android emulator: 10.0.2.2 maps to host machine's localhost
    else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    // iOS simulator / Desktop: use localhost
    else {
      return 'http://localhost:8000';
    }
  }

  /// Get the API base URL
  String get fastApiBaseUrl => _baseUrl;

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
  /// Note: Render free tier can take 30-60s to wake from cold start
  Future<Map<String, dynamic>?> fetchPredictions() async {
    debugPrint('Fetching predictions from: $fastApiBaseUrl/predict/today');
    try {
      final response = await http
          .get(
            Uri.parse('$fastApiBaseUrl/predict/today'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 90), // Increased for Render cold starts
            onTimeout: () => throw Exception('Prediction API timed out (90s)'),
          );

      debugPrint('Prediction API response: ${response.statusCode}');
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Prediction API error: ${response.statusCode} - ${response.body}');
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


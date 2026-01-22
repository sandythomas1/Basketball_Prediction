import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../Services/app_config.dart';

/// API Service for handling all HTTP requests.
///
/// Handles all network requests with proper error handling, timeouts,
/// and environment-aware configuration.
class ApiService {
  final AppConfig _config = AppConfig.instance;

  /// Get the API base URL based on environment and platform.
  String get fastApiBaseUrl => _config.getApiBaseUrl(isWeb: kIsWeb);

  /// ESPN API base URL (always same regardless of environment)
  String get espnBaseUrl => AppConfig.espnApiUrl;

  /// Fetch today's games from ESPN API.
  ///
  /// Throws [ApiException] on network or server errors.
  Future<Map<String, dynamic>> fetchEspnScoreboard() async {
    final now = DateTime.now();
    final dateParam = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    try {
      final response = await http
          .get(
            Uri.parse('$espnBaseUrl/scoreboard?dates=$dateParam'),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'NBA-Predictions-App/1.0',
            },
          )
          .timeout(
            Duration(seconds: AppConfig.espnTimeoutSeconds),
            onTimeout: () => throw ApiException(
              'ESPN API timed out',
              statusCode: 408,
              isTimeout: true,
            ),
          );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 429) {
        throw ApiException(
          'Too many requests. Please try again later.',
          statusCode: 429,
          isRateLimited: true,
        );
      } else {
        throw ApiException(
          'Failed to load games',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      if (AppConfig.enableDebugLogging) {
        debugPrint('ESPN API error: $e');
      }
      throw ApiException('Network error: ${e.runtimeType}');
    }
  }

  /// Fetch predictions from FastAPI backend.
  ///
  /// Returns null on error (graceful degradation).
  /// Note: Render free tier can take 30-60s to wake from cold start.
  Future<Map<String, dynamic>?> fetchPredictions() async {
    final url = '$fastApiBaseUrl/predict/today';

    if (AppConfig.enableDebugLogging) {
      debugPrint('Fetching predictions from: $url');
    }

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'NBA-Predictions-App/1.0',
            },
          )
          .timeout(
            Duration(seconds: AppConfig.apiLongTimeoutSeconds),
            onTimeout: () => throw ApiException(
              'Prediction API timed out',
              statusCode: 408,
              isTimeout: true,
            ),
          );

      if (AppConfig.enableDebugLogging) {
        debugPrint('Prediction API response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 429) {
        if (AppConfig.enableDebugLogging) {
          debugPrint('Rate limited by prediction API');
        }
        return null;
      } else {
        if (AppConfig.enableDebugLogging) {
          debugPrint('Prediction API error: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (AppConfig.enableDebugLogging) {
        debugPrint('Failed to fetch predictions: $e');
      }
      return null;
    }
  }
}

/// Custom exception for API errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isTimeout;
  final bool isRateLimited;

  ApiException(
    this.message, {
    this.statusCode,
    this.isTimeout = false,
    this.isRateLimited = false,
  });

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';

  /// User-friendly error message.
  String get userMessage {
    if (isTimeout) {
      return 'Request timed out. Please check your connection and try again.';
    }
    if (isRateLimited) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (statusCode != null && statusCode! >= 500) {
      return 'Server error. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }
}

/// Provider for the API service
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});


import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../Services/app_config.dart';
import '../Services/cache_service.dart';

/// API Service for handling all HTTP requests.
///
/// Sends the current Firebase ID token on every backend request so the
/// server can enforce authentication when FIREBASE_AUTH_REQUIRED=true.
class ApiService {
  final AppConfig _config = AppConfig.instance;

  String get fastApiBaseUrl => _config.getApiBaseUrl(isWeb: kIsWeb);
  String get espnBaseUrl => AppConfig.espnApiUrl;

  /// Build common headers, attaching a Firebase bearer token when available.
  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'Signal-Sports/2.0',
    };

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (_) {
      // Auth unavailable — proceed without token
    }
    return headers;
  }

  /// Returns the current date in PST/PDT as YYYYMMDD (for ESPN API).
  String _getPstDateCompact() {
    final pst = _nowInPst();
    return '${pst.year}${pst.month.toString().padLeft(2, '0')}${pst.day.toString().padLeft(2, '0')}';
  }

  /// Returns the current date in PST/PDT as YYYY-MM-DD (for backend API).
  String _getPstDateIso() {
    final pst = _nowInPst();
    return '${pst.year}-${pst.month.toString().padLeft(2, '0')}-${pst.day.toString().padLeft(2, '0')}';
  }

  /// Converts UTC now to PST (UTC-8) or PDT (UTC-7) based on US DST rules.
  DateTime _nowInPst() {
    final utc = DateTime.now().toUtc();
    return utc.subtract(Duration(hours: _isPdt(utc) ? 7 : 8));
  }

  /// Returns true if US daylight saving time (PDT) is active for [utc].
  /// DST starts on the second Sunday of March and ends the first Sunday of November.
  bool _isPdt(DateTime utc) {
    final year = utc.year;
    final marchFirst = DateTime.utc(year, 3, 1);
    // Second Sunday of March (day 1 = Monday in weekday, 7 = Sunday)
    final dstStart = marchFirst.add(
      Duration(days: (7 - (marchFirst.weekday % 7)) % 7 + 7),
    );
    final novFirst = DateTime.utc(year, 11, 1);
    // First Sunday of November
    final dstEnd = novFirst.add(
      Duration(days: (7 - (novFirst.weekday % 7)) % 7),
    );
    return utc.isAfter(dstStart) && utc.isBefore(dstEnd);
  }

  /// Fetch today's games + predictions in a single backend call.
  ///
  /// Falls back to null if the backend is unreachable so the caller can
  /// degrade to the ESPN-direct path.
  Future<Map<String, dynamic>?> fetchGamesWithPredictions() async {
    final url = '$fastApiBaseUrl/games/${_getPstDateIso()}/with-predictions';
    if (AppConfig.enableDebugLogging) {
      debugPrint('Fetching games+predictions from: $url');
    }

    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(
            Duration(seconds: AppConfig.apiLongTimeoutSeconds),
            onTimeout: () => throw ApiException(
              'Backend timed out',
              statusCode: 408,
              isTimeout: true,
            ),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        await CacheService.instance.saveGamesCache(response.body);
        return data;
      }
      if (AppConfig.enableDebugLogging) {
        debugPrint('Backend games+predictions: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      if (AppConfig.enableDebugLogging) {
        debugPrint('Backend games+predictions failed: $e');
      }
      return null;
    }
  }

  /// Fetch today's games from ESPN API (fallback when backend is down).
  Future<Map<String, dynamic>> fetchEspnScoreboard() async {
    final dateParam = _getPstDateCompact();

    try {
      final response = await http
          .get(
            Uri.parse('$espnBaseUrl/scoreboard?dates=$dateParam'),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Signal-Sports/2.0',
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

  /// Fetch predictions from FastAPI backend (fallback path).
  Future<Map<String, dynamic>?> fetchPredictions() async {
    final url = '$fastApiBaseUrl/predict/today';
    if (AppConfig.enableDebugLogging) {
      debugPrint('Fetching predictions from: $url');
    }

    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse(url), headers: headers)
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
      }
      return null;
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


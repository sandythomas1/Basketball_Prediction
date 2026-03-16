import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lightweight local cache that persists the most recent API responses
/// so the app can display stale data when the network is unavailable.
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  static const _gamesKey = 'cached_games_response';
  static const _gamesTimestampKey = 'cached_games_ts';

  final _storage = const FlutterSecureStorage();

  /// Maximum cache age before it's considered expired.
  static const Duration maxAge = Duration(hours: 2);

  /// Persist a raw JSON response string for the games endpoint.
  Future<void> saveGamesCache(String jsonBody) async {
    try {
      await _storage.write(key: _gamesKey, value: jsonBody);
      await _storage.write(
        key: _gamesTimestampKey,
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('CacheService: failed to write games cache: $e');
    }
  }

  /// Load the most recent cached games response, or null if expired / empty.
  Future<Map<String, dynamic>?> loadGamesCache() async {
    try {
      final tsRaw = await _storage.read(key: _gamesTimestampKey);
      if (tsRaw == null) return null;

      final ts = DateTime.tryParse(tsRaw);
      if (ts == null || DateTime.now().difference(ts) > maxAge) {
        return null;
      }

      final body = await _storage.read(key: _gamesKey);
      if (body == null || body.isEmpty) return null;

      return json.decode(body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('CacheService: failed to read games cache: $e');
      return null;
    }
  }

  /// Clear all cached data.
  Future<void> clear() async {
    await _storage.delete(key: _gamesKey);
    await _storage.delete(key: _gamesTimestampKey);
  }
}

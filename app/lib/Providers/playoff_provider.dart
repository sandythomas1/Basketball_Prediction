import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../Models/playoff_models.dart';
import '../Services/app_config.dart';

// ============================================================================
// Internal HTTP helpers (mirrors the pattern in ApiService)
// ============================================================================

Future<Map<String, String>> _authHeaders() async {
  final headers = <String, String>{
    'Accept': 'application/json',
    'User-Agent': 'Signal-Sports/2.0',
  };
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
  } catch (_) {}
  return headers;
}

Future<Map<String, dynamic>?> _getJson(String url) async {
  try {
    final headers = await _authHeaders();
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(Duration(seconds: AppConfig.apiLongTimeoutSeconds));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
  } catch (e) {
    debugPrint('Playoff API error [$url]: $e');
  }
  return null;
}

String _baseUrl() => AppConfig.instance.getApiBaseUrl(isWeb: false);

// ============================================================================
// Providers
// ============================================================================

/// Whether the playoffs tab should be shown.
/// Set to true once playoffBracketProvider confirms playoffs are active.
final playoffsActiveProvider = StateProvider<bool>((ref) => false);

/// Full bracket data provider.
final playoffBracketProvider =
    AsyncNotifierProvider<PlayoffBracketNotifier, PlayoffBracket?>(() {
  return PlayoffBracketNotifier();
});

class PlayoffBracketNotifier extends AsyncNotifier<PlayoffBracket?> {
  @override
  Future<PlayoffBracket?> build() async {
    // Check playoff status first
    final statusData = await _getJson('${_baseUrl()}/playoff/status');
    final active = statusData?['playoffs_active'] as bool? ?? false;
    ref.read(playoffsActiveProvider.notifier).state = active;
    if (!active) return null;

    final data = await _getJson('${_baseUrl()}/playoff/bracket');
    if (data == null) return null;
    return PlayoffBracket.fromJson(data);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final data = await _getJson('${_baseUrl()}/playoff/bracket');
      if (data == null) return null;
      return PlayoffBracket.fromJson(data);
    });
  }
}

/// Today's playoff games provider.
final todayPlayoffGamesProvider =
    AsyncNotifierProvider<TodayPlayoffGamesNotifier, List<PlayoffGame>>(() {
  return TodayPlayoffGamesNotifier();
});

class TodayPlayoffGamesNotifier extends AsyncNotifier<List<PlayoffGame>> {
  @override
  Future<List<PlayoffGame>> build() async {
    final active = ref.watch(playoffsActiveProvider);
    if (!active) return [];

    final data = await _getJson('${_baseUrl()}/playoff/predict/today');
    if (data == null) return [];
    final gamesData = data['games'] as List<dynamic>? ?? [];
    return gamesData
        .map((g) => PlayoffGame.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final data = await _getJson('${_baseUrl()}/playoff/predict/today');
      if (data == null) return <PlayoffGame>[];
      final gamesData = data['games'] as List<dynamic>? ?? [];
      return gamesData
          .map((g) => PlayoffGame.fromJson(g as Map<String, dynamic>))
          .toList();
    });
  }
}

/// Series detail provider — keyed by series ID.
final playoffSeriesProvider =
    AsyncNotifierProviderFamily<PlayoffSeriesNotifier, PlayoffSeriesDetail?, String>(
        PlayoffSeriesNotifier.new);

class PlayoffSeriesNotifier
    extends FamilyAsyncNotifier<PlayoffSeriesDetail?, String> {
  @override
  Future<PlayoffSeriesDetail?> build(String seriesId) async {
    final data = await _getJson('${_baseUrl()}/playoff/series/$seriesId');
    if (data == null) return null;
    return PlayoffSeriesDetail.fromJson(data);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final data = await _getJson('${_baseUrl()}/playoff/series/$arg');
      if (data == null) return null;
      return PlayoffSeriesDetail.fromJson(data);
    });
  }
}

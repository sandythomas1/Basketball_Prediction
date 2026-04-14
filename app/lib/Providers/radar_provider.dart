import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Models/radar_entry.dart';
import 'auth_provider.dart';

/// Streams all Recruit Radar entries from RTDB, sorted newest-first.
/// Requires the user to be authenticated; returns empty list for guests.
final radarEntriesProvider = StreamProvider<List<RadarEntry>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  return FirebaseDatabase.instance
      .ref('recruit_radar/entries')
      .onValue
      .map((event) {
    final raw = event.snapshot.value;
    if (raw == null) return <RadarEntry>[];

    final map = Map<String, dynamic>.from(raw as Map);
    final entries = map.values
        .map((v) => RadarEntry.fromJson(Map<String, dynamic>.from(v as Map)))
        .where((e) => e.playerName.isNotEmpty)
        .toList();

    // Newest entries first
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  });
});

/// Streams the ISO timestamp of the last job run (shown in the UI header).
final radarLastUpdatedProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  return FirebaseDatabase.instance
      .ref('recruit_radar/last_updated')
      .onValue
      .map((event) => event.snapshot.value as String?);
});

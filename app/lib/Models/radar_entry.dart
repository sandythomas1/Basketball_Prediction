/// Data model for a Recruit Radar entry — mirrors the Python RadarEntry Pydantic schema.
/// Stored in Firebase RTDB under recruit_radar/entries/{player-slug}.
class RadarEntry {
  final String playerName;
  final String schoolFrom;
  final String summary;
  final List<String> leadSchools;
  final List<String> visitDates;
  final double sentimentScore;
  final List<String> sourceSnippets;
  final String timestamp;

  const RadarEntry({
    required this.playerName,
    required this.schoolFrom,
    required this.summary,
    required this.leadSchools,
    required this.visitDates,
    required this.sentimentScore,
    required this.sourceSnippets,
    required this.timestamp,
  });

  factory RadarEntry.fromJson(Map<String, dynamic> json) {
    return RadarEntry(
      playerName: json['player_name'] as String? ?? '',
      schoolFrom: json['school_from'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      leadSchools: _toStringList(json['lead_schools']),
      visitDates: _toStringList(json['visit_dates']),
      sentimentScore: (json['sentiment_score'] as num?)?.toDouble() ?? 5.0,
      sourceSnippets: _toStringList(json['source_snippets']),
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'player_name': playerName,
        'school_from': schoolFrom,
        'summary': summary,
        'lead_schools': leadSchools,
        'visit_dates': visitDates,
        'sentiment_score': sentimentScore,
        'source_snippets': sourceSnippets,
        'timestamp': timestamp,
      };

  /// Human-readable relative timestamp: "2h ago", "just now", etc.
  String get relativeTime {
    if (timestamp.isEmpty) return '';
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Sentiment label based on score range.
  String get sentimentLabel {
    if (sentimentScore >= 8.0) return 'Hot';
    if (sentimentScore >= 6.0) return 'Warm';
    if (sentimentScore >= 4.0) return 'Neutral';
    return 'Cold';
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}

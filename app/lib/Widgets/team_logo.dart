import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// ESPN abbreviation mapping for NBA teams
/// Some teams use different abbreviations on ESPN's CDN
const Map<String, String> _espnAbbreviations = {
  // Standard abbreviations
  'Atlanta Hawks': 'atl',
  'Boston Celtics': 'bos',
  'Brooklyn Nets': 'bkn',
  'Charlotte Hornets': 'cha',
  'Chicago Bulls': 'chi',
  'Cleveland Cavaliers': 'cle',
  'Dallas Mavericks': 'dal',
  'Denver Nuggets': 'den',
  'Detroit Pistons': 'det',
  'Houston Rockets': 'hou',
  'Indiana Pacers': 'ind',
  'Los Angeles Clippers': 'lac',
  'Los Angeles Lakers': 'lal',
  'Memphis Grizzlies': 'mem',
  'Miami Heat': 'mia',
  'Milwaukee Bucks': 'mil',
  'Minnesota Timberwolves': 'min',
  'Oklahoma City Thunder': 'okc',
  'Orlando Magic': 'orl',
  'Philadelphia 76ers': 'phi',
  'Phoenix Suns': 'phx',
  'Portland Trail Blazers': 'por',
  'Sacramento Kings': 'sac',
  'Toronto Raptors': 'tor',
  'Utah Jazz': 'utah',
  // Teams with non-standard ESPN abbreviations
  'Golden State Warriors': 'gs', // ESPN uses 'gs' not 'gsw'
  'New Orleans Pelicans': 'no', // ESPN uses 'no' not 'nop'
  'New York Knicks': 'ny', // ESPN uses 'ny' not 'nyk'
  'San Antonio Spurs': 'sa', // ESPN uses 'sa' not 'sas'
  'Washington Wizards': 'wsh', // ESPN uses 'wsh' not 'was'
};

/// Get ESPN abbreviation for a team name
String getEspnAbbreviation(String teamName) {
  // Try exact match first
  if (_espnAbbreviations.containsKey(teamName)) {
    return _espnAbbreviations[teamName]!;
  }

  // Try case-insensitive match
  for (final entry in _espnAbbreviations.entries) {
    if (entry.key.toLowerCase() == teamName.toLowerCase()) {
      return entry.value;
    }
  }

  // Try partial match (e.g., "Lakers" matches "Los Angeles Lakers")
  for (final entry in _espnAbbreviations.entries) {
    if (entry.key.toLowerCase().contains(teamName.toLowerCase()) ||
        teamName.toLowerCase().contains(entry.key.split(' ').last.toLowerCase())) {
      return entry.value;
    }
  }

  // Default fallback - return 'nba' for generic logo
  return 'nba';
}

/// Widget to display NBA team logos from ESPN's CDN
class TeamLogo extends StatelessWidget {
  final String teamName;
  final double size;
  final Color? backgroundColor;
  final double borderRadius;

  const TeamLogo({
    super.key,
    required this.teamName,
    this.size = 32,
    this.backgroundColor,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final abbr = getEspnAbbreviation(teamName);
    final logoUrl = 'https://a.espncdn.com/i/teamlogos/nba/500/$abbr.png';

    // Use theme-aware background color
    final bgColor = backgroundColor ?? context.bgSecondary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: logoUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildFallback(context),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size * 0.5,
        height: size * 0.5,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(context.textMuted),
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Icon(
      Icons.sports_basketball,
      size: size * 0.6,
      color: AppColors.accentOrange,
    );
  }
}

/// Large team logo for detail screens
class TeamLogoLarge extends StatelessWidget {
  final String teamName;
  final double size;

  const TeamLogoLarge({
    super.key,
    required this.teamName,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return TeamLogo(
      teamName: teamName,
      size: size,
      borderRadius: 16,
      backgroundColor: context.bgCard,
    );
  }
}

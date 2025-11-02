"""
Example Usage of Basketball Database

This file demonstrates how to:
1. Initialize the database
2. Insert data into each table
3. Query data with various patterns
4. Use JOIN operations
5. Calculate statistics

Run this to see practical examples and learn the database API.
"""

from db_manager import DatabaseManager
from datetime import datetime, timedelta
import random


def example_1_basic_team_insertion():
    """
    Example 1: Adding teams to the database
    
    Learning Points:
    - Using the add_team() convenience method
    - Understanding required vs optional fields
    """
    print("\n" + "=" * 60)
    print("EXAMPLE 1: Adding Teams")
    print("=" * 60)
    
    db = DatabaseManager()
    
    # Add some NBA teams
    teams_data = [
        ('LAL', 'Los Angeles Lakers', 'West', 'Pacific', 'Los Angeles'),
        ('BOS', 'Boston Celtics', 'East', 'Atlantic', 'Boston'),
        ('GSW', 'Golden State Warriors', 'West', 'Pacific', 'San Francisco'),
        ('MIA', 'Miami Heat', 'East', 'Southeast', 'Miami'),
    ]
    
    for abbr, name, conf, div, city in teams_data:
        try:
            team_id = db.add_team(abbr, name, conf, div, city)
            print(f"✓ Added {name} (ID: {team_id})")
        except sqlite3.IntegrityError:
            print(f"  {name} already exists (skipped)")
    
    # Query all teams
    teams = db.execute_query("SELECT * FROM teams ORDER BY team_name")
    print(f"\nTotal teams in database: {len(teams)}")
    for team in teams:
        print(f"  - {team['team_abbr']}: {team['team_name']} ({team['conference']})")


def example_2_adding_games():
    """
    Example 2: Adding game results
    
    Learning Points:
    - Inserting related data (games reference teams)
    - Using foreign keys
    - Calculating derived fields (who won)
    """
    print("\n" + "=" * 60)
    print("EXAMPLE 2: Adding Games")
    print("=" * 60)
    
    db = DatabaseManager()
    
    # Get team IDs
    lal = db.get_team_by_abbr('LAL')
    bos = db.get_team_by_abbr('BOS')
    gsw = db.get_team_by_abbr('GSW')
    mia = db.get_team_by_abbr('MIA')
    
    if not all([lal, bos, gsw, mia]):
        print("⚠ Teams not found. Run example_1 first!")
        return
    
    # Create some sample games
    base_date = datetime(2024, 10, 22)  # NBA season start
    
    games = [
        {
            'external_game_id': 'NBA_2024_001',
            'game_date': base_date.strftime('%Y-%m-%d'),
            'season': '2024-25',
            'season_type': 'Regular Season',
            'home_team_id': lal['team_id'],
            'away_team_id': bos['team_id'],
            'home_team_score': 110,
            'away_team_score': 105,
            'home_team_won': 1,
            'away_team_won': 0,
            'overtime_periods': 0,
            'attendance': 18997
        },
        {
            'external_game_id': 'NBA_2024_002',
            'game_date': (base_date + timedelta(days=1)).strftime('%Y-%m-%d'),
            'season': '2024-25',
            'season_type': 'Regular Season',
            'home_team_id': gsw['team_id'],
            'away_team_id': mia['team_id'],
            'home_team_score': 118,
            'away_team_score': 112,
            'home_team_won': 1,
            'away_team_won': 0,
            'overtime_periods': 1,  # This game went to overtime!
            'attendance': 18064
        }
    ]
    
    for game in games:
        game_id = db.insert_one('games', game)
        home = db.get_team_by_abbr(
            db.execute_query("SELECT team_abbr FROM teams WHERE team_id = ?", 
                           (game['home_team_id'],))[0]['team_abbr']
        )
        away = db.get_team_by_abbr(
            db.execute_query("SELECT team_abbr FROM teams WHERE team_id = ?", 
                           (game['away_team_id'],))[0]['team_abbr']
        )
        
        ot_text = f" (OT{game['overtime_periods']})" if game['overtime_periods'] > 0 else ""
        print(f"✓ Added game: {away['team_abbr']} @ {home['team_abbr']}: "
              f"{game['away_team_score']}-{game['home_team_score']}{ot_text}")


def example_3_adding_player_stats():
    """
    Example 3: Adding player box scores
    
    Learning Points:
    - Inserting detailed statistical data
    - Relating players to games and teams
    - Working with multiple related records
    """
    print("\n" + "=" * 60)
    print("EXAMPLE 3: Adding Player Statistics")
    print("=" * 60)
    
    db = DatabaseManager()
    
    # Get a game to add stats for
    games = db.execute_query(
        "SELECT * FROM games WHERE external_game_id = 'NBA_2024_001'"
    )
    
    if not games:
        print("⚠ Game not found. Run example_2 first!")
        return
    
    game = games[0]
    
    # Sample player stats for the game (Lakers vs Celtics)
    player_stats = [
        {
            'game_id': game['game_id'],
            'team_id': game['home_team_id'],  # Lakers
            'player_id': 2544,
            'player_name': 'LeBron James',
            'minutes_played': 35.5,
            'points': 28,
            'field_goals_made': 11,
            'field_goals_attempted': 22,
            'field_goal_percentage': 50.0,
            'three_pointers_made': 2,
            'three_pointers_attempted': 6,
            'three_point_percentage': 33.3,
            'free_throws_made': 4,
            'free_throws_attempted': 5,
            'free_throw_percentage': 80.0,
            'offensive_rebounds': 1,
            'defensive_rebounds': 6,
            'total_rebounds': 7,
            'assists': 8,
            'steals': 2,
            'blocks': 1,
            'turnovers': 3,
            'personal_fouls': 2,
            'plus_minus': 12,
            'is_starter': 1
        },
        {
            'game_id': game['game_id'],
            'team_id': game['home_team_id'],  # Lakers
            'player_id': 1630175,
            'player_name': 'Anthony Davis',
            'minutes_played': 33.2,
            'points': 24,
            'field_goals_made': 10,
            'field_goals_attempted': 18,
            'field_goal_percentage': 55.6,
            'three_pointers_made': 0,
            'three_pointers_attempted': 2,
            'three_point_percentage': 0.0,
            'free_throws_made': 4,
            'free_throws_attempted': 6,
            'free_throw_percentage': 66.7,
            'offensive_rebounds': 3,
            'defensive_rebounds': 9,
            'total_rebounds': 12,
            'assists': 3,
            'steals': 1,
            'blocks': 3,
            'turnovers': 2,
            'personal_fouls': 3,
            'plus_minus': 8,
            'is_starter': 1
        }
    ]
    
    count = db.insert_many('player_stats', player_stats)
    print(f"✓ Added stats for {count} players")
    
    # Query and display the stats
    print("\nPlayer Performance:")
    for stat in player_stats:
        print(f"  {stat['player_name']}: {stat['points']} PTS, "
              f"{stat['total_rebounds']} REB, {stat['assists']} AST")


def example_4_season_averages():
    """
    Example 4: Storing season averages
    
    Learning Points:
    - Aggregated data storage
    - When to use averages vs raw data
    - Performance considerations
    """
    print("\n" + "=" * 60)
    print("EXAMPLE 4: Season Averages")
    print("=" * 60)
    
    db = DatabaseManager()
    
    lal = db.get_team_by_abbr('LAL')
    if not lal:
        print("⚠ Team not found. Run example_1 first!")
        return
    
    season_avg = {
        'player_id': 2544,
        'player_name': 'LeBron James',
        'team_id': lal['team_id'],
        'season': '2024-25',
        'season_type': 'Regular Season',
        'games_played': 55,
        'games_started': 55,
        'minutes_per_game': 35.2,
        'points_per_game': 25.8,
        'rebounds_per_game': 7.2,
        'assists_per_game': 8.1,
        'steals_per_game': 1.3,
        'blocks_per_game': 0.6,
        'turnovers_per_game': 3.5,
        'field_goal_percentage': 52.1,
        'three_point_percentage': 35.2,
        'free_throw_percentage': 75.3,
        'player_efficiency_rating': 24.5,
        'true_shooting_percentage': 61.2,
        'usage_rate': 30.5
    }
    
    avg_id = db.insert_one('season_averages', season_avg)
    print(f"✓ Added season averages for {season_avg['player_name']}")
    print(f"  PPG: {season_avg['points_per_game']} | "
          f"RPG: {season_avg['rebounds_per_game']} | "
          f"APG: {season_avg['assists_per_game']}")


def example_5_team_stats():
    """
    Example 5: Team statistics and metrics
    
    Learning Points:
    - Team-level aggregations
    - Advanced metrics (offensive/defensive ratings)
    - Performance tracking
    """
    print("\n" + "=" * 60)
    print("EXAMPLE 5: Team Statistics")
    print("=" * 60)
    
    db = DatabaseManager()
    
    lal = db.get_team_by_abbr('LAL')
    bos = db.get_team_by_abbr('BOS')
    
    if not all([lal, bos]):
        print("⚠ Teams not found. Run example_1 first!")
        return
    
    teams_stats = [
        {
            'team_id': lal['team_id'],
            'season': '2024-25',
            'season_type': 'Regular Season',
            'games_played': 25,
            'wins': 15,
            'losses': 10,
            'win_percentage': 0.600,
            'home_wins': 10,
            'home_losses': 3,
            'away_wins': 5,
            'away_losses': 7,
            'points_per_game': 115.2,
            'field_goal_percentage': 47.8,
            'three_point_percentage': 36.5,
            'free_throw_percentage': 78.2,
            'offensive_rebounds_per_game': 10.5,
            'assists_per_game': 25.8,
            'turnovers_per_game': 13.2,
            'opponent_points_per_game': 110.5,
            'opponent_field_goal_percentage': 45.2,
            'defensive_rebounds_per_game': 34.2,
            'steals_per_game': 7.8,
            'blocks_per_game': 5.2,
            'offensive_rating': 116.5,
            'defensive_rating': 111.8,
            'net_rating': 4.7,
            'pace': 99.5,
            'current_streak': 3,  # 3-game win streak
            'last_10_wins': 7,
            'last_10_losses': 3
        },
        {
            'team_id': bos['team_id'],
            'season': '2024-25',
            'season_type': 'Regular Season',
            'games_played': 25,
            'wins': 18,
            'losses': 7,
            'win_percentage': 0.720,
            'home_wins': 11,
            'home_losses': 2,
            'away_wins': 7,
            'away_losses': 5,
            'points_per_game': 118.5,
            'field_goal_percentage': 48.9,
            'three_point_percentage': 38.2,
            'free_throw_percentage': 81.5,
            'offensive_rebounds_per_game': 9.8,
            'assists_per_game': 27.2,
            'turnovers_per_game': 12.8,
            'opponent_points_per_game': 108.2,
            'opponent_field_goal_percentage': 44.1,
            'defensive_rebounds_per_game': 35.5,
            'steals_per_game': 8.5,
            'blocks_per_game': 6.1,
            'offensive_rating': 120.2,
            'defensive_rating': 109.5,
            'net_rating': 10.7,
            'pace': 98.2,
            'current_streak': -1,  # 1-game losing streak
            'last_10_wins': 8,
            'last_10_losses': 2
        }
    ]
    
    count = db.insert_many('team_stats', teams_stats)
    print(f"✓ Added stats for {count} teams\n")
    
    # Display comparison
    print("Team Comparison:")
    print(f"{'Team':<20} {'W-L':<10} {'PPG':<8} {'Net Rating':<12}")
    print("-" * 50)
    for stat in teams_stats:
        team = db.execute_query(
            "SELECT team_abbr FROM teams WHERE team_id = ?",
            (stat['team_id'],)
        )[0]
        print(f"{team['team_abbr']:<20} "
              f"{stat['wins']}-{stat['losses']:<8} "
              f"{stat['points_per_game']:<8.1f} "
              f"{stat['net_rating']:<12.1f}")


def example_6_complex_queries():
    """
    Example 6: Advanced queries with JOINs
    
    Learning Points:
    - Joining multiple tables
    - Filtering and aggregating
    - Real-world query patterns
    """
    print("\n" + "=" * 60)
    print("EXAMPLE 6: Complex Queries")
    print("=" * 60)
    
    db = DatabaseManager()
    
    # Query 1: Get all games with team names
    print("\n1. Recent games with team names:")
    query = """
        SELECT 
            g.game_date,
            home.team_abbr as home_team,
            away.team_abbr as away_team,
            g.home_team_score,
            g.away_team_score,
            CASE WHEN g.overtime_periods > 0 THEN 'OT' || g.overtime_periods ELSE '' END as ot
        FROM games g
        JOIN teams home ON g.home_team_id = home.team_id
        JOIN teams away ON g.away_team_id = away.team_id
        ORDER BY g.game_date DESC
        LIMIT 5
    """
    results = db.execute_query(query)
    for game in results:
        ot_text = f" ({game['ot']})" if game['ot'] else ""
        print(f"  {game['game_date']}: {game['away_team']} @ {game['home_team']} - "
              f"{game['away_team_score']}-{game['home_team_score']}{ot_text}")
    
    # Query 2: Top scorers in a game
    print("\n2. Top scorers from games:")
    query = """
        SELECT 
            ps.player_name,
            t.team_abbr,
            ps.points,
            ps.total_rebounds,
            ps.assists,
            g.game_date
        FROM player_stats ps
        JOIN teams t ON ps.team_id = t.team_id
        JOIN games g ON ps.game_id = g.game_id
        ORDER BY ps.points DESC
        LIMIT 5
    """
    results = db.execute_query(query)
    for player in results:
        print(f"  {player['player_name']} ({player['team_abbr']}): "
              f"{player['points']} PTS, {player['total_rebounds']} REB, "
              f"{player['assists']} AST - {player['game_date']}")
    
    # Query 3: Team win-loss records
    print("\n3. Team standings (from team_stats):")
    query = """
        SELECT 
            t.team_abbr,
            t.team_name,
            ts.wins,
            ts.losses,
            ts.win_percentage,
            ts.net_rating
        FROM team_stats ts
        JOIN teams t ON ts.team_id = t.team_id
        WHERE ts.season = '2024-25'
        ORDER BY ts.win_percentage DESC
    """
    results = db.execute_query(query)
    print(f"  {'Team':<25} {'Record':<12} {'Win%':<8} {'Net Rtg'}")
    print("  " + "-" * 55)
    for team in results:
        print(f"  {team['team_name']:<25} "
              f"{team['wins']}-{team['losses']:<10} "
              f"{team['win_percentage']:.3f}    "
              f"{team['net_rating']:+.1f}")


def example_7_database_insights():
    """
    Example 7: Getting insights from your data
    
    Learning Points:
    - Using aggregate functions (AVG, SUM, COUNT)
    - GROUP BY for summaries
    - Data analysis patterns
    """
    print("\n" + "=" * 60)
    print("EXAMPLE 7: Database Insights")
    print("=" * 60)
    
    db = DatabaseManager()
    
    # Get database statistics
    stats = db.get_database_stats()
    print("\nDatabase Contents:")
    for table, count in stats.items():
        print(f"  {table:<20}: {count:>5} records")
    
    # Average points per game across all player performances
    query = """
        SELECT 
            AVG(points) as avg_points,
            MAX(points) as max_points,
            MIN(points) as min_points
        FROM player_stats
    """
    results = db.execute_query(query)
    if results and results[0]['avg_points']:
        result = results[0]
        print(f"\nPlayer Scoring Statistics:")
        print(f"  Average PPG: {result['avg_points']:.1f}")
        print(f"  Highest: {result['max_points']}")
        print(f"  Lowest: {result['min_points']}")


def run_all_examples():
    """Run all examples in sequence"""
    import sqlite3
    
    print("\n" + "=" * 60)
    print("BASKETBALL DATABASE EXAMPLES")
    print("=" * 60)
    print("\nThese examples demonstrate how to use the basketball database.")
    print("Each example builds on the previous ones.\n")
    
    try:
        example_1_basic_team_insertion()
        example_2_adding_games()
        example_3_adding_player_stats()
        example_4_season_averages()
        example_5_team_stats()
        example_6_complex_queries()
        example_7_database_insights()
        
        print("\n" + "=" * 60)
        print("✓ All examples completed successfully!")
        print("=" * 60)
        print("\nNext steps:")
        print("1. Review the code in this file to understand each pattern")
        print("2. Try modifying the examples to add your own data")
        print("3. Practice writing your own queries")
        print("4. Start collecting real NBA data using an API")
        
    except Exception as e:
        print(f"\n⚠ Error: {e}")
        print("Make sure the database is properly initialized.")


if __name__ == "__main__":
    run_all_examples()


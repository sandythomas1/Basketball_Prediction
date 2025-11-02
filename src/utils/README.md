# Database Utils

This directory contains database management utilities for the Basketball Prediction project.

## Quick Start

### 1. Initialize the Database

```bash
cd src/utils
python db_manager.py
```

This will:
- Create the database file at `data/processed/basketball.db`
- Set up all tables (teams, games, player_stats, season_averages, team_stats)
- Display current database statistics

### 2. Run Examples

```bash
python database_examples.py
```

This will:
- Add sample NBA teams
- Insert example games
- Add player statistics
- Demonstrate complex queries
- Show you how to use the database API

### 3. Use in Your Code

```python
from utils.db_manager import DatabaseManager

# Initialize
db = DatabaseManager()
db.initialize_database()

# Add a team
team_id = db.add_team('LAL', 'Los Angeles Lakers', 'West', 'Pacific', 'Los Angeles')

# Query teams
lal = db.get_team_by_abbr('LAL')
print(lal['team_name'])  # "Los Angeles Lakers"

# Insert game data
game_data = {
    'external_game_id': 'NBA_2024_001',
    'game_date': '2024-10-22',
    'season': '2024-25',
    'season_type': 'Regular Season',
    'home_team_id': 1,
    'away_team_id': 2,
    'home_team_score': 110,
    'away_team_score': 105,
    'home_team_won': 1,
    'away_team_won': 0
}
game_id = db.insert_one('games', game_data)
```

## Files

- **`database_schema.sql`** - SQL schema definition with detailed comments
- **`db_manager.py`** - Python database manager class with helper functions
- **`database_examples.py`** - Comprehensive examples demonstrating usage
- **`DATABASE_GUIDE.md`** - In-depth learning guide (highly recommended!)

## Learning Resources

Start with the **DATABASE_GUIDE.md** file - it explains:
- Database design principles
- How each table works
- SQL fundamentals
- Python integration patterns
- Performance optimization
- Practice exercises

## Database Location

By default, the database is created at:
```
Basketball_Prediction/
  data/
    processed/
      basketball.db  <-- Your database file
```

You can view and edit it with tools like:
- [DB Browser for SQLite](https://sqlitebrowser.org/) (GUI)
- `sqlite3` command-line tool (comes with macOS/Linux)
- VS Code SQLite extension

## Common Tasks

### View Database Contents

```bash
sqlite3 ../../data/processed/basketball.db

# Inside sqlite3:
.tables                    # List all tables
.schema teams             # Show table structure
SELECT * FROM teams;      # Query data
.quit                     # Exit
```

### Reset Database

```python
from utils.db_manager import DatabaseManager

db = DatabaseManager()
db.clear_all_data()  # WARNING: Deletes all data
```

### Check Database Stats

```python
db = DatabaseManager()
stats = db.get_database_stats()
print(stats)
# {'teams': 30, 'games': 1230, 'player_stats': 24600, ...}
```

## Next Steps

1. ✅ Initialize database (`python db_manager.py`)
2. ✅ Run examples (`python database_examples.py`)
3. 📖 Read DATABASE_GUIDE.md to understand concepts
4. 🔧 Integrate with data collectors
5. 📊 Use for feature engineering in ML model

Happy coding! 🏀


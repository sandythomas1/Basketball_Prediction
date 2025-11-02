# Basketball Prediction Database - Setup Complete! 🏀

## 📦 What Was Built

A complete SQLite database system for storing basketball game data with 5 interconnected tables:

```
✅ teams           - Team information and metadata
✅ games           - Historical game results  
✅ player_stats    - Individual player box scores per game
✅ season_averages - Aggregated season statistics per player
✅ team_stats      - Team performance metrics and advanced analytics
```

## 📁 Files Created

### Core Database Files
- **`src/utils/database_schema.sql`** (450+ lines)
  - Complete SQL schema with detailed comments
  - All table definitions with constraints
  - Indexes for performance
  - Automatic timestamp triggers

- **`src/utils/db_manager.py`** (330+ lines)
  - Python DatabaseManager class
  - Helper functions for common operations
  - Safe parameterized queries
  - Connection management

- **`src/utils/database_examples.py`** (500+ lines)
  - 7 comprehensive examples
  - Sample data insertion
  - Complex query demonstrations
  - Real-world usage patterns

### Documentation & Learning Resources
- **`src/utils/DATABASE_GUIDE.md`** (900+ lines)
  - In-depth learning guide
  - Database concepts explained
  - SQL fundamentals
  - Performance optimization tips
  - Practice exercises with solutions

- **`src/utils/schema_diagram.txt`**
  - Visual ASCII diagram of all tables
  - Relationship mappings
  - Index documentation
  - Data flow explanation

- **`src/utils/README.md`**
  - Quick start guide
  - Common tasks
  - File descriptions

### Package Files
- **`src/utils/__init__.py`**
  - Makes utils a proper Python package
  - Exports DatabaseManager

### Database File
- **`data/processed/basketball.db`**
  - SQLite database file (created and ready!)
  - Contains all tables and indexes
  - Ready for data collection

## 🚀 Quick Start

### 1. Test Database Setup
```bash
cd /Users/sandythomas/Desktop/Basketball_Prediction/src/utils
python3 db_manager.py
```

### 2. Run Examples
```bash
python3 database_examples.py
```

This will:
- Add sample NBA teams (Lakers, Celtics, Warriors, Heat)
- Insert example games with scores
- Add player statistics (LeBron, AD, etc.)
- Demonstrate complex queries
- Show database capabilities

### 3. Use in Your Code
```python
from utils.db_manager import DatabaseManager

# Initialize
db = DatabaseManager()

# Add a team
db.add_team('LAL', 'Los Angeles Lakers', 'West', 'Pacific', 'Los Angeles')

# Query
lal = db.get_team_by_abbr('LAL')
print(lal['team_name'])  # "Los Angeles Lakers"

# Get database stats
stats = db.get_database_stats()
print(f"Teams: {stats['teams']}, Games: {stats['games']}")
```

## 📚 Learning Path

### Start Here: Read in This Order
1. **`src/utils/README.md`** (5 min)
   - Quick overview and basic usage

2. **`src/utils/schema_diagram.txt`** (10 min)
   - Visual understanding of table relationships

3. **`src/utils/DATABASE_GUIDE.md`** (60-90 min)
   - Deep dive into concepts
   - This is your main learning resource!
   - Read sections incrementally

4. **`src/utils/database_examples.py`** (30 min)
   - Run the examples
   - Study the code
   - Modify and experiment

### Practice Exercises

After reading the guide, try these:

**Exercise 1: Basic Operations**
```python
# 1. Add 3 more NBA teams
# 2. Query all teams in a specific conference
# 3. Count total teams in database
```

**Exercise 2: Game Data**
```python
# 1. Add a game between two teams
# 2. Query all games for a specific team
# 3. Find games that went to overtime
```

**Exercise 3: Complex Queries**
```python
# 1. Find average points scored by home teams
# 2. Get win-loss records for all teams
# 3. List top 5 scorers across all games
```

Solutions in `database_examples.py`!

## 🎓 Key Concepts You'll Learn

### Database Design
- **Primary Keys**: Unique identifiers (team_id, game_id)
- **Foreign Keys**: Relationships between tables
- **Normalization**: Organizing data efficiently
- **Denormalization**: Strategic duplication for performance

### SQL Skills
- **DDL** (Data Definition): CREATE TABLE, indexes, constraints
- **DML** (Data Manipulation): INSERT, UPDATE, DELETE, SELECT
- **Joins**: Combining data from multiple tables
- **Aggregation**: GROUP BY, HAVING, aggregate functions

### Python Integration
- **sqlite3 module**: Python's built-in SQLite interface
- **Context managers**: Proper connection handling
- **Parameterized queries**: SQL injection prevention
- **Row factories**: Dict-like access to results

### Performance
- **Indexes**: Speed up queries (especially WHERE, JOIN, ORDER BY)
- **Batch inserts**: Fast bulk data loading
- **Aggregation tables**: Pre-calculated statistics
- **Query optimization**: Writing efficient SQL

## 🔍 Database Tables Explained

### 1. teams (Foundation)
```
Purpose: Store team information
Key Field: team_abbr (e.g., 'LAL')
Records: ~30 (one per NBA team)
```

### 2. games (Historical Data)
```
Purpose: Record game results
Links To: teams (home and away)
Records: Thousands (all historical games)
Key for: Win/loss records, scores, dates
```

### 3. player_stats (Detailed Performance)
```
Purpose: Individual player box scores
Links To: games, teams
Records: Hundreds of thousands (players × games)
Key for: Points, rebounds, assists, shooting %
```

### 4. season_averages (Aggregated)
```
Purpose: Season-long player statistics
Links To: teams
Records: Thousands (players × seasons)
Key for: PPG, RPG, APG, efficiency metrics
Use for: Quick access to season performance
```

### 5. team_stats (Team Analytics)
```
Purpose: Team-level metrics and ratings
Links To: teams
Records: Hundreds (teams × seasons)
Key for: Win%, offensive/defensive ratings, pace
Use for: Team strength, prediction features
```

## 🎯 Next Steps for Your Project

### Phase 1: Data Collection (Current Phase)
```python
# 1. Set up NBA API client (nba_api, balldontlie, etc.)
# 2. Write collectors to fetch:
#    - Team data
#    - Game schedules and results
#    - Player box scores
# 3. Populate your database
```

### Phase 2: Feature Engineering
```python
# Use database to create ML features:
# - Rolling averages (last 5 games, last 10 games)
# - Home/away splits
# - Head-to-head history
# - Rest days between games
# - Injury reports (if available)
```

### Phase 3: Model Training
```python
# Query features from database
# Train prediction models:
# - Logistic Regression (baseline)
# - Random Forest
# - XGBoost
# - Neural Networks
```

### Phase 4: Predictions
```python
# Real-time predictions:
# - Fetch today's matchups
# - Load recent team/player stats
# - Generate win probability predictions
```

## 🛠 Tools & Resources

### Database Browsers
- **DB Browser for SQLite**: https://sqlitebrowser.org/
  - Free, cross-platform GUI
  - Visualize tables and relationships
  - Run queries interactively

- **SQLite CLI**:
  ```bash
  sqlite3 data/processed/basketball.db
  .tables              # List tables
  .schema teams        # View structure
  SELECT * FROM teams; # Query data
  ```

### Data Sources for Basketball
- **nba_api**: Official NBA stats Python wrapper
- **Basketball Reference**: Historical data (scraping)
- **balldontlie.io**: Free NBA API
- **ESPN API**: Unofficial but comprehensive

### Learning SQL
- **SQLZoo**: Interactive SQL tutorials
- **SQLite Documentation**: Comprehensive reference
- **LeetCode Database**: Practice problems

## ✨ Database Features

### Implemented Features
✅ Complete schema with all relationships  
✅ Foreign key constraints for data integrity  
✅ Indexes on frequently queried columns  
✅ CHECK constraints for data validation  
✅ Automatic timestamp updates via triggers  
✅ UNIQUE constraints to prevent duplicates  
✅ CASCADE deletes for cleanup  
✅ Python API with helper methods  
✅ Parameterized queries (SQL injection safe)  
✅ Connection pooling via context managers  

### Design Highlights
- **Flexible**: Handles trades (player team changes)
- **Extensible**: Easy to add new columns/tables
- **Performant**: Optimized indexes for common queries
- **Safe**: Constraints prevent bad data
- **Educational**: Extensive comments and documentation

## 📊 Example Queries You Can Run

```sql
-- Get all Lakers games this season
SELECT g.game_date, t_opp.team_abbr as opponent, 
       g.home_team_score, g.away_team_score
FROM games g
JOIN teams t_home ON g.home_team_id = t_home.team_id
JOIN teams t_away ON g.away_team_id = t_away.team_id
JOIN teams t_opp ON (g.away_team_id = t_opp.team_id)
WHERE t_home.team_abbr = 'LAL' AND g.season = '2024-25';

-- Top scorers in database
SELECT player_name, AVG(points) as ppg, COUNT(*) as games
FROM player_stats
GROUP BY player_id, player_name
HAVING COUNT(*) >= 10
ORDER BY ppg DESC
LIMIT 10;

-- Team win percentages
SELECT t.team_name, ts.wins, ts.losses, 
       ROUND(ts.win_percentage * 100, 1) || '%' as win_pct
FROM team_stats ts
JOIN teams t ON ts.team_id = t.team_id
WHERE ts.season = '2024-25'
ORDER BY ts.win_percentage DESC;
```

## 🎉 You're All Set!

Your basketball prediction database is fully set up and ready to use. Here's what you have:

✅ Professional database schema  
✅ Python API for easy interaction  
✅ Comprehensive documentation  
✅ Working examples  
✅ Learning resources  

**Start exploring by:**
1. Running the examples: `python3 src/utils/database_examples.py`
2. Reading the guide: Open `src/utils/DATABASE_GUIDE.md`
3. Experimenting: Modify examples, add your own data
4. Building: Create data collectors to populate with real NBA data

## 💡 Tips for Learning Without AI

Since you want to learn without heavy AI assistance:

1. **Read First**: Go through DATABASE_GUIDE.md thoroughly
2. **Type Manually**: Don't copy-paste, type queries yourself
3. **Break Things**: Experiment, make mistakes, debug
4. **Reference Examples**: Use database_examples.py as a guide
5. **Google Concepts**: Look up SQL concepts you don't understand
6. **Practice Daily**: Write 3-5 queries per day
7. **Build Gradually**: Start simple, add complexity over time

## 📞 Getting Help

- SQLite Docs: https://www.sqlite.org/docs.html
- Python sqlite3: https://docs.python.org/3/library/sqlite3.html
- SQL Tutorial: https://www.sqlitetutorial.net/
- Database Design: Search "database normalization"

---

**Built with**: SQLite 3, Python 3, Best Practices  
**Ready for**: Data collection, feature engineering, ML modeling  
**Database location**: `data/processed/basketball.db`

Happy coding! 🏀📊🚀


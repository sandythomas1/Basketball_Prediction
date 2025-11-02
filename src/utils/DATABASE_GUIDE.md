# Basketball Database Design Guide

This guide explains the database schema design for the basketball prediction system. Understanding these concepts will help you work with databases effectively in any project.

## 🎯 Learning Objectives

By working with this database, you'll learn:
1. **Relational database design** - How to structure data efficiently
2. **SQL fundamentals** - Creating tables, queries, and relationships
3. **Data normalization** - Avoiding redundancy and maintaining integrity
4. **Python database integration** - Using sqlite3 effectively
5. **Performance optimization** - Indexes and query patterns

---

## 📊 Database Schema Overview

### Entity Relationship Diagram (ERD) Concept

```
┌─────────────┐         ┌──────────────┐         ┌──────────────────┐
│   TEAMS     │◄────────│    GAMES     │────────►│  PLAYER_STATS    │
│             │         │              │         │                  │
│ • team_id   │         │ • game_id    │         │ • stat_id        │
│ • team_abbr │         │ • home_team  │         │ • player_id      │
│ • team_name │         │ • away_team  │         │ • game_id        │
└──────┬──────┘         │ • scores     │         │ • statistics     │
       │                └──────────────┘         └──────────────────┘
       │
       ├──────────────┐
       │              │
       ▼              ▼
┌──────────────┐  ┌──────────────┐
│ SEASON_AVG   │  │ TEAM_STATS   │
│              │  │              │
│ • player_id  │  │ • team_id    │
│ • season     │  │ • season     │
│ • averages   │  │ • metrics    │
└──────────────┘  └──────────────┘
```

---

## 📋 Table Descriptions

### 1. **TEAMS** - Core Reference Table

**Purpose**: Store information about basketball teams

**Key Concepts**:
- **Primary Key**: `team_id` - uniquely identifies each team
- **Unique Constraint**: `team_abbr` - prevents duplicate abbreviations
- **CHECK Constraint**: Ensures `conference` is only 'East' or 'West'

**Why This Design?**:
- Teams are referenced by other tables (games, stats)
- Using `team_id` as a number is more efficient than storing "Lakers" repeatedly
- This is called **normalization** - storing data in one place

```sql
Example:
team_id | team_abbr | team_name          | conference
--------|-----------|--------------------|-----------
1       | LAL       | Los Angeles Lakers | West
2       | BOS       | Boston Celtics     | East
```

**Learning Note**: We use `team_id` (integer) as the primary key rather than `team_abbr` (text) because:
- Integer comparisons are faster
- Takes less storage space
- Keys never need to change (what if a team changes abbreviation?)

---

### 2. **GAMES** - Game Results

**Purpose**: Record every basketball game played

**Key Concepts**:
- **Foreign Keys**: `home_team_id` and `away_team_id` link to `teams` table
- **Referential Integrity**: Can't delete a team if games reference it
- **CHECK Constraint**: Home and away teams must be different

**Why This Design?**:
- Stores both teams' perspectives of the same game
- `external_game_id` allows syncing with external APIs
- Date indexing enables fast time-based queries

```sql
Example:
game_id | game_date  | home_team_id | away_team_id | home_score | away_score
--------|------------|--------------|--------------|------------|------------
1       | 2024-10-22 | 1 (LAL)      | 2 (BOS)      | 110        | 105
```

**Learning Note**: We store `home_team_id` and `away_team_id` separately rather than having two rows per game because:
- Avoids data duplication (score, date, etc.)
- Makes queries simpler (one row = one game)
- Easier to maintain data consistency

---

### 3. **PLAYER_STATS** - Individual Game Performances

**Purpose**: Box score statistics for each player in each game

**Key Concepts**:
- **Composite Unique Constraint**: `(game_id, player_id)` ensures one stat line per player per game
- **Multiple Foreign Keys**: Links to both `games` and `teams`
- **Calculated Fields**: Some fields like percentages can be derived from others

**Why This Design?**:
- Detailed statistical tracking for machine learning features
- Can aggregate to create season averages
- Enables player performance analysis

```sql
Example:
stat_id | game_id | player_id | player_name   | points | rebounds | assists
--------|---------|-----------|---------------|--------|----------|--------
1       | 1       | 2544      | LeBron James  | 28     | 7        | 8
2       | 1       | 1630175   | Anthony Davis | 24     | 12       | 3
```

**Learning Note**: We store both raw counts (field_goals_made) and percentages because:
- Raw counts are used for aggregation
- Percentages are convenient for queries
- Recalculating percentages every time is slow

---

### 4. **SEASON_AVERAGES** - Aggregated Player Data

**Purpose**: Pre-calculated season statistics per player

**Key Concepts**:
- **Aggregation Table**: Stores computed averages
- **Denormalization**: Duplicates info for performance
- **Trade-offs**: More storage for faster queries

**Why This Design?**:
- Calculating averages from thousands of games is slow
- Machine learning models need quick access to season stats
- Updates happen infrequently (once per game or weekly)

```sql
Example:
avg_id | player_id | season  | games_played | points_per_game | rebounds_per_game
-------|-----------|---------|--------------|-----------------|------------------
1      | 2544      | 2024-25 | 55           | 25.8            | 7.2
```

**Learning Note**: This is **denormalization** - storing derived data:
- **Pros**: Much faster queries (no calculation needed)
- **Cons**: Must update when new games added
- **Use Case**: When reads >> writes (we query often, update rarely)

---

### 5. **TEAM_STATS** - Team Performance Metrics

**Purpose**: Aggregated team statistics and advanced metrics

**Key Concepts**:
- **Advanced Analytics**: Offensive/defensive ratings, pace, net rating
- **Historical Tracking**: Win streaks, last 10 games
- **Unique Constraint**: One row per team per season

**Why This Design?**:
- Teams are the primary prediction unit
- Advanced metrics are expensive to calculate repeatedly
- Critical for feature engineering in ML models

```sql
Example:
team_stat_id | team_id | season  | wins | losses | net_rating | pace
-------------|---------|---------|------|--------|------------|------
1            | 1       | 2024-25 | 15   | 10     | +4.7       | 99.5
```

**Learning Note**: Advanced metrics like "Offensive Rating" (points per 100 possessions):
- Require complex calculations across many games
- Are better pre-calculated and stored
- Get updated periodically (e.g., after each game day)

---

## 🔑 Key Database Concepts Explained

### 1. Primary Keys

**What**: A column that uniquely identifies each row
**Why**: Enables efficient lookups and relationships
**Example**: `team_id`, `game_id`, `stat_id`

```sql
-- Each team has a unique ID
team_id | team_name
--------|------------------
1       | Lakers
2       | Celtics
-- No two teams can have the same team_id
```

### 2. Foreign Keys

**What**: A column that references a primary key in another table
**Why**: Creates relationships and maintains data integrity
**Example**: `home_team_id` in `games` references `team_id` in `teams`

```sql
-- Foreign key relationship
FOREIGN KEY (home_team_id) REFERENCES teams(team_id)

-- This means:
-- - home_team_id must exist in teams table
-- - Can't delete a team if games reference it (or CASCADE deletes games too)
-- - Maintains referential integrity
```

**Real-world analogy**: Like how a library book has a checkout card with a member ID - that member ID must exist in the members database.

### 3. Indexes

**What**: A data structure that makes queries faster
**Why**: Without indexes, database scans every row (slow)
**Example**: Index on `game_date` makes date-range queries fast

```sql
-- Without index: Scan all 10,000 games ❌
-- With index: Jump directly to date range ✅
CREATE INDEX idx_games_date ON games(game_date);
```

**Real-world analogy**: Like an index in a textbook - instead of reading every page to find "Lakers", you check the index and jump to page 234.

**When to create indexes**:
- Columns frequently used in WHERE clauses
- Foreign key columns (for joins)
- Columns used in ORDER BY

**Trade-offs**:
- Faster reads, slower writes
- Takes extra storage
- Don't over-index (creates maintenance overhead)

### 4. Constraints

**What**: Rules enforced by the database
**Why**: Prevents invalid data from being inserted

**Types**:

```sql
-- PRIMARY KEY: Must be unique and not null
team_id INTEGER PRIMARY KEY

-- UNIQUE: Must be unique (but can be null)
team_abbr TEXT UNIQUE

-- NOT NULL: Cannot be empty
team_name TEXT NOT NULL

-- CHECK: Must meet condition
conference TEXT CHECK(conference IN ('East', 'West'))

-- FOREIGN KEY: Must reference existing row
FOREIGN KEY (home_team_id) REFERENCES teams(team_id)

-- DEFAULT: Automatic value if not provided
overtime_periods INTEGER DEFAULT 0
```

**Learning Note**: Constraints are better than application-level validation because:
- Enforced even if data comes from different sources
- Prevents bugs from bad data
- Self-documenting (schema shows rules)

### 5. Transactions

**What**: A group of operations that either all succeed or all fail
**Why**: Maintains data consistency

```python
# Example: Adding a game and player stats together
with db.get_connection() as conn:
    # Start transaction
    game_id = conn.execute("INSERT INTO games ...")
    conn.execute("INSERT INTO player_stats ...")
    conn.commit()  # Both succeed
    # If anything fails, both are rolled back
```

**Real-world analogy**: Like a bank transfer - money leaves one account and enters another, or neither happens. Never half-done.

---

## 🎓 SQL Fundamentals

### Basic Queries

```sql
-- SELECT: Retrieve data
SELECT team_name, conference FROM teams;

-- WHERE: Filter rows
SELECT * FROM teams WHERE conference = 'West';

-- ORDER BY: Sort results
SELECT * FROM games ORDER BY game_date DESC;

-- LIMIT: Get first N rows
SELECT * FROM games ORDER BY game_date DESC LIMIT 10;
```

### Joins

Joins combine data from multiple tables:

```sql
-- Get games with team names (not just IDs)
SELECT 
    g.game_date,
    home.team_name as home_team,
    away.team_name as away_team,
    g.home_team_score,
    g.away_team_score
FROM games g
JOIN teams home ON g.home_team_id = home.team_id
JOIN teams away ON g.away_team_id = away.team_id;
```

**Result**:
```
game_date  | home_team        | away_team      | home_score | away_score
-----------|------------------|----------------|------------|------------
2024-10-22 | Los Angeles Lakers| Boston Celtics | 110        | 105
```

**Join Types**:
- **INNER JOIN**: Only matching rows (most common)
- **LEFT JOIN**: All rows from left table, nulls for missing matches
- **RIGHT JOIN**: All rows from right table
- **FULL JOIN**: All rows from both tables

### Aggregation

```sql
-- Count games per team
SELECT team_id, COUNT(*) as game_count
FROM games
WHERE home_team_id = team_id OR away_team_id = team_id
GROUP BY team_id;

-- Average points per player
SELECT player_name, AVG(points) as avg_points
FROM player_stats
GROUP BY player_name
HAVING AVG(points) > 20  -- Filter after grouping
ORDER BY avg_points DESC;
```

**Aggregate Functions**:
- `COUNT(*)`: Count rows
- `SUM(column)`: Total
- `AVG(column)`: Average
- `MAX(column)`: Maximum
- `MIN(column)`: Minimum

---

## 💻 Python Integration Patterns

### 1. Using Context Managers (Recommended)

```python
# Context manager ensures connection closes even if error occurs
with db.get_connection() as conn:
    cursor = conn.execute("SELECT * FROM teams")
    results = cursor.fetchall()
# Connection automatically closed here
```

### 2. Parameterized Queries (CRITICAL)

```python
# ✅ GOOD: Parameterized (safe from SQL injection)
team_abbr = "LAL"
db.execute_query("SELECT * FROM teams WHERE team_abbr = ?", (team_abbr,))

# ❌ BAD: String formatting (vulnerable to SQL injection)
db.execute_query(f"SELECT * FROM teams WHERE team_abbr = '{team_abbr}'")
```

**Why parameterized queries?**
- Prevents SQL injection attacks
- Handles special characters automatically
- Database can cache query plans (faster)

**SQL Injection Example**:
```python
# User input: "LAL' OR '1'='1"
# Bad query becomes:
"SELECT * FROM teams WHERE team_abbr = 'LAL' OR '1'='1'"
# This returns ALL teams! Security breach!

# With parameters, it safely looks for literal string "LAL' OR '1'='1"
```

### 3. Row Factory for Dict-like Access

```python
conn = sqlite3.connect('basketball.db')
conn.row_factory = sqlite3.Row  # Enable row factory

cursor = conn.execute("SELECT * FROM teams WHERE team_id = 1")
team = cursor.fetchone()

# Access by column name
print(team['team_name'])  # "Los Angeles Lakers"
print(team['conference'])  # "West"

# Or by index
print(team[0])  # team_id
```

---

## 🚀 Performance Optimization Tips

### 1. Use Indexes Strategically

```sql
-- If you frequently query by date range
CREATE INDEX idx_games_date ON games(game_date);

-- If you often filter by player
CREATE INDEX idx_player_stats_player ON player_stats(player_id);
```

### 2. Batch Inserts

```python
# ✅ GOOD: Insert 1000 rows in one transaction
db.insert_many('player_stats', stats_list)

# ❌ BAD: 1000 separate transactions (very slow)
for stat in stats_list:
    db.insert_one('player_stats', stat)
```

### 3. Use Aggregation Tables

```python
# ✅ GOOD: Pre-calculated season averages
db.execute_query("SELECT * FROM season_averages WHERE player_id = ?", (player_id,))

# ❌ BAD: Calculate on the fly (slow for many games)
db.execute_query("""
    SELECT AVG(points), AVG(rebounds), AVG(assists)
    FROM player_stats
    WHERE player_id = ?
""", (player_id,))
```

### 4. Limit Result Sets

```sql
-- Get only what you need
SELECT team_name, wins, losses FROM team_stats
WHERE season = '2024-25'
LIMIT 10;

-- Not: SELECT * (wastes memory loading unused columns)
```

---

## 🛠 Common Operations

### Initialize Database

```python
from utils.db_manager import DatabaseManager

db = DatabaseManager()
db.initialize_database()
```

### Add Teams

```python
db.add_team('LAL', 'Los Angeles Lakers', 'West', 'Pacific', 'Los Angeles')
```

### Add Game

```python
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

### Query with JOIN

```python
query = """
    SELECT 
        g.game_date,
        home.team_abbr as home_team,
        g.home_team_score
    FROM games g
    JOIN teams home ON g.home_team_id = home.team_id
    ORDER BY g.game_date DESC
    LIMIT 5
"""
recent_games = db.execute_query(query)
for game in recent_games:
    print(f"{game['game_date']}: {game['home_team']} {game['home_team_score']}")
```

---

## 📚 Learning Path

### Phase 1: Basics (You are here!)
- [x] Understand table structure
- [x] Learn primary/foreign keys
- [x] Practice basic SELECT queries
- [ ] Run `database_examples.py` to see examples

### Phase 2: Intermediate
- [ ] Write complex JOIN queries
- [ ] Practice aggregation (GROUP BY, HAVING)
- [ ] Understand indexes and when to use them
- [ ] Collect real NBA data via API

### Phase 3: Advanced
- [ ] Query optimization techniques
- [ ] Design your own tables for new features
- [ ] Implement data validation
- [ ] Build automated data pipeline

---

## 🧪 Practice Exercises

### Exercise 1: Basic Queries
```sql
-- 1. Get all teams in the Western Conference
-- 2. Find games where home team scored > 120 points
-- 3. List players who scored > 30 points in a game
```

### Exercise 2: Joins
```sql
-- 1. Get all games for Lakers with opponent names
-- 2. Find top 5 scorers across all games
-- 3. List teams with their win-loss records
```

### Exercise 3: Aggregation
```sql
-- 1. Calculate average points per game by team
-- 2. Find players with most total rebounds
-- 3. Determine home vs away win percentages
```

**Answers** in `database_examples.py` - try writing them yourself first!

---

## 📖 Additional Resources

### SQLite Documentation
- [SQLite Tutorial](https://www.sqlitetutorial.net/)
- [SQLite Python docs](https://docs.python.org/3/library/sqlite3.html)

### Database Design
- Database normalization (1NF, 2NF, 3NF)
- Entity-Relationship Diagrams (ERD)
- ACID properties (Atomicity, Consistency, Isolation, Durability)

### SQL Practice
- [SQLZoo](https://sqlzoo.net/) - Interactive SQL tutorial
- [LeetCode Database](https://leetcode.com/problemset/database/) - SQL problems

---

## ❓ FAQ

### Q: Why SQLite instead of PostgreSQL/MySQL?
**A**: SQLite is perfect for this project because:
- No server setup required (file-based)
- Great for development and small-to-medium datasets
- Easy to backup (just copy the .db file)
- Fast for read-heavy workloads
- Can always migrate to PostgreSQL later if needed

### Q: Should I store calculated stats or compute them on-the-fly?
**A**: It depends:
- **Store**: If calculations are expensive and data rarely changes (season averages)
- **Compute**: If calculations are simple or data changes frequently
- **Hybrid**: Store for common queries, compute for ad-hoc analysis

### Q: How do I handle player trades mid-season?
**A**: The current schema handles this:
- `player_stats` links to `team_id` per game
- `season_averages` can have multiple rows per player (one per team)
- Query: Get all teams a player played for in a season

### Q: What about playoff vs regular season stats?
**A**: Use the `season_type` field:
- 'Regular Season'
- 'Playoffs'
- Separate rows in `season_averages` and `team_stats`

---

## 🎯 Next Steps

1. **Run the examples**: `python src/utils/database_examples.py`
2. **Explore the data**: Open `basketball.db` in a SQLite browser
3. **Write your own queries**: Practice with the data
4. **Collect real data**: Use NBA API to populate tables
5. **Build features**: Use this data for your ML model

Good luck with your learning journey! 🏀


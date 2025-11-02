-- Basketball Prediction Database Schema
-- This schema is designed for storing NBA/basketball game data for prediction modeling

-- =============================================================================
-- TEAMS TABLE
-- Stores team information and metadata
-- =============================================================================
CREATE TABLE IF NOT EXISTS teams (
    team_id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Auto-incrementing unique identifier
    team_abbr TEXT NOT NULL UNIQUE,              -- Team abbreviation (e.g., 'LAL', 'BOS')
    team_name TEXT NOT NULL,                     -- Full team name (e.g., 'Los Angeles Lakers')
    conference TEXT CHECK(conference IN ('East', 'West')),  -- Conference constraint
    division TEXT,                               -- Division name (e.g., 'Pacific')
    city TEXT,                                   -- Team city
    arena TEXT,                                  -- Home arena name
    founded_year INTEGER,                        -- Year team was founded
    is_active BOOLEAN DEFAULT 1,                 -- Track if team is currently active
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast lookups by abbreviation (commonly used in APIs)
CREATE INDEX IF NOT EXISTS idx_teams_abbr ON teams(team_abbr);
CREATE INDEX IF NOT EXISTS idx_teams_conference ON teams(conference);


-- =============================================================================
-- GAMES TABLE
-- Stores historical game results
-- =============================================================================
CREATE TABLE IF NOT EXISTS games (
    game_id INTEGER PRIMARY KEY AUTOINCREMENT,
    external_game_id TEXT UNIQUE,                -- ID from external API (e.g., NBA.com)
    game_date DATE NOT NULL,                     -- Date of the game
    season TEXT NOT NULL,                        -- Season identifier (e.g., '2023-24')
    season_type TEXT CHECK(season_type IN ('Regular Season', 'Playoffs', 'Preseason')),
    
    -- Home team information
    home_team_id INTEGER NOT NULL,
    home_team_score INTEGER,
    home_team_won BOOLEAN,
    
    -- Away team information
    away_team_id INTEGER NOT NULL,
    away_team_score INTEGER,
    away_team_won BOOLEAN,
    
    -- Game metadata
    overtime_periods INTEGER DEFAULT 0,          -- Number of OT periods (0 if none)
    attendance INTEGER,
    arena_name TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key constraints ensure referential integrity
    FOREIGN KEY (home_team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
    FOREIGN KEY (away_team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
    
    -- Constraint: home and away teams must be different
    CHECK (home_team_id != away_team_id)
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_games_date ON games(game_date);
CREATE INDEX IF NOT EXISTS idx_games_season ON games(season);
CREATE INDEX IF NOT EXISTS idx_games_home_team ON games(home_team_id);
CREATE INDEX IF NOT EXISTS idx_games_away_team ON games(away_team_id);
CREATE INDEX IF NOT EXISTS idx_games_external_id ON games(external_game_id);


-- =============================================================================
-- PLAYER_STATS TABLE
-- Stores individual player box scores for each game
-- =============================================================================
CREATE TABLE IF NOT EXISTS player_stats (
    stat_id INTEGER PRIMARY KEY AUTOINCREMENT,
    game_id INTEGER NOT NULL,
    team_id INTEGER NOT NULL,
    player_id INTEGER NOT NULL,                  -- Player identifier
    player_name TEXT NOT NULL,
    
    -- Playing time
    minutes_played REAL,                         -- Minutes played (can be decimal)
    seconds_played INTEGER,
    
    -- Scoring statistics
    points INTEGER DEFAULT 0,
    field_goals_made INTEGER DEFAULT 0,
    field_goals_attempted INTEGER DEFAULT 0,
    field_goal_percentage REAL,
    three_pointers_made INTEGER DEFAULT 0,
    three_pointers_attempted INTEGER DEFAULT 0,
    three_point_percentage REAL,
    free_throws_made INTEGER DEFAULT 0,
    free_throws_attempted INTEGER DEFAULT 0,
    free_throw_percentage REAL,
    
    -- Rebounding statistics
    offensive_rebounds INTEGER DEFAULT 0,
    defensive_rebounds INTEGER DEFAULT 0,
    total_rebounds INTEGER DEFAULT 0,
    
    -- Playmaking and defense
    assists INTEGER DEFAULT 0,
    steals INTEGER DEFAULT 0,
    blocks INTEGER DEFAULT 0,
    turnovers INTEGER DEFAULT 0,
    personal_fouls INTEGER DEFAULT 0,
    
    -- Advanced metrics
    plus_minus INTEGER,                          -- +/- while on court
    
    -- Metadata
    is_starter BOOLEAN DEFAULT 0,                -- Starting lineup indicator
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
    
    -- Ensure unique stat entry per player per game
    UNIQUE(game_id, player_id)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_player_stats_game ON player_stats(game_id);
CREATE INDEX IF NOT EXISTS idx_player_stats_player ON player_stats(player_id);
CREATE INDEX IF NOT EXISTS idx_player_stats_team ON player_stats(team_id);


-- =============================================================================
-- SEASON_AVERAGES TABLE
-- Aggregated season statistics per player
-- =============================================================================
CREATE TABLE IF NOT EXISTS season_averages (
    avg_id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id INTEGER NOT NULL,
    player_name TEXT NOT NULL,
    team_id INTEGER NOT NULL,
    season TEXT NOT NULL,
    season_type TEXT CHECK(season_type IN ('Regular Season', 'Playoffs')) DEFAULT 'Regular Season',
    
    -- Counting stats
    games_played INTEGER DEFAULT 0,
    games_started INTEGER DEFAULT 0,
    
    -- Per-game averages
    minutes_per_game REAL,
    points_per_game REAL,
    rebounds_per_game REAL,
    assists_per_game REAL,
    steals_per_game REAL,
    blocks_per_game REAL,
    turnovers_per_game REAL,
    
    -- Shooting percentages
    field_goal_percentage REAL,
    three_point_percentage REAL,
    free_throw_percentage REAL,
    
    -- Advanced metrics
    player_efficiency_rating REAL,              -- PER
    true_shooting_percentage REAL,              -- TS%
    effective_field_goal_percentage REAL,       -- eFG%
    usage_rate REAL,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
    
    -- One entry per player per season per team
    UNIQUE(player_id, team_id, season, season_type)
);

-- Indexes for lookups
CREATE INDEX IF NOT EXISTS idx_season_avg_player ON season_averages(player_id);
CREATE INDEX IF NOT EXISTS idx_season_avg_season ON season_averages(season);
CREATE INDEX IF NOT EXISTS idx_season_avg_team ON season_averages(team_id);


-- =============================================================================
-- TEAM_STATS TABLE
-- Aggregated team performance metrics
-- =============================================================================
CREATE TABLE IF NOT EXISTS team_stats (
    team_stat_id INTEGER PRIMARY KEY AUTOINCREMENT,
    team_id INTEGER NOT NULL,
    season TEXT NOT NULL,
    season_type TEXT CHECK(season_type IN ('Regular Season', 'Playoffs')) DEFAULT 'Regular Season',
    
    -- Record
    games_played INTEGER DEFAULT 0,
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    win_percentage REAL,
    
    -- Home/Away splits
    home_wins INTEGER DEFAULT 0,
    home_losses INTEGER DEFAULT 0,
    away_wins INTEGER DEFAULT 0,
    away_losses INTEGER DEFAULT 0,
    
    -- Offensive statistics (per game averages)
    points_per_game REAL,
    field_goal_percentage REAL,
    three_point_percentage REAL,
    free_throw_percentage REAL,
    offensive_rebounds_per_game REAL,
    assists_per_game REAL,
    turnovers_per_game REAL,
    
    -- Defensive statistics (per game averages)
    opponent_points_per_game REAL,
    opponent_field_goal_percentage REAL,
    opponent_three_point_percentage REAL,
    defensive_rebounds_per_game REAL,
    steals_per_game REAL,
    blocks_per_game REAL,
    
    -- Advanced metrics
    offensive_rating REAL,                       -- Points per 100 possessions
    defensive_rating REAL,                       -- Opponent points per 100 possessions
    net_rating REAL,                            -- Off rating - Def rating
    pace REAL,                                   -- Possessions per game
    effective_field_goal_percentage REAL,
    true_shooting_percentage REAL,
    
    -- Streaks and momentum
    current_streak INTEGER,                      -- Positive for wins, negative for losses
    last_10_wins INTEGER,                        -- Wins in last 10 games
    last_10_losses INTEGER,                      -- Losses in last 10 games
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
    
    -- One entry per team per season per season type
    UNIQUE(team_id, season, season_type)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_team_stats_team ON team_stats(team_id);
CREATE INDEX IF NOT EXISTS idx_team_stats_season ON team_stats(season);
CREATE INDEX IF NOT EXISTS idx_team_stats_win_pct ON team_stats(win_percentage);


-- =============================================================================
-- OPTIONAL: Trigger to automatically update 'updated_at' timestamp
-- (SQLite doesn't have built-in auto-update for timestamps)
-- =============================================================================

-- Trigger for teams table
CREATE TRIGGER IF NOT EXISTS update_teams_timestamp 
AFTER UPDATE ON teams
FOR EACH ROW
BEGIN
    UPDATE teams SET updated_at = CURRENT_TIMESTAMP WHERE team_id = NEW.team_id;
END;

-- Trigger for games table
CREATE TRIGGER IF NOT EXISTS update_games_timestamp 
AFTER UPDATE ON games
FOR EACH ROW
BEGIN
    UPDATE games SET updated_at = CURRENT_TIMESTAMP WHERE game_id = NEW.game_id;
END;

-- Trigger for season_averages table
CREATE TRIGGER IF NOT EXISTS update_season_averages_timestamp 
AFTER UPDATE ON season_averages
FOR EACH ROW
BEGIN
    UPDATE season_averages SET updated_at = CURRENT_TIMESTAMP WHERE avg_id = NEW.avg_id;
END;

-- Trigger for team_stats table
CREATE TRIGGER IF NOT EXISTS update_team_stats_timestamp 
AFTER UPDATE ON team_stats
FOR EACH ROW
BEGIN
    UPDATE team_stats SET updated_at = CURRENT_TIMESTAMP WHERE team_stat_id = NEW.team_stat_id;
END;


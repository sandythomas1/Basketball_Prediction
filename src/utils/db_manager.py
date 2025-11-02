"""
Database Manager for Basketball Prediction System

This module provides functions to:
1. Initialize the SQLite database with the proper schema
2. Provide helper functions for common database operations
3. Ensure data integrity and efficient querying

Learning Notes:
- sqlite3 is Python's built-in module for SQLite databases
- Context managers (with statement) ensure proper connection handling
- Parameterized queries prevent SQL injection attacks
"""

import sqlite3
import os
from pathlib import Path
from typing import Optional, List, Dict, Any
from datetime import datetime


class DatabaseManager:
    """
    Manages all database operations for the basketball prediction system.
    
    Design Pattern: This uses the Singleton-like pattern where we pass
    the database path, making it flexible for testing and production.
    """
    
    def __init__(self, db_path: Optional[str] = None):
        """
        Initialize the database manager.
        
        Args:
            db_path: Path to SQLite database file. If None, uses default location.
        """
        if db_path is None:
            # Default: store in data/processed directory
            project_root = Path(__file__).parent.parent.parent
            db_path = project_root / "data" / "processed" / "basketball.db"
        
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
    def get_connection(self) -> sqlite3.Connection:
        """
        Create a database connection with optimizations.
        
        Returns:
            sqlite3.Connection object
            
        Learning Note: 
        - Row factory allows accessing columns by name (like a dictionary)
        - Foreign keys must be explicitly enabled in SQLite
        """
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row  # Access columns by name
        conn.execute("PRAGMA foreign_keys = ON")  # Enable foreign key constraints
        return conn
    
    def initialize_database(self) -> None:
        """
        Initialize the database with the schema from SQL file.
        This is idempotent - safe to run multiple times.
        
        Learning Note:
        - CREATE TABLE IF NOT EXISTS makes this safe to re-run
        - executescript() runs multiple SQL statements
        """
        schema_path = Path(__file__).parent / "database_schema.sql"
        
        with open(schema_path, 'r') as f:
            schema_sql = f.read()
        
        with self.get_connection() as conn:
            conn.executescript(schema_sql)
            conn.commit()
        
        print(f"✓ Database initialized at: {self.db_path}")
    
    def execute_query(self, query: str, params: tuple = ()) -> List[sqlite3.Row]:
        """
        Execute a SELECT query and return results.
        
        Args:
            query: SQL SELECT statement
            params: Parameters for the query (prevents SQL injection)
            
        Returns:
            List of rows as sqlite3.Row objects
            
        Learning Note: Always use parameterized queries (? placeholders)
        instead of string formatting to prevent SQL injection.
        
        Example:
            # GOOD (parameterized):
            db.execute_query("SELECT * FROM teams WHERE team_abbr = ?", ("LAL",))
            
            # BAD (vulnerable to SQL injection):
            db.execute_query(f"SELECT * FROM teams WHERE team_abbr = '{abbr}'")
        """
        with self.get_connection() as conn:
            cursor = conn.execute(query, params)
            return cursor.fetchall()
    
    def execute_update(self, query: str, params: tuple = ()) -> int:
        """
        Execute an INSERT, UPDATE, or DELETE query.
        
        Args:
            query: SQL statement
            params: Parameters for the query
            
        Returns:
            Number of rows affected
        """
        with self.get_connection() as conn:
            cursor = conn.execute(query, params)
            conn.commit()
            return cursor.rowcount
    
    def insert_one(self, table: str, data: Dict[str, Any]) -> int:
        """
        Insert a single row into a table.
        
        Args:
            table: Table name
            data: Dictionary of column_name: value pairs
            
        Returns:
            ID of the inserted row
            
        Learning Note: This is a helper function that builds the INSERT
        statement dynamically, making it easier to insert data.
        """
        columns = ', '.join(data.keys())
        placeholders = ', '.join(['?' for _ in data])
        query = f"INSERT INTO {table} ({columns}) VALUES ({placeholders})"
        
        with self.get_connection() as conn:
            cursor = conn.execute(query, tuple(data.values()))
            conn.commit()
            return cursor.lastrowid
    
    def insert_many(self, table: str, data_list: List[Dict[str, Any]]) -> int:
        """
        Insert multiple rows efficiently.
        
        Args:
            table: Table name
            data_list: List of dictionaries with data
            
        Returns:
            Number of rows inserted
            
        Learning Note: executemany() is much faster than multiple execute()
        calls because it uses a single transaction.
        """
        if not data_list:
            return 0
        
        columns = ', '.join(data_list[0].keys())
        placeholders = ', '.join(['?' for _ in data_list[0]])
        query = f"INSERT OR IGNORE INTO {table} ({columns}) VALUES ({placeholders})"
        
        with self.get_connection() as conn:
            cursor = conn.executemany(query, [tuple(d.values()) for d in data_list])
            conn.commit()
            return cursor.rowcount
    
    # =========================================================================
    # Convenience Methods for Common Operations
    # =========================================================================
    
    def add_team(self, team_abbr: str, team_name: str, conference: str, 
                 division: str = None, city: str = None) -> int:
        """
        Add a team to the database.
        
        Args:
            team_abbr: Team abbreviation (e.g., 'LAL')
            team_name: Full team name
            conference: 'East' or 'West'
            division: Division name (optional)
            city: City name (optional)
            
        Returns:
            team_id of the inserted team
        """
        data = {
            'team_abbr': team_abbr,
            'team_name': team_name,
            'conference': conference,
            'division': division,
            'city': city
        }
        return self.insert_one('teams', data)
    
    def get_team_by_abbr(self, team_abbr: str) -> Optional[sqlite3.Row]:
        """Get team information by abbreviation."""
        results = self.execute_query(
            "SELECT * FROM teams WHERE team_abbr = ?", 
            (team_abbr,)
        )
        return results[0] if results else None
    
    def get_team_games(self, team_id: int, season: str = None) -> List[sqlite3.Row]:
        """
        Get all games for a team, optionally filtered by season.
        
        Learning Note: This uses an OR condition to get games where
        the team was either home or away.
        """
        if season:
            query = """
                SELECT * FROM games 
                WHERE (home_team_id = ? OR away_team_id = ?) 
                AND season = ?
                ORDER BY game_date DESC
            """
            params = (team_id, team_id, season)
        else:
            query = """
                SELECT * FROM games 
                WHERE home_team_id = ? OR away_team_id = ?
                ORDER BY game_date DESC
            """
            params = (team_id, team_id)
        
        return self.execute_query(query, params)
    
    def get_player_game_stats(self, player_id: int, season: str = None) -> List[sqlite3.Row]:
        """Get all game stats for a player."""
        if season:
            query = """
                SELECT ps.*, g.game_date, g.season 
                FROM player_stats ps
                JOIN games g ON ps.game_id = g.game_id
                WHERE ps.player_id = ? AND g.season = ?
                ORDER BY g.game_date DESC
            """
            params = (player_id, season)
        else:
            query = """
                SELECT ps.*, g.game_date, g.season 
                FROM player_stats ps
                JOIN games g ON ps.game_id = g.game_id
                WHERE ps.player_id = ?
                ORDER BY g.game_date DESC
            """
            params = (player_id,)
        
        return self.execute_query(query, params)
    
    def get_team_stats(self, team_id: int, season: str) -> Optional[sqlite3.Row]:
        """Get aggregated stats for a team in a specific season."""
        results = self.execute_query(
            "SELECT * FROM team_stats WHERE team_id = ? AND season = ?",
            (team_id, season)
        )
        return results[0] if results else None
    
    def clear_all_data(self) -> None:
        """
        Clear all data from all tables (for testing/reset purposes).
        
        WARNING: This deletes all data!
        
        Learning Note: The ORDER matters here due to foreign key constraints.
        We must delete child tables before parent tables.
        """
        tables = ['player_stats', 'season_averages', 'team_stats', 'games', 'teams']
        
        with self.get_connection() as conn:
            for table in tables:
                conn.execute(f"DELETE FROM {table}")
            conn.commit()
        
        print("✓ All data cleared from database")
    
    def get_database_stats(self) -> Dict[str, int]:
        """
        Get counts of records in each table.
        Useful for verifying data collection.
        """
        tables = ['teams', 'games', 'player_stats', 'season_averages', 'team_stats']
        stats = {}
        
        with self.get_connection() as conn:
            for table in tables:
                cursor = conn.execute(f"SELECT COUNT(*) FROM {table}")
                stats[table] = cursor.fetchone()[0]
        
        return stats


def main():
    """
    Example usage of the DatabaseManager.
    Run this file directly to initialize the database.
    """
    print("Basketball Prediction Database Manager")
    print("=" * 50)
    
    # Initialize database
    db = DatabaseManager()
    db.initialize_database()
    
    # Show current stats
    stats = db.get_database_stats()
    print("\nDatabase Statistics:")
    for table, count in stats.items():
        print(f"  {table}: {count} records")
    
    print("\n" + "=" * 50)
    print("Database is ready for use!")
    print(f"Location: {db.db_path}")


if __name__ == "__main__":
    main()


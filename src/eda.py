"""
Exploratory Data Analysis for NBA SQLite Database
"""
import sqlite3

# Connect to database
conn = sqlite3.connect('/mnt/c/Users/sandy/Desktop/dev/Basketball_Prediction/data/nba.sqlite')
cursor = conn.cursor()

# Get all tables
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = cursor.fetchall()
print("=" * 60)
print("TABLES IN DATABASE:")
print("=" * 60)
for t in tables:
    print(f"  - {t[0]}")

# Explore each table
for (table_name,) in tables:
    print("\n" + "=" * 60)
    print(f"TABLE: {table_name}")
    print("=" * 60)
    
    # Get row count
    cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
    count = cursor.fetchone()[0]
    print(f"\nTotal rows: {count}")
    
    # Get column info
    cursor.execute(f"PRAGMA table_info({table_name})")
    columns = cursor.fetchall()
    print(f"\nColumns ({len(columns)}):")
    for col in columns:
        print(f"  {col[1]} ({col[2]})")
    
    # Sample data
    cursor.execute(f"SELECT * FROM {table_name} LIMIT 3")
    rows = cursor.fetchall()
    col_names = [col[1] for col in columns]
    print(f"\nSample data:")
    print(f"  {col_names}")
    for row in rows:
        print(f"  {row}")

conn.close()

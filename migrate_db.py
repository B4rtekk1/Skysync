#!/usr/bin/env python3
"""
Database migration script to add deletion_token columns to existing database.
Run this script to update your existing database schema.
"""

import sqlite3
import os

def migrate_database():
    """Add deletion_token columns to existing database."""
    
    db_path = "server.db"
    
    if not os.path.exists(db_path):
        print("Database file not found. Creating new database...")
        return
    
    print("Starting database migration...")
    
    try:
        # Connect to existing database
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check if columns already exist
        cursor.execute("PRAGMA table_info(users)")
        columns = [column[1] for column in cursor.fetchall()]
        
        print(f"Existing columns: {columns}")
        
        # Add deletion_token column if it doesn't exist
        if 'deletion_token' not in columns:
            print("Adding deletion_token column...")
            cursor.execute("ALTER TABLE users ADD COLUMN deletion_token TEXT")
            print("✓ deletion_token column added")
        else:
            print("deletion_token column already exists")
        
        # Add deletion_token_expiry column if it doesn't exist
        if 'deletion_token_expiry' not in columns:
            print("Adding deletion_token_expiry column...")
            cursor.execute("ALTER TABLE users ADD COLUMN deletion_token_expiry DATETIME")
            print("✓ deletion_token_expiry column added")
        else:
            print("deletion_token_expiry column already exists")
        
        # Commit changes
        conn.commit()
        print("✓ Database migration completed successfully!")
        
    except sqlite3.Error as e:
        print(f"❌ Database error: {e}")
        conn.rollback()
    except Exception as e:
        print(f"❌ Migration error: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    migrate_database() 
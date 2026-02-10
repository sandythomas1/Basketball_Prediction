"""
Injury Cache Manager: Caching layer for injury data with TTL and persistence.

Provides thread-safe caching of injury reports to reduce API calls
and improve reliability.
"""

import json
import threading
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Dict
from dataclasses import dataclass, asdict

try:
    from .config import INJURY_CACHE_TTL, INJURY_CACHE_PERSIST, INJURY_CACHE_FILE
except ImportError:
    # Fallback for direct execution
    INJURY_CACHE_TTL = 14400  # 4 hours
    INJURY_CACHE_PERSIST = False
    INJURY_CACHE_FILE = ".cache/injury_cache.json"


@dataclass
class CachedInjuryData:
    """Cached injury adjustment data for a team."""
    team_id: int
    team_name: str
    adjustment: float  # Elo adjustment value
    severity: float    # Total severity score
    injuries_count: int
    injuries_summary: list  # List of injury strings
    cached_at: str  # ISO format timestamp
    
    def is_expired(self, ttl: int = INJURY_CACHE_TTL) -> bool:
        """
        Check if cache entry is expired.
        
        Args:
            ttl: Time-to-live in seconds
        
        Returns:
            True if expired
        """
        cached_time = datetime.fromisoformat(self.cached_at)
        return (datetime.now() - cached_time).total_seconds() > ttl
    
    def age_seconds(self) -> float:
        """Get age of cache entry in seconds."""
        cached_time = datetime.fromisoformat(self.cached_at)
        return (datetime.now() - cached_time).total_seconds()


class InjuryCache:
    """
    Thread-safe cache for injury data with TTL and optional persistence.
    """
    
    def __init__(
        self, 
        ttl: int = INJURY_CACHE_TTL,
        persist: bool = INJURY_CACHE_PERSIST,
        cache_file: Optional[str] = None
    ):
        """
        Initialize injury cache.
        
        Args:
            ttl: Time-to-live in seconds (default: 4 hours)
            persist: Whether to persist cache to disk
            cache_file: Path to cache file (for persistence)
        """
        self.ttl = ttl
        self.persist = persist
        self.cache_file = Path(cache_file or INJURY_CACHE_FILE)
        
        # Thread-safe storage
        self._cache: Dict[int, CachedInjuryData] = {}
        self._lock = threading.RLock()
        
        # Load from disk if persistence enabled
        if self.persist:
            self._load_from_disk()
    
    def get(self, team_id: int, allow_stale: bool = False) -> Optional[CachedInjuryData]:
        """
        Get cached injury data for a team.
        
        Args:
            team_id: NBA team ID
            allow_stale: Return stale data if no fresh data available
        
        Returns:
            CachedInjuryData if found and not expired, None otherwise
        """
        with self._lock:
            if team_id not in self._cache:
                return None
            
            entry = self._cache[team_id]
            
            if not entry.is_expired(self.ttl):
                return entry
            
            # Cache is expired
            if allow_stale:
                return entry
            
            return None
    
    def get_adjustment(
        self, 
        team_id: int, 
        allow_stale: bool = False,
        default: float = 0.0
    ) -> float:
        """
        Get Elo adjustment for a team (convenience method).
        
        Args:
            team_id: NBA team ID
            allow_stale: Return stale data if no fresh data available
            default: Default value if not found
        
        Returns:
            Elo adjustment value
        """
        entry = self.get(team_id, allow_stale)
        return entry.adjustment if entry else default
    
    def set(
        self,
        team_id: int,
        team_name: str,
        adjustment: float,
        severity: float,
        injuries_count: int,
        injuries_summary: list
    ) -> None:
        """
        Cache injury data for a team.
        
        Args:
            team_id: NBA team ID
            team_name: Team name
            adjustment: Elo adjustment value
            severity: Total severity score
            injuries_count: Number of injuries
            injuries_summary: List of injury description strings
        """
        with self._lock:
            entry = CachedInjuryData(
                team_id=team_id,
                team_name=team_name,
                adjustment=adjustment,
                severity=severity,
                injuries_count=injuries_count,
                injuries_summary=injuries_summary,
                cached_at=datetime.now().isoformat(),
            )
            self._cache[team_id] = entry
            
            # Persist to disk if enabled
            if self.persist:
                self._save_to_disk()
    
    def clear(self, team_id: Optional[int] = None) -> None:
        """
        Clear cache.
        
        Args:
            team_id: If provided, clear only this team. Otherwise clear all.
        """
        with self._lock:
            if team_id is not None:
                self._cache.pop(team_id, None)
            else:
                self._cache.clear()
            
            if self.persist:
                self._save_to_disk()
    
    def clear_expired(self) -> int:
        """
        Remove expired entries from cache.
        
        Returns:
            Number of entries removed
        """
        with self._lock:
            expired_ids = [
                tid for tid, entry in self._cache.items()
                if entry.is_expired(self.ttl)
            ]
            
            for tid in expired_ids:
                del self._cache[tid]
            
            if expired_ids and self.persist:
                self._save_to_disk()
            
            return len(expired_ids)
    
    def get_stats(self) -> dict:
        """
        Get cache statistics.
        
        Returns:
            Dict with cache stats
        """
        with self._lock:
            total = len(self._cache)
            expired = sum(1 for e in self._cache.values() if e.is_expired(self.ttl))
            fresh = total - expired
            
            ages = [e.age_seconds() for e in self._cache.values()] if self._cache else [0]
            avg_age = sum(ages) / len(ages) if ages else 0
            
            return {
                "total_entries": total,
                "fresh_entries": fresh,
                "expired_entries": expired,
                "average_age_seconds": avg_age,
                "ttl_seconds": self.ttl,
            }
    
    def _save_to_disk(self) -> None:
        """Save cache to disk (called with lock held)."""
        try:
            self.cache_file.parent.mkdir(parents=True, exist_ok=True)
            
            # Convert cache to JSON-serializable format
            cache_data = {
                str(team_id): asdict(entry)
                for team_id, entry in self._cache.items()
            }
            
            with open(self.cache_file, 'w', encoding='utf-8') as f:
                json.dump({
                    "cached_at": datetime.now().isoformat(),
                    "ttl": self.ttl,
                    "entries": cache_data,
                }, f, indent=2)
        except Exception as e:
            # Don't crash if persistence fails
            print(f"Warning: Failed to persist injury cache: {e}")
    
    def _load_from_disk(self) -> None:
        """Load cache from disk (called during init)."""
        try:
            if not self.cache_file.exists():
                return
            
            with open(self.cache_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            entries = data.get("entries", {})
            
            for team_id_str, entry_dict in entries.items():
                team_id = int(team_id_str)
                entry = CachedInjuryData(**entry_dict)
                
                # Only load if not expired
                if not entry.is_expired(self.ttl):
                    self._cache[team_id] = entry
        except Exception as e:
            # Don't crash if load fails, just start with empty cache
            print(f"Warning: Failed to load injury cache from disk: {e}")
    
    def __len__(self) -> int:
        """Return number of cached entries."""
        with self._lock:
            return len(self._cache)
    
    def __repr__(self) -> str:
        stats = self.get_stats()
        return (f"InjuryCache({stats['total_entries']} entries, "
                f"{stats['fresh_entries']} fresh, TTL={self.ttl}s)")


# =============================================================================
# Global Cache Instance
# =============================================================================

# Singleton cache instance for the application
_global_cache: Optional[InjuryCache] = None


def get_global_cache() -> InjuryCache:
    """
    Get the global injury cache instance.
    
    Returns:
        Singleton InjuryCache instance
    """
    global _global_cache
    if _global_cache is None:
        _global_cache = InjuryCache()
    return _global_cache


# =============================================================================
# Testing & Debugging
# =============================================================================

if __name__ == "__main__":
    print("Testing Injury Cache Manager")
    print("=" * 60)
    
    # Create test cache
    cache = InjuryCache(ttl=60, persist=False)  # 1 minute TTL for testing
    
    print("\n1. Adding test entries...")
    cache.set(
        team_id=1610612747,  # Lakers
        team_name="Los Angeles Lakers",
        adjustment=-50.0,
        severity=2.5,
        injuries_count=2,
        injuries_summary=["LeBron James (Out)", "Anthony Davis (Questionable)"]
    )
    
    cache.set(
        team_id=1610612738,  # Celtics
        team_name="Boston Celtics",
        adjustment=-20.0,
        severity=1.0,
        injuries_count=1,
        injuries_summary=["Jayson Tatum (Questionable)"]
    )
    
    print(f"Added 2 entries to cache")
    print(f"Cache: {cache}")
    
    print("\n2. Retrieving entries...")
    lakers = cache.get(1610612747)
    if lakers:
        print(f"Lakers adjustment: {lakers.adjustment} Elo")
        print(f"  Injuries: {', '.join(lakers.injuries_summary)}")
        print(f"  Age: {lakers.age_seconds():.1f}s")
    
    celtics_adj = cache.get_adjustment(1610612738)
    print(f"Celtics adjustment: {celtics_adj} Elo")
    
    print("\n3. Cache statistics:")
    stats = cache.get_stats()
    for key, value in stats.items():
        print(f"  {key}: {value}")
    
    print("\nInjury cache working correctly!")

"""
Pytest configuration and fixtures.

Sets up test environment before any API tests run.
"""
import os

# Ensure test-friendly env before app imports (affects rate limiter, CORS, etc.)
os.environ.setdefault("ENVIRONMENT", "development")
os.environ.setdefault("TESTING", "1")

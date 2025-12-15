#!/usr/bin/env python3

import sys
import requests
import json
import time
import os
import hashlib
from pathlib import Path
from datetime import datetime, timedelta

API_BASE = "https://api.coingecko.com/api/v3"

TIMEFRAMES = {
    "1h": 1 / 24,
    "24h": 1,
    "7d": 7,
    "30d": 30,
    "90d": 90,
    "1y": 365,
}

# Common coin mappings
COMMON_COINS = {
    "btc": "bitcoin",
    "eth": "ethereum",
    "usdt": "tether",
    "bnb": "binancecoin",
    "sol": "solana",
    "xrp": "ripple",
    "ada": "cardano",
    "doge": "dogecoin",
    "dot": "polkadot",
    "avax": "avalanche-2",
}

# Cache configuration
# CACHE_DIR = Path.home() / ".crypto_cache"
CACHE_DIR = Path("/tmp") / ".crypto_cache"
COIN_LIST_CACHE = CACHE_DIR / "coin_list_cache.json"
PRICE_CACHE_DIR = CACHE_DIR / "prices"

# Cache durations (in seconds)
COIN_LIST_DURATION = 86400  # 24 hours
PRICE_CACHE_DURATION = {
    "1h": 300,  # 5 minutes
    "24h": 1800,  # 30 minutes
    "7d": 3600,  # 1 hour
    "30d": 7200,  # 2 hours
    "90d": 14400,  # 4 hours
    "1y": 28800,  # 8 hours
}


def die(msg):
    """Print error and exit"""
    print(json.dumps({"error": msg}))
    sys.exit(1)


def ensure_cache_dir():
    """Create cache directories if they don't exist"""
    CACHE_DIR.mkdir(exist_ok=True)
    PRICE_CACHE_DIR.mkdir(exist_ok=True)


def get_cache_key(coin_id, days):
    """Generate unique cache key for price data"""
    key_string = f"{coin_id}_{days}"
    return hashlib.md5(key_string.encode()).hexdigest()[:16]


def load_cached_data(cache_file, max_age):
    """Load data from cache if fresh"""
    if not cache_file.exists():
        return None

    try:
        file_age = time.time() - cache_file.stat().st_mtime
        if file_age < max_age:
            with open(cache_file, "r") as f:
                return json.load(f)
        else:
            return None
    except (json.JSONDecodeError, IOError):
        return None


def save_to_cache(cache_file, data):
    """Save data to cache file"""
    try:
        with open(cache_file, "w") as f:
            json.dump(data, f, indent=2)
        return True
    except IOError:
        return False


def fetch_coin_list():
    """Fetch coin list from API or cache"""
    # Check cache first
    cached = load_cached_data(COIN_LIST_CACHE, COIN_LIST_DURATION)
    if cached:
        print("Using cached coin list", file=sys.stderr)
        return cached

    # Fetch from API
    print("Fetching coin list from API...", file=sys.stderr)
    try:
        r = requests.get(f"{API_BASE}/coins/list", timeout=10)
        r.raise_for_status()
        coin_list = r.json()

        # Save to cache
        save_to_cache(COIN_LIST_CACHE, coin_list)
        return coin_list
    except requests.exceptions.RequestException as e:
        die(f"Failed to fetch coin list: {e}")


def get_coin_id(symbol):
    """Get coin ID using cache and common coins"""
    symbol_lower = symbol.lower()

    # Check common coins first
    if symbol_lower in COMMON_COINS:
        print(f"Found {symbol} in common coins", file=sys.stderr)
        return COMMON_COINS[symbol_lower]

    # Search in cached/fetched coin list
    coin_list = fetch_coin_list()
    for coin in coin_list:
        if coin["symbol"] == symbol_lower:
            print(f"Found {symbol} in coin list", file=sys.stderr)
            return coin["id"]

    die(f"Symbol '{symbol}' not found")


def fetch_prices_with_cache(coin_id, days, timeframe):
    """Fetch prices using cache when possible"""
    cache_key = get_cache_key(coin_id, days)
    cache_file = PRICE_CACHE_DIR / f"{cache_key}.json"
    cache_duration = PRICE_CACHE_DURATION[timeframe]

    # Try cache first
    cached = load_cached_data(cache_file, cache_duration)
    if cached:
        print(f"Using cached price data for {coin_id} ({timeframe})", file=sys.stderr)
        return cached

    # Fetch from API
    print(f"Fetching fresh price data for {coin_id}...", file=sys.stderr)

    # Rate limiting delay
    time.sleep(1)

    try:
        params = {"vs_currency": "usd", "days": days}
        r = requests.get(
            f"{API_BASE}/coins/{coin_id}/market_chart", params=params, timeout=15
        )
        r.raise_for_status()
        prices = r.json()["prices"]

        # Save to cache
        save_to_cache(cache_file, prices)
        return prices
    except requests.exceptions.RequestException as e:
        die(f"Failed to fetch prices: {e}")


def main():
    if len(sys.argv) != 3:
        die("usage: crypto.py <symbol> <timeframe>")

    symbol = sys.argv[1]
    timeframe = sys.argv[2]

    if timeframe not in TIMEFRAMES:
        die(f"Invalid timeframe: {timeframe}")

    # Initialize cache
    ensure_cache_dir()

    # Get coin ID
    coin_id = get_coin_id(symbol)
    print(f"Coin ID: {coin_id}", file=sys.stderr)

    # Get prices (cached or fresh)
    days = TIMEFRAMES[timeframe]
    prices = fetch_prices_with_cache(coin_id, days, timeframe)

    # Format output
    output = [{"timestamp": int(ts / 1000), "price": price} for ts, price in prices]

    result = {
        "symbol": symbol.lower(),
        "coin_id": coin_id,
        "timeframe": timeframe,
        "cache_info": {
            "coin_list_cached": COIN_LIST_CACHE.exists(),
            "price_cache_key": get_cache_key(coin_id, days),
        },
        "prices": output,
    }

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

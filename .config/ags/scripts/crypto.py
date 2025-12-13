#!/usr/bin/env python3

import sys
import requests
import json

API_BASE = "https://api.coingecko.com/api/v3"

TIMEFRAMES = {
    "1h": 1 / 24,
    "24h": 1,
    "7d": 7,
    "30d": 30,
    "90d": 90,
    "1y": 365,
}

# Common coin mappings to avoid API calls
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


def die(msg):
    print(json.dumps({"error": msg}))
    sys.exit(1)


def get_coin_id(symbol: str) -> str:
    # First check common coins to avoid API call
    symbol_lower = symbol.lower()
    if symbol_lower in COMMON_COINS:
        return COMMON_COINS[symbol_lower]

    # If not in common list, use the API
    r = requests.get(f"{API_BASE}/coins/list")
    r.raise_for_status()

    for coin in r.json():
        if coin["symbol"] == symbol_lower:
            return coin["id"]

    die(f"symbol '{symbol}' not found on CoinGecko")


def fetch_prices(coin_id: str, days: float):
    params = {"vs_currency": "usd", "days": days}
    r = requests.get(f"{API_BASE}/coins/{coin_id}/market_chart", params=params)
    r.raise_for_status()
    return r.json()["prices"]


def main():
    if len(sys.argv) != 3:
        die("usage: crypto.py <symbol> <timeframe>")

    symbol = sys.argv[1]
    timeframe = sys.argv[2]

    if timeframe not in TIMEFRAMES:
        die(f"invalid timeframe: {timeframe}")

    coin_id = get_coin_id(symbol)
    print(f"Using coin ID: {coin_id}", file=sys.stderr)  # Debug output

    prices = fetch_prices(coin_id, TIMEFRAMES[timeframe])

    # Convert milliseconds to seconds for timestamp
    output = [{"timestamp": int(ts / 1000), "price": price} for ts, price in prices]

    print(
        json.dumps(
            {"symbol": symbol.lower(), "timeframe": timeframe, "prices": output},
            indent=2,
        )
    )


if __name__ == "__main__":
    main()

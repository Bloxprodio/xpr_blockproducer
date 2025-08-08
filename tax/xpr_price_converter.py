import pandas as pd
import requests
import json
import time
from datetime import datetime
from tqdm import tqdm
import os

CACHE_FILE = "price_cache.json"

def load_cache():
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, "r") as f:
            return json.load(f)
    return {}

def save_cache(cache):
    with open(CACHE_FILE, "w") as f:
        json.dump(cache, f, indent=2)

def fetch_xpr_price(date):
    """Fetches the historical USD price of XPR for a given date (YYYY-MM-DD)"""
    dt = datetime.strptime(date, "%Y-%m-%d")
    formatted_date = dt.strftime("%d-%m-%Y")
    url = f"https://api.coingecko.com/api/v3/coins/proton/history?date={formatted_date}&localization=false"

    for attempt in range(5):
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            return data.get("market_data", {}).get("current_price", {}).get("usd", None)
        elif response.status_code == 429:
            print(f"429 Too Many Requests – waiting 60 seconds... ({date})")
            time.sleep(60)
        else:
            print(f"Error {response.status_code} on {date}")
            return None
    return None

def main():
    # Read CSV
    df = pd.read_csv("Juli_Export.csv")
    df["Date"] = pd.to_datetime(df["Date"]).dt.date
    df = df[["Date", "Buy Amount"]].groupby("Date").sum().reset_index()

    # Load cache
    cache = load_cache()
    prices = []
    usd_values = []

    for index, row in tqdm(df.iterrows(), total=len(df)):
        date_str = row["Date"].strftime("%Y-%m-%d")
        xpr_amount = row["Buy Amount"]

        if date_str in cache:
            price = cache[date_str]
        else:
            price = fetch_xpr_price(date_str)
            cache[date_str] = price
            save_cache(cache)

        if price is None:
            price = 0.0
        usd_value = round(xpr_amount * price, 2)

        prices.append(price)
        usd_values.append(usd_value)

        time.sleep(1.2)  # Avoid hitting API rate limit

    df["USD_Price"] = prices
    df["USD_Value"] = usd_values
    today_str = datetime.today().strftime("%Y-%m-%d")
    filename = f"Export_XPR_USD_{today_str}.csv"
    df.to_csv(filename, index=False, sep=";")
    print(f"\n✔️ File '{filename}' was successfully created.")


if __name__ == "__main__":
    main()

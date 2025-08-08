## 🧰 How to Run the Program on Windows

### 1. ✅ Install Python
If Python is not yet installed:

- Go to the [official Python website](https://www.python.org/downloads/)
- Download the latest version for Windows
- During installation, check the box that says “Add Python to PATH”
- Finish installation and verify by opening Command Prompt and typing:

python --version


### 2. 📦 Install Required Python Packages
Open Command Prompt and run:

pip install pandas requests tqdm


These packages are used for:
- `pandas`: handling CSV files and dataframes
- `requests`: making API calls
- `tqdm`: showing progress bars

### 3. 📁 Prepare Your CSV File
Create a file named `Export_XPR_USD_{actual Date}.csv` in the same folder as your script. It should contain at least:
- A column named `Date` (in format YYYY-MM-DD)
- A column named `New Amount` (number of XPR )

### 4. ▶️ Run the Program
Save your Python script as `xpr_price_converter.py`, then run it in Command Prompt:

python xpr_price_converter.py


After execution, it will generate a file like:

Export_XPR_USD_2025-08-08.csv


---

## 🧠 What the Program Does – Step by Step

1. **Reads your CSV file** containing dates and XPR amounts.
2. **Groups purchases by date** to calculate total XPR bought per day.
3. **Fetches historical USD prices** for XPR from CoinGecko’s API.
4. **Caches prices** locally in `price_cache.json` to avoid redundant API calls.
5. **Calculates USD value** for each day’s total XPR.
6. **Writes the results** to a new CSV file with USD prices and values.

---

## 🌐 External API Used

The program accesses:
**CoinGecko API**  
  Endpoint:  
  `https://api.coingecko.com/api/v3/coins/proton/history`  
  Purpose:  
  To retrieve historical price data for the cryptocurrency **Proton (XPR)**.

Example API call:

https://api.coingecko.com/api/v3/coins/proton/history?date=08-08-2025&localization=false

🚦 API Rate Limits
CoinGecko limits the number of requests per minute. To avoid errors:

The program waits 1.2 seconds between requests

If the limit is exceeded, it waits 60 seconds before retrying

This ensures smooth operation even with large datasets.

---


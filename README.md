# Equity-Misvaluation-and-Default-Options

Includes code used by Arizona State University SIM Fund 2019-2020 Team A to implement the strategy which requires access to Bloomberg and Compustat(to get CHS values). 

Full Python implementation using publicly available or relatively inexpensive(especially compared to Bloomberg) data is in development.

Status 9/28/2020: Able to scrape balance sheet data. Need to try and resolve issues and scrape income statement data.

Issues:
- Financial data limited to filings made in xbrl format
- There are form types such as 10/QA or 10KT which are ammendements to previous 10/Q, still have to decide how to deal with them
    - Filtered only for filings that match '10-Q' and '10-K' for now
- Naming for financial statements is not standard across filings
    - Have a list called financial_statement_names which filters the "shortnames" in the FilingSummary.xml which seem to be somewhat standardized
- How to best store the financial data?
    - Data warehouse on GCP?
    - Save in flat files?
- Possibility currency in filings is not in dollars
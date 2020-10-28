# Equity-Misvaluation-and-Default-Options

Includes code used by Arizona State University SIM Fund 2019-2020 Team A to implement the strategy which requires access to Bloomberg and Compustat(to get CHS values). 

Implementation: 
1. Get CHS values from Compustat by running the "Inputs for the model.sas" SAS script with access to Compustat. This script is given by the authors of the paper.
2. Set up screens in EQS on Bloomberg for data. Pictures of specific fields are provided under "Helpful Screenshots". Make sure to match the file name when exporting to the one in the script so the data is imported correctly.
3. Make sure to install the required libraries in python and run the script. CSV files with the buy and sell orders that meet most of the team's criteria are generated.



Full Python implementation using publicly available or relatively inexpensive(especially compared to Bloomberg) data is in development. Status 9/28/2020: Able to scrape balance sheet data from SEC. Need to try to resolve issues and scrape income statement data.

Issues:
- The script takes a long time to run. Possible to make it run faster?
- Financial data limited to filings made in xbrl format
- There are form types such as 10/QA or 10KT which are ammendements to previous 10/Q, still have to decide how to deal with them
    - Filtered only for filings that match '10-Q' and '10-K' for now
- Naming for financial statements is not standard across filings
    - Have a list called financial_statement_names which filters the "shortnames" in the FilingSummary.xml which seem to be somewhat standardized
- How to best store the financial data?
    - Data warehouse on GCP?
    - Save in flat files?
- Possibility currency in filings is not in dollars

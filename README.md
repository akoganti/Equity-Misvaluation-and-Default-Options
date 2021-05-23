# Equity-Misvaluation-and-Default-Options

Includes code used by Arizona State University SIM Fund 2019-2020 Team A to implement the strategy which requires access to Bloomberg and Compustat(to get CHS values). 

Implementation: 
1. Get CHS values from Compustat by running the "Inputs for the model.sas" SAS script with access to Compustat. This script is given by the authors of the paper.
2. Set up screens in EQS on Bloomberg for data. Pictures of specific fields are provided under "Helpful Screenshots". Make sure to match the file name when exporting to the one in the script so the data is imported correctly.
3. Make sure to install the required libraries in python and run the script. CSV files with the buy and sell orders that meet most of the team's criteria are generated.

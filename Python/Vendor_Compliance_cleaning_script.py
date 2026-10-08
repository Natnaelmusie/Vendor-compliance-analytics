# VENDOR INBOUND LOG - CLEANING PIPELINE
# Reads the raw 2025 inbound log, standardises it, and writes a clean
# table ('Inbound_data') to SQLite for the SQL analysis stage.
# -------------------------------------------------------------------
import pandas as pd
import sqlite3
 
# Load the raw log (the 'Inbound' sheet)
vendor_data = pd.read_excel('vendor_inbound_log_2025.xlsx', sheet_name='Inbound')
 
 
# ---------------------------------------------------------------------
# 1. Derive Booking_type from the booked-in time.
#    Lowercase first so 'open slot' matches regardless of original case.
# ---------------------------------------------------------------------
vendor_data['Booked In Time'] = vendor_data['Booked In Time'].str.lower()
 
# New column defaulting to 'Fixed'; then overwrite the two special cases.
vendor_data.insert(1, 'Booking_type', 'Fixed')
vendor_data.loc[vendor_data['Booked In Time'].str.contains('open', na=False), 'Booking_type'] = 'Open_slot'
vendor_data.loc[vendor_data['Booked In Time'].isna(), 'Booking_type'] = 'unscheduled'   # blanks: no keyword, so use .isna()
 
# Collapse every open slot to one representative time (they are all equivalent).
vendor_data.loc[vendor_data['Booked In Time'].str.contains('open slot', na=False), 'Booked In Time'] = '15:00'
 
 
# ---------------------------------------------------------------------
# 2. Fill the identifier columns.
# ---------------------------------------------------------------------
print("Delivery Reference empty cells:", vendor_data['Delivery Reference'].isnull().sum())   # expect 0
 
print("IDN empty cells before fill:", vendor_data['IDN'].isnull().sum())                     # expect 198
vendor_data['IDN'] = vendor_data['IDN'].fillna(value='No_IDN_provided')
print("IDN empty cells after fill:", vendor_data['IDN'].isnull().sum())                      # expect 0
 
print("IDN Error empty cells before fill:", vendor_data['IDN Error'].isnull().sum())         # expect 1032
vendor_data['IDN Error'] = vendor_data['IDN Error'].fillna(value='none')
print("IDN Error empty cells after fill:", vendor_data['IDN Error'].isnull().sum())          # expect 0
 
 
# ---------------------------------------------------------------------
# 3. Fill Arrival Time using two conditions tied to Booking_type.
#    - Booked (fixed/open) but no arrival -> 'Not_arrived'   (a genuine no-show)
#    - Unscheduled and no arrival         -> 'Not_scheduled' (never had a slot)
# ---------------------------------------------------------------------
print("Arrival Time empty cells before fill:", vendor_data['Arrival Time'].isnull().sum())   # expect 40
 
vendor_data.loc[(vendor_data['Arrival Time'].isna()) & (vendor_data['Booking_type'] != 'unscheduled'), 'Arrival Time'] = 'Not_arrived'
vendor_data.loc[(vendor_data['Arrival Time'].isna()) & (vendor_data['Booking_type'] == 'unscheduled'), 'Arrival Time'] = 'Not_scheduled'
 
print("Arrival Time empty cells after fill:", vendor_data['Arrival Time'].isnull().sum())    # expect 0
 
 
# ---------------------------------------------------------------------
# 4. Save the cleaned table to SQLite for the SQL stage.
# ---------------------------------------------------------------------
conn = sqlite3.connect('vendor_clean.db')
vendor_data.to_sql('Inbound_data', conn, if_exists='replace', index=False)
conn.close()
 
print("Done - cleaned table 'Inbound_data' written to vendor_clean.db")
 

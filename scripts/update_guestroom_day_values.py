#!/usr/bin/env python3
"""
Script to update GuestroomTypeDay__c records with random BlockedDefinite__c values
and calculate GroupAvailable__c as DailyRoomInventory__c - BlockedDefinite__c.
"""

import subprocess
import json
import random
import csv
import os

def main():
    base_dir = '/Users/rreboucas/Documents/SFDX Projects/fdesdo/Fdesdo'

    # Query all GuestroomTypeDay__c records
    print("Querying GuestroomTypeDay__c records...")
    query = "SELECT Id, Name, DailyRoomInventory__c, BlockedDefinite__c, GroupAvailable__c FROM GuestroomTypeDay__c"

    result = subprocess.run(
        ['sf', 'data', 'query', '--query', query, '--json'],
        capture_output=True, text=True, cwd=base_dir
    )

    if result.returncode != 0:
        print(f"Error querying records: {result.stderr}")
        return

    data = json.loads(result.stdout)
    records = data.get('result', {}).get('records', [])

    print(f"Found {len(records)} records to update")

    # Possible random values for BlockedDefinite__c
    blocked_values = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]

    # Prepare update CSV
    output_file = os.path.join(base_dir, 'dataimport/GuestroomTypeDay_update.csv')

    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Id', 'BlockedDefinite__c', 'GroupAvailable__c'])

        for record in records:
            record_id = record['Id']
            daily_inventory = record.get('DailyRoomInventory__c', 0) or 0

            # Pick a random value that is less than DailyRoomInventory__c
            valid_values = [v for v in blocked_values if v < daily_inventory]

            if valid_values:
                blocked_definite = random.choice(valid_values)
            else:
                # If inventory is very low, use a smaller value
                blocked_definite = max(0, int(daily_inventory * 0.3))

            # Calculate GroupAvailable__c
            group_available = daily_inventory - blocked_definite

            writer.writerow([record_id, blocked_definite, group_available])

    print(f"Created update file: {output_file}")

    # Run the bulk update
    print("Running bulk update...")
    update_result = subprocess.run(
        ['sfdx', 'force:data:bulk:upsert', '-s', 'GuestroomTypeDay__c',
         '-f', output_file, '-i', 'Id', '-w', '15'],
        capture_output=True, text=True, cwd=base_dir
    )

    print(update_result.stdout)
    if update_result.returncode != 0:
        print(f"Error: {update_result.stderr}")
    else:
        print("Update completed successfully!")

if __name__ == '__main__':
    main()

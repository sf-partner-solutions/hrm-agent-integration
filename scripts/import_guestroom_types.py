#!/usr/bin/env python3
"""
Script to process Guest_Room_Type.csv and prepare for Salesforce import.
Replaces Location__c with the target org value and removes system fields.
"""

import csv
import os

def main():
    base_dir = '/Users/rreboucas/Documents/SFDX Projects/fdesdo/Fdesdo'
    input_file = os.path.join(base_dir, 'dataimport/Guest_Room_Type.csv')
    output_file = os.path.join(base_dir, 'dataimport/GuestroomType_import.csv')

    # Target Location__c ID in the demo org
    target_location_id = 'a47Ka000000lhMlIAI'

    # Fields to exclude (system fields that shouldn't be inserted)
    exclude_fields = [
        'Id', 'CreatedById', 'CreatedDate', 'LastModifiedById',
        'LastModifiedDate', 'SystemModstamp', 'IsDeleted', 'CurrencyIsoCode'
    ]

    with open(input_file, 'r') as infile:
        reader = csv.DictReader(infile)
        fieldnames = [f for f in reader.fieldnames if f not in exclude_fields]

        rows = []
        for row in reader:
            # Replace Location__c with target org value
            row['Location__c'] = target_location_id

            # Create new row with only the fields we want
            new_row = {k: v for k, v in row.items() if k in fieldnames}
            rows.append(new_row)

    with open(output_file, 'w', newline='\r\n') as outfile:
        writer = csv.DictWriter(outfile, fieldnames=fieldnames, lineterminator='\r\n')
        writer.writeheader()
        writer.writerows(rows)

    print(f"Processed {len(rows)} records")
    print(f"Output written to: {output_file}")
    print(f"Location__c set to: {target_location_id}")
    print(f"\nFields included: {', '.join(fieldnames)}")

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
Script to process Guest_Room_Type_Day__c.csv and prepare for Salesforce import.
Maps GuestroomType__c IDs from source to target org and sets Location__c.
"""

import csv
import os

def main():
    base_dir = '/Users/rreboucas/Documents/SFDX Projects/fdesdo/Fdesdo'
    input_file = os.path.join(base_dir, 'dataimport/Guest_Room_Type_Day__c.csv')
    output_file = os.path.join(base_dir, 'dataimport/GuestroomTypeDay_import.csv')

    # Target Location__c ID in the demo org
    target_location_id = 'a47Ka000000lhMlIAI'

    # Mapping from source org GuestroomType__c IDs to demo org IDs
    guestroom_type_mapping = {
        'a1Bfh000000uGenEAE': 'a4CKa000000m2c6MAA',  # Run of House
        'a1Bfh000000uGrhEAE': 'a4CKa000000m2bcMAA',  # Standard
        'a1Bfh000000uGriEAE': 'a4CKa000000m2bhMAA',  # Presidential Suite
        'a1Bfh000000uGrjEAE': 'a4CKa000000m2bmMAA',  # Twin
        'a1Bfh000000uGrkEAE': 'a4CKa000000m2brMAA',  # Deluxe
        'a1Bfh000000uGrlEAE': 'a4CKa000000m2bwMAA',  # King
        'a1Bfh000000uGrmEAE': 'a4CKa000000m2c1MAA',  # Queen
        'a1Bfh000000uGrnEAE': 'a4CKa000000m2bnMAA',  # Studio
    }

    # Fields to exclude (system fields that shouldn't be inserted)
    exclude_fields = [
        'Id', 'CreatedById', 'CreatedDate', 'LastModifiedById',
        'LastModifiedDate', 'SystemModstamp', 'IsDeleted', 'CurrencyIsoCode',
        'OwnerId', 'RecordTypeId', 'LastReferencedDate', 'LastViewedDate'
    ]

    with open(input_file, 'r') as infile:
        reader = csv.DictReader(infile)
        fieldnames = [f for f in reader.fieldnames if f not in exclude_fields]

        rows = []
        unmapped_count = 0
        for row in reader:
            # Replace Location__c with target org value
            row['Location__c'] = target_location_id

            # Map GuestroomType__c to new ID
            old_guestroom_type_id = row.get('GuestroomType__c', '')
            if old_guestroom_type_id in guestroom_type_mapping:
                row['GuestroomType__c'] = guestroom_type_mapping[old_guestroom_type_id]
            elif old_guestroom_type_id:
                print(f"Warning: Unmapped GuestroomType__c ID: {old_guestroom_type_id}")
                unmapped_count += 1

            # Create new row with only the fields we want
            new_row = {k: v for k, v in row.items() if k in fieldnames}
            rows.append(new_row)

    # Write with CRLF line endings for Salesforce bulk API
    with open(output_file, 'w', newline='') as outfile:
        writer = csv.DictWriter(outfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Processed {len(rows)} records")
    print(f"Output written to: {output_file}")
    print(f"Location__c set to: {target_location_id}")
    if unmapped_count > 0:
        print(f"Warning: {unmapped_count} records had unmapped GuestroomType__c IDs")
    print(f"\nFields included ({len(fieldnames)}): {', '.join(fieldnames[:10])}...")

if __name__ == '__main__':
    main()

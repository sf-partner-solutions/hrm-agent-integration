#!/usr/bin/env python3
"""
Script to import GuestroomType__c records using sf data create record.
"""

import csv
import subprocess
import json
import os

def main():
    base_dir = '/Users/rreboucas/Documents/SFDX Projects/fdesdo/Fdesdo'
    input_file = os.path.join(base_dir, 'dataimport/Guest_Room_Type.csv')

    # Target Location__c ID in the demo org
    target_location_id = 'a47Ka000000lhMlIAI'

    # Fields to exclude (system fields that shouldn't be inserted)
    exclude_fields = [
        'Id', 'CreatedById', 'CreatedDate', 'LastModifiedById',
        'LastModifiedDate', 'SystemModstamp', 'IsDeleted', 'CurrencyIsoCode'
    ]

    with open(input_file, 'r') as infile:
        reader = csv.DictReader(infile)

        for i, row in enumerate(reader, 1):
            # Replace Location__c with target org value
            row['Location__c'] = target_location_id

            # Build the field values string for sf data create record
            values = []
            for key, value in row.items():
                if key in exclude_fields:
                    continue
                if value == '' or value is None:
                    continue
                # Handle boolean values
                if value.lower() in ['true', 'false']:
                    values.append(f"{key}={value.lower()}")
                # Handle numeric values
                elif value.replace('.', '').replace('-', '').isdigit():
                    values.append(f"{key}={value}")
                else:
                    # Escape single quotes in string values
                    escaped_value = value.replace("'", "\\'")
                    values.append(f"{key}='{escaped_value}'")

            values_str = ' '.join(values)

            cmd = f'sf data create record --sobject GuestroomType__c --values "{values_str}" --json'

            print(f"\nCreating record {i}: {row.get('Name', 'Unknown')}")

            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=base_dir)

            if result.returncode == 0:
                response = json.loads(result.stdout)
                if response.get('status') == 0:
                    record_id = response.get('result', {}).get('id', 'Unknown')
                    print(f"  ✓ Created with ID: {record_id}")
                else:
                    print(f"  ✗ Error: {response}")
            else:
                print(f"  ✗ Command failed: {result.stderr}")

if __name__ == '__main__':
    main()

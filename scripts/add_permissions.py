#!/usr/bin/env python3
"""
Generate permission set additions for Booking__c, BookingEvent__c, EventItem__c
"""

import os
from pathlib import Path

# Base path for field metadata
BASE_PATH = Path('/Users/rreboucas/Documents/SFDX Projects/fdesdo/Fdesdo/force-app/main/default/objects')

def get_custom_fields(object_name):
    """Get list of custom fields for an object from metadata files."""
    fields_dir = BASE_PATH / object_name / 'fields'
    if not fields_dir.exists():
        return []

    fields = []
    for field_file in fields_dir.glob('*.field-meta.xml'):
        field_name = field_file.stem.replace('.field-meta', '')
        if field_name.endswith('__c'):
            fields.append(field_name)
    return sorted(fields)

def generate_field_permissions_xml(object_name, fields):
    """Generate fieldPermissions XML for all fields."""
    xml_parts = []
    for field in fields:
        xml_parts.append(f'''    <fieldPermissions>
        <editable>true</editable>
        <field>{object_name}.{field}</field>
        <readable>true</readable>
    </fieldPermissions>''')
    return '\n'.join(xml_parts)

def generate_object_permission_xml(object_name):
    """Generate objectPermissions XML for an object."""
    return f'''    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>true</allowDelete>
        <allowEdit>true</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>true</modifyAllRecords>
        <object>{object_name}</object>
        <viewAllFields>true</viewAllFields>
        <viewAllRecords>true</viewAllRecords>
    </objectPermissions>'''

def generate_tab_setting_xml(object_name):
    """Generate tabSettings XML for an object."""
    return f'''    <tabSettings>
        <tab>{object_name}</tab>
        <visibility>Visible</visibility>
    </tabSettings>'''

def main():
    objects = ['Booking__c', 'BookingEvent__c', 'EventItem__c']

    print("<!-- Object Permissions -->")
    for obj in objects:
        print(generate_object_permission_xml(obj))
        print()

    print("\n<!-- Field Permissions -->")
    for obj in objects:
        fields = get_custom_fields(obj)
        print(f"<!-- {obj}: {len(fields)} fields -->")
        print(generate_field_permissions_xml(obj, fields))
        print()

    print("\n<!-- Tab Settings -->")
    for obj in objects:
        print(generate_tab_setting_xml(obj))
        print()

if __name__ == '__main__':
    main()

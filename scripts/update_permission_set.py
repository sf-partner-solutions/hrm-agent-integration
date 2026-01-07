#!/usr/bin/env python3
"""
Update Delphi_Admin permission set with permissions for Booking__c, BookingEvent__c, EventItem__c
"""

import os
import re
from pathlib import Path

# Base paths
BASE_PATH = Path('/Users/rreboucas/Documents/SFDX Projects/fdesdo/Fdesdo/force-app/main/default')
PERM_SET_PATH = BASE_PATH / 'permissionsets' / 'Delphi_Admin.permissionset-meta.xml'

def get_custom_fields(object_name):
    """Get list of custom fields for an object from metadata files."""
    fields_dir = BASE_PATH / 'objects' / object_name / 'fields'
    if not fields_dir.exists():
        return []

    fields = []
    for field_file in fields_dir.glob('*.field-meta.xml'):
        field_name = field_file.stem.replace('.field-meta', '')
        if field_name.endswith('__c'):
            fields.append(field_name)
    return sorted(fields)

def generate_field_permissions(object_name, fields):
    """Generate fieldPermissions XML for all fields."""
    xml_parts = []
    for field in fields:
        xml_parts.append(f'''    <fieldPermissions>
        <editable>true</editable>
        <field>{object_name}.{field}</field>
        <readable>true</readable>
    </fieldPermissions>''')
    return '\n'.join(xml_parts)

def generate_object_permission(object_name):
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

def generate_tab_setting(object_name):
    """Generate tabSettings XML for an object."""
    return f'''    <tabSettings>
        <tab>{object_name}</tab>
        <visibility>Visible</visibility>
    </tabSettings>'''

def main():
    objects = ['Booking__c', 'BookingEvent__c', 'EventItem__c']

    # Read existing permission set
    with open(PERM_SET_PATH, 'r') as f:
        content = f.read()

    # Generate new field permissions
    new_field_perms = []
    for obj in objects:
        fields = get_custom_fields(obj)
        print(f"{obj}: {len(fields)} fields")
        new_field_perms.append(generate_field_permissions(obj, fields))
    field_perms_xml = '\n'.join(new_field_perms)

    # Generate new object permissions
    obj_perms_xml = '\n'.join([generate_object_permission(obj) for obj in objects])

    # Generate new tab settings
    tab_settings_xml = '\n'.join([generate_tab_setting(obj) for obj in objects])

    # Find insertion points and insert content
    # Insert field permissions before </PermissionSet> but after existing fieldPermissions
    # Find the last fieldPermissions closing tag
    last_field_perm = content.rfind('</fieldPermissions>')
    if last_field_perm != -1:
        insert_pos = content.find('\n', last_field_perm) + 1
        content = content[:insert_pos] + field_perms_xml + '\n' + content[insert_pos:]

    # Insert object permissions after existing objectPermissions
    last_obj_perm = content.rfind('</objectPermissions>')
    if last_obj_perm != -1:
        insert_pos = content.find('\n', last_obj_perm) + 1
        content = content[:insert_pos] + obj_perms_xml + '\n' + content[insert_pos:]

    # Insert tab settings after existing tabSettings
    last_tab = content.rfind('</tabSettings>')
    if last_tab != -1:
        insert_pos = content.find('\n', last_tab) + 1
        content = content[:insert_pos] + tab_settings_xml + '\n' + content[insert_pos:]

    # Write updated permission set
    with open(PERM_SET_PATH, 'w') as f:
        f.write(content)

    print(f"\nUpdated {PERM_SET_PATH}")
    print(f"Added object permissions for: {', '.join(objects)}")
    print(f"Added tab settings for: {', '.join(objects)}")

if __name__ == '__main__':
    main()

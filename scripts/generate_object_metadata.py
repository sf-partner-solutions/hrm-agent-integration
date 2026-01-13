#!/usr/bin/env python3
"""
Generate Salesforce custom object metadata XML from describe JSON.
Processes Workbench REST Explorer describe output and creates deployable metadata.
"""

from typing import Optional, Dict, List
import json
import os
import sys
from pathlib import Path

# Configuration
EXCLUDED_FIELDS = {
    'BookingEvent__c': ['AdvancedBooking__c', 'BanquetCheck__c', 'Beo__c'],
    'EventItem__c': ['BeoSection__c', 'ChoiceGroupItem__c'],
    'Booking__c': []
}

# Objects we're creating - lookups to other objects should be excluded
OBJECTS_BEING_CREATED = ['Booking__c', 'BookingEvent__c', 'EventItem__c']

# Standard fields that shouldn't be included in metadata (auto-created by Salesforce)
STANDARD_FIELDS = [
    'Id', 'OwnerId', 'IsDeleted', 'Name', 'CreatedDate', 'CreatedById',
    'LastModifiedDate', 'LastModifiedById', 'SystemModstamp', 'LastActivityDate',
    'LastViewedDate', 'LastReferencedDate', 'RecordTypeId'
]

# Field type mapping from describe to metadata
FIELD_TYPE_MAP = {
    'string': 'Text',
    'textarea': 'LongTextArea',
    'boolean': 'Checkbox',
    'int': 'Number',
    'double': 'Number',
    'currency': 'Currency',
    'percent': 'Percent',
    'phone': 'Phone',
    'email': 'Email',
    'url': 'Url',
    'date': 'Date',
    'datetime': 'DateTime',
    'time': 'Time',
    'picklist': 'Picklist',
    'multipicklist': 'MultiselectPicklist',
    'reference': 'Lookup',
    'id': None,  # Skip ID fields
    'encryptedstring': 'Text',
}


def get_field_xml(field: dict, object_name: str) -> Optional[str]:
    """Generate XML for a single field."""
    field_name = field.get('name', '')
    field_type = field.get('type', '').lower()

    # Skip standard fields
    if field_name in STANDARD_FIELDS:
        return None

    # Skip non-custom fields (those without __c suffix, except Name)
    if not field_name.endswith('__c'):
        return None

    # Skip excluded fields for this object
    if field_name in EXCLUDED_FIELDS.get(object_name, []):
        print(f"  Skipping excluded field: {field_name}")
        return None

    # Handle lookup/reference fields
    if field_type == 'reference':
        reference_to = field.get('referenceTo', [])
        if reference_to:
            ref_object = reference_to[0]
            # Skip lookups to objects we're not creating (except standard objects)
            if ref_object.endswith('__c') and ref_object not in OBJECTS_BEING_CREATED:
                print(f"  Skipping lookup to non-existent object: {field_name} -> {ref_object}")
                return None

    # Map field type
    metadata_type = FIELD_TYPE_MAP.get(field_type)
    if metadata_type is None:
        print(f"  Skipping unsupported field type: {field_name} ({field_type})")
        return None

    # Build field XML
    xml_parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">',
        f'    <fullName>{field_name}</fullName>',
    ]

    # Add label
    label = field.get('label', field_name.replace('__c', '').replace('_', ' '))
    xml_parts.append(f'    <label>{escape_xml(label)}</label>')

    # Add description if available
    inline_help = field.get('inlineHelpText')
    if inline_help:
        xml_parts.append(f'    <description>{escape_xml(inline_help)}</description>')

    # Handle different field types
    if metadata_type == 'Text':
        length = field.get('length', 255)
        xml_parts.append(f'    <length>{min(length, 255)}</length>')
        xml_parts.append('    <type>Text</type>')
        xml_parts.append(f'    <required>{str(not field.get("nillable", True)).lower()}</required>')

    elif metadata_type == 'LongTextArea':
        length = field.get('length', 32768)
        # Minimum length for LongTextArea is 256
        length = max(length, 256)
        xml_parts.append(f'    <length>{length}</length>')
        xml_parts.append('    <type>LongTextArea</type>')
        xml_parts.append('    <visibleLines>3</visibleLines>')

    elif metadata_type == 'Checkbox':
        default_value = field.get('defaultValue')
        # Checkbox defaultValue must be exactly 'true' or 'false'
        if default_value is None or default_value == '':
            default_value = False
        xml_parts.append(f'    <defaultValue>{str(bool(default_value)).lower()}</defaultValue>')
        xml_parts.append('    <type>Checkbox</type>')

    elif metadata_type == 'Number':
        precision = field.get('precision', 18)
        scale = field.get('scale', 0)
        xml_parts.append(f'    <precision>{precision}</precision>')
        xml_parts.append(f'    <scale>{scale}</scale>')
        xml_parts.append('    <type>Number</type>')
        xml_parts.append(f'    <required>{str(not field.get("nillable", True)).lower()}</required>')

    elif metadata_type == 'Currency':
        precision = field.get('precision', 18)
        scale = field.get('scale', 2)
        xml_parts.append(f'    <precision>{precision}</precision>')
        xml_parts.append(f'    <scale>{scale}</scale>')
        xml_parts.append('    <type>Currency</type>')
        xml_parts.append(f'    <required>{str(not field.get("nillable", True)).lower()}</required>')

    elif metadata_type == 'Percent':
        precision = field.get('precision', 18)
        scale = field.get('scale', 2)
        xml_parts.append(f'    <precision>{precision}</precision>')
        xml_parts.append(f'    <scale>{scale}</scale>')
        xml_parts.append('    <type>Percent</type>')
        xml_parts.append(f'    <required>{str(not field.get("nillable", True)).lower()}</required>')

    elif metadata_type in ['Phone', 'Email', 'Url']:
        xml_parts.append(f'    <type>{metadata_type}</type>')
        xml_parts.append(f'    <required>{str(not field.get("nillable", True)).lower()}</required>')

    elif metadata_type in ['Date', 'DateTime', 'Time']:
        xml_parts.append(f'    <type>{metadata_type}</type>')
        xml_parts.append(f'    <required>{str(not field.get("nillable", True)).lower()}</required>')

    elif metadata_type == 'Picklist':
        xml_parts.append('    <type>Picklist</type>')
        xml_parts.append(f'    <required>{str(not field.get("nillable", True)).lower()}</required>')
        picklist_values = field.get('picklistValues', [])
        if picklist_values:
            xml_parts.append('    <valueSet>')
            xml_parts.append('        <restricted>true</restricted>')
            xml_parts.append('        <valueSetDefinition>')
            xml_parts.append('            <sorted>false</sorted>')
            for pv in picklist_values:
                if pv.get('active', True):
                    xml_parts.append('            <value>')
                    xml_parts.append(f'                <fullName>{escape_xml(pv.get("value", ""))}</fullName>')
                    xml_parts.append(f'                <default>{str(pv.get("defaultValue", False)).lower()}</default>')
                    xml_parts.append(f'                <label>{escape_xml(pv.get("label", pv.get("value", "")))}</label>')
                    xml_parts.append('            </value>')
            xml_parts.append('        </valueSetDefinition>')
            xml_parts.append('    </valueSet>')

    elif metadata_type == 'MultiselectPicklist':
        xml_parts.append('    <type>MultiselectPicklist</type>')
        xml_parts.append(f'    <required>{str(not field.get("nillable", True)).lower()}</required>')
        xml_parts.append('    <visibleLines>4</visibleLines>')
        picklist_values = field.get('picklistValues', [])
        if picklist_values:
            xml_parts.append('    <valueSet>')
            xml_parts.append('        <restricted>true</restricted>')
            xml_parts.append('        <valueSetDefinition>')
            xml_parts.append('            <sorted>false</sorted>')
            for pv in picklist_values:
                if pv.get('active', True):
                    xml_parts.append('            <value>')
                    xml_parts.append(f'                <fullName>{escape_xml(pv.get("value", ""))}</fullName>')
                    xml_parts.append(f'                <default>{str(pv.get("defaultValue", False)).lower()}</default>')
                    xml_parts.append(f'                <label>{escape_xml(pv.get("label", pv.get("value", "")))}</label>')
                    xml_parts.append('            </value>')
            xml_parts.append('        </valueSetDefinition>')
            xml_parts.append('    </valueSet>')

    elif metadata_type == 'Lookup':
        reference_to = field.get('referenceTo', [])
        if not reference_to:
            return None
        ref_object = reference_to[0]

        # Get base relationship name from field name (remove __c)
        base_rel_name = field_name.replace('__c', '')
        parent_obj_name = object_name.replace('__c', '')

        # For lookups to standard objects OR custom objects we're creating,
        # make relationship name unique by including the parent object name
        # This avoids conflicts like "Booking__r" already existing on Booking
        standard_objects = ['User', 'Contact', 'Account', 'Lead', 'Opportunity', 'Case']
        custom_objects_being_created = ['Booking__c', 'BookingEvent__c', 'EventItem__c']

        if ref_object in standard_objects or ref_object in custom_objects_being_created:
            # Use format: FieldName_ParentObject (e.g., Booking_EventItem)
            relationship_name = f'{base_rel_name}_{parent_obj_name}'
            relationship_label = f'{base_rel_name} ({parent_obj_name})'
        else:
            relationship_name = field.get('relationshipName', base_rel_name)
            relationship_label = field.get('relationshipName', base_rel_name)

        xml_parts.append(f'    <referenceTo>{ref_object}</referenceTo>')
        xml_parts.append(f'    <relationshipName>{relationship_name}</relationshipName>')
        xml_parts.append(f'    <relationshipLabel>{escape_xml(relationship_label)}</relationshipLabel>')
        xml_parts.append('    <type>Lookup</type>')

        # Required lookups need Restrict or Cascade delete, optional can use SetNull
        is_required = not field.get('nillable', True)
        if is_required:
            xml_parts.append('    <deleteConstraint>Restrict</deleteConstraint>')
        else:
            xml_parts.append('    <deleteConstraint>SetNull</deleteConstraint>')
        xml_parts.append(f'    <required>{str(is_required).lower()}</required>')

    xml_parts.append('</CustomField>')

    return '\n'.join(xml_parts)


def get_object_xml(describe: dict) -> str:
    """Generate the main object XML."""
    object_name = describe.get('name', 'CustomObject')
    label = describe.get('label', object_name.replace('__c', ''))
    plural_label = describe.get('labelPlural', label + 's')

    # Find the Name field configuration
    name_field = None
    for field in describe.get('fields', []):
        if field.get('name') == 'Name':
            name_field = field
            break

    name_type = 'Text'
    if name_field and name_field.get('type') == 'string' and name_field.get('autoNumber'):
        name_type = 'AutoNumber'

    xml_parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">',
        f'    <label>{escape_xml(label)}</label>',
        f'    <pluralLabel>{escape_xml(plural_label)}</pluralLabel>',
        '    <deploymentStatus>Deployed</deploymentStatus>',
        '    <sharingModel>ReadWrite</sharingModel>',
        '    <enableActivities>true</enableActivities>',
        '    <enableHistory>false</enableHistory>',
        '    <enableReports>true</enableReports>',
        '    <nameField>',
    ]

    if name_type == 'AutoNumber':
        display_format = name_field.get('defaultValueFormula', '{0000}')
        xml_parts.append(f'        <displayFormat>{display_format}</displayFormat>')
        xml_parts.append('        <label>Name</label>')
        xml_parts.append('        <type>AutoNumber</type>')
    else:
        xml_parts.append('        <label>Name</label>')
        xml_parts.append('        <type>Text</type>')

    xml_parts.append('    </nameField>')
    xml_parts.append('</CustomObject>')

    return '\n'.join(xml_parts)


def escape_xml(text: str) -> str:
    """Escape special XML characters."""
    if not text:
        return ''
    return (text
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace("'", '&apos;'))


def process_object(json_path: str, output_base: str) -> dict:
    """Process a single object JSON and generate metadata files."""
    print(f"\nProcessing: {json_path}")

    with open(json_path, 'r') as f:
        content = f.read()

    # Handle files that include HTTP headers (from Workbench raw response)
    # Find the start of JSON (first { character)
    json_start = content.find('{')
    if json_start > 0:
        content = content[json_start:]

    # Find the last closing brace (end of JSON object)
    json_end = content.rfind('}')
    if json_end > 0:
        content = content[:json_end + 1]

    describe = json.loads(content)

    object_name = describe.get('name', 'Unknown')
    print(f"Object: {object_name}")
    print(f"Label: {describe.get('label')}")
    print(f"Fields count: {len(describe.get('fields', []))}")

    # Create output directories
    object_dir = Path(output_base) / 'objects' / object_name
    fields_dir = object_dir / 'fields'
    fields_dir.mkdir(parents=True, exist_ok=True)

    # Generate main object XML
    object_xml = get_object_xml(describe)
    object_file = object_dir / f'{object_name}.object-meta.xml'
    with open(object_file, 'w') as f:
        f.write(object_xml)
    print(f"Created: {object_file}")

    # Generate field XMLs
    fields_created = 0
    fields_skipped = 0

    for field in describe.get('fields', []):
        field_name = field.get('name', '')
        field_xml = get_field_xml(field, object_name)

        if field_xml:
            field_file = fields_dir / f'{field_name}.field-meta.xml'
            with open(field_file, 'w') as f:
                f.write(field_xml)
            fields_created += 1
        else:
            fields_skipped += 1

    print(f"Fields created: {fields_created}")
    print(f"Fields skipped: {fields_skipped}")

    return {
        'object_name': object_name,
        'fields_created': fields_created,
        'fields_skipped': fields_skipped
    }


def generate_package_xml(objects: list, output_base: str):
    """Generate package.xml for deployment."""
    xml_parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<Package xmlns="http://soap.sforce.com/2006/04/metadata">',
        '    <types>',
    ]

    for obj in objects:
        xml_parts.append(f'        <members>{obj}</members>')

    xml_parts.extend([
        '        <name>CustomObject</name>',
        '    </types>',
        '    <types>',
    ])

    for obj in objects:
        xml_parts.append(f'        <members>{obj}.*</members>')

    xml_parts.extend([
        '        <name>CustomField</name>',
        '    </types>',
        '    <version>62.0</version>',
        '</Package>'
    ])

    package_file = Path(output_base) / 'package.xml'
    with open(package_file, 'w') as f:
        f.write('\n'.join(xml_parts))
    print(f"\nCreated: {package_file}")


def main():
    # Default paths
    downloads_dir = Path.home() / 'Downloads'
    project_dir = Path('/Users/rreboucas/Documents/SFDX Projects/fdesdo/Fdesdo')
    output_base = project_dir / 'force-app' / 'main' / 'default'

    # JSON files to process (in deployment order: child to parent)
    json_files = [
        ('EventItem__c.json', 'EventItem__c'),
        ('BookigEvent__c.json', 'BookingEvent__c'),  # Note: typo in filename
        ('Booking__c.json', 'Booking__c'),
    ]

    results = []
    objects_processed = []

    for filename, expected_name in json_files:
        json_path = downloads_dir / filename
        if json_path.exists():
            result = process_object(str(json_path), str(output_base))
            results.append(result)
            objects_processed.append(result['object_name'])
        else:
            print(f"\nWarning: {json_path} not found")

    # Generate package.xml
    if objects_processed:
        manifest_dir = project_dir / 'manifest'
        manifest_dir.mkdir(exist_ok=True)
        generate_package_xml(objects_processed, str(manifest_dir))

    # Summary
    print("\n" + "="*50)
    print("SUMMARY")
    print("="*50)
    for result in results:
        print(f"{result['object_name']}: {result['fields_created']} fields created")

    print("\nDeployment order:")
    print("1. EventItem__c (child)")
    print("2. BookingEvent__c (middle)")
    print("3. Booking__c (parent)")

    print("\nTo deploy, run:")
    print("sf project deploy start --manifest manifest/package.xml")


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""
Script to generate Salesforce metadata XML from REST API describe JSON.
Parses the describe output and creates object-meta.xml and field-meta.xml files.
"""

import json
import os
import sys

def get_field_type_mapping(field):
    """Map REST API field types to metadata XML field types."""
    type_map = {
        'string': 'Text',
        'textarea': 'LongTextArea',
        'boolean': 'Checkbox',
        'int': 'Number',
        'double': 'Number',
        'currency': 'Currency',
        'percent': 'Percent',
        'date': 'Date',
        'datetime': 'DateTime',
        'time': 'Time',
        'phone': 'Phone',
        'url': 'Url',
        'email': 'Email',
        'picklist': 'Picklist',
        'multipicklist': 'MultiselectPicklist',
        'reference': 'Lookup',
        'id': None,  # Skip ID fields
        'address': None,  # Compound field
        'location': None,  # Compound field
    }

    field_type = field.get('type', '').lower()

    # Handle special cases
    if field_type == 'string' and field.get('length', 0) > 255:
        return 'LongTextArea'
    if field_type == 'textarea' and field.get('htmlFormatted'):
        return 'Html'
    if field_type == 'reference' and field.get('relationshipOrder') is not None:
        return 'MasterDetail'

    return type_map.get(field_type)

def generate_picklist_xml(picklist_values):
    """Generate picklist values XML."""
    if not picklist_values:
        return ""

    xml = "        <valueSet>\n"
    xml += "            <restricted>true</restricted>\n"
    xml += "            <valueSetDefinition>\n"
    xml += "                <sorted>false</sorted>\n"

    for pv in picklist_values:
        if pv.get('active', True):
            xml += "                <value>\n"
            xml += f"                    <fullName>{escape_xml(pv.get('value', ''))}</fullName>\n"
            if pv.get('defaultValue'):
                xml += "                    <default>true</default>\n"
            else:
                xml += "                    <default>false</default>\n"
            xml += f"                    <label>{escape_xml(pv.get('label', pv.get('value', '')))}</label>\n"
            xml += "                </value>\n"

    xml += "            </valueSetDefinition>\n"
    xml += "        </valueSet>\n"
    return xml

def escape_xml(text):
    """Escape special XML characters."""
    if text is None:
        return ""
    text = str(text)
    text = text.replace("&", "&amp;")
    text = text.replace("<", "&lt;")
    text = text.replace(">", "&gt;")
    text = text.replace('"', "&quot;")
    text = text.replace("'", "&apos;")
    return text

def generate_field_xml(field, object_name):
    """Generate field metadata XML for a custom field."""
    field_name = field.get('name', '')

    # Skip standard fields and non-custom fields
    if not field.get('custom', False):
        return None

    # Skip formula fields that reference unknown objects (will cause deployment errors)
    # We'll include them but they may need manual adjustment

    metadata_type = get_field_type_mapping(field)
    if metadata_type is None:
        return None

    xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
    xml += '<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">\n'
    xml += f'    <fullName>{field_name}</fullName>\n'

    # Add description if available
    if field.get('inlineHelpText'):
        xml += f'    <description>{escape_xml(field.get("inlineHelpText"))}</description>\n'

    # External ID
    if field.get('externalId'):
        xml += '    <externalId>true</externalId>\n'
    else:
        xml += '    <externalId>false</externalId>\n'

    # Help text
    if field.get('inlineHelpText'):
        xml += f'    <inlineHelpText>{escape_xml(field.get("inlineHelpText"))}</inlineHelpText>\n'

    # Label
    xml += f'    <label>{escape_xml(field.get("label", field_name))}</label>\n'

    # Type-specific attributes
    if metadata_type == 'Text':
        length = min(field.get('length', 255), 255)
        xml += f'    <length>{length}</length>\n'
        xml += '    <required>false</required>\n'
        xml += f'    <type>{metadata_type}</type>\n'
        xml += '    <unique>false</unique>\n'

    elif metadata_type == 'LongTextArea':
        length = field.get('length', 32768)
        xml += f'    <length>{length}</length>\n'
        xml += f'    <type>{metadata_type}</type>\n'
        xml += '    <visibleLines>3</visibleLines>\n'

    elif metadata_type == 'Html':
        length = field.get('length', 32768)
        xml += f'    <length>{length}</length>\n'
        xml += f'    <type>{metadata_type}</type>\n'
        xml += '    <visibleLines>10</visibleLines>\n'

    elif metadata_type == 'Checkbox':
        default_value = field.get('defaultValue', False)
        xml += f'    <defaultValue>{str(default_value).lower()}</defaultValue>\n'
        xml += f'    <type>{metadata_type}</type>\n'

    elif metadata_type == 'Number':
        precision = field.get('precision', 18)
        scale = field.get('scale', 0)
        xml += f'    <precision>{precision}</precision>\n'
        xml += '    <required>false</required>\n'
        xml += f'    <scale>{scale}</scale>\n'
        xml += f'    <type>{metadata_type}</type>\n'
        xml += '    <unique>false</unique>\n'

    elif metadata_type == 'Currency':
        precision = field.get('precision', 18)
        scale = field.get('scale', 2)
        xml += f'    <precision>{precision}</precision>\n'
        xml += '    <required>false</required>\n'
        xml += f'    <scale>{scale}</scale>\n'
        xml += f'    <type>{metadata_type}</type>\n'

    elif metadata_type == 'Percent':
        precision = field.get('precision', 18)
        scale = field.get('scale', 2)
        xml += f'    <precision>{precision}</precision>\n'
        xml += '    <required>false</required>\n'
        xml += f'    <scale>{scale}</scale>\n'
        xml += f'    <type>{metadata_type}</type>\n'

    elif metadata_type in ('Date', 'DateTime', 'Time', 'Phone', 'Url', 'Email'):
        xml += '    <required>false</required>\n'
        xml += f'    <type>{metadata_type}</type>\n'

    elif metadata_type == 'Picklist':
        xml += '    <required>false</required>\n'
        xml += f'    <type>{metadata_type}</type>\n'
        xml += generate_picklist_xml(field.get('picklistValues', []))

    elif metadata_type == 'MultiselectPicklist':
        xml += '    <required>false</required>\n'
        xml += f'    <type>{metadata_type}</type>\n'
        xml += generate_picklist_xml(field.get('picklistValues', []))
        xml += '    <visibleLines>4</visibleLines>\n'

    elif metadata_type in ('Lookup', 'MasterDetail'):
        reference_to = field.get('referenceTo', [])
        if reference_to:
            ref_object = reference_to[0]
            xml += '    <deleteConstraint>SetNull</deleteConstraint>\n' if metadata_type == 'Lookup' else ''
            xml += f'    <referenceTo>{ref_object}</referenceTo>\n'
            rel_name = field.get('relationshipName', '')
            if rel_name:
                xml += f'    <relationshipLabel>{escape_xml(rel_name)}</relationshipLabel>\n'
                xml += f'    <relationshipName>{rel_name}</relationshipName>\n'
            xml += '    <required>false</required>\n' if metadata_type == 'Lookup' else ''
            xml += f'    <type>{metadata_type}</type>\n'

    xml += '</CustomField>\n'
    return xml

def generate_object_xml(describe_data):
    """Generate object metadata XML."""
    object_name = describe_data.get('name', 'Unknown')
    label = describe_data.get('label', object_name)
    label_plural = describe_data.get('labelPlural', label + 's')

    xml = '<?xml version="1.0" encoding="UTF-8"?>\n'
    xml += '<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">\n'
    xml += '    <actionOverrides>\n'
    xml += '        <actionName>Accept</actionName>\n'
    xml += '        <type>Default</type>\n'
    xml += '    </actionOverrides>\n'
    xml += '    <actionOverrides>\n'
    xml += '        <actionName>CancelEdit</actionName>\n'
    xml += '        <type>Default</type>\n'
    xml += '    </actionOverrides>\n'
    xml += '    <actionOverrides>\n'
    xml += '        <actionName>Clone</actionName>\n'
    xml += '        <type>Default</type>\n'
    xml += '    </actionOverrides>\n'
    xml += '    <actionOverrides>\n'
    xml += '        <actionName>Delete</actionName>\n'
    xml += '        <type>Default</type>\n'
    xml += '    </actionOverrides>\n'
    xml += '    <actionOverrides>\n'
    xml += '        <actionName>Edit</actionName>\n'
    xml += '        <type>Default</type>\n'
    xml += '    </actionOverrides>\n'
    xml += '    <actionOverrides>\n'
    xml += '        <actionName>List</actionName>\n'
    xml += '        <type>Default</type>\n'
    xml += '    </actionOverrides>\n'
    xml += '    <actionOverrides>\n'
    xml += '        <actionName>New</actionName>\n'
    xml += '        <type>Default</type>\n'
    xml += '    </actionOverrides>\n'
    xml += '    <actionOverrides>\n'
    xml += '        <actionName>SaveEdit</actionName>\n'
    xml += '        <type>Default</type>\n'
    xml += '    </actionOverrides>\n'
    xml += '    <actionOverrides>\n'
    xml += '        <actionName>Tab</actionName>\n'
    xml += '        <type>Default</type>\n'
    xml += '    </actionOverrides>\n'
    xml += '    <actionOverrides>\n'
    xml += '        <actionName>View</actionName>\n'
    xml += '        <type>Default</type>\n'
    xml += '    </actionOverrides>\n'
    xml += '    <allowInChatterGroups>false</allowInChatterGroups>\n'
    xml += '    <compactLayoutAssignment>SYSTEM</compactLayoutAssignment>\n'
    xml += '    <deploymentStatus>Deployed</deploymentStatus>\n'
    xml += '    <enableActivities>false</enableActivities>\n'
    xml += '    <enableBulkApi>true</enableBulkApi>\n'
    xml += '    <enableFeeds>false</enableFeeds>\n'
    xml += '    <enableHistory>false</enableHistory>\n'
    xml += '    <enableLicensing>false</enableLicensing>\n'
    xml += '    <enableReports>false</enableReports>\n'
    xml += '    <enableSearch>true</enableSearch>\n'
    xml += '    <enableSharing>true</enableSharing>\n'
    xml += '    <enableStreamingApi>true</enableStreamingApi>\n'
    xml += '    <externalSharingModel>ReadWrite</externalSharingModel>\n'
    xml += f'    <label>{escape_xml(label)}</label>\n'

    # Determine name field type
    name_field = None
    for field in describe_data.get('fields', []):
        if field.get('nameField'):
            name_field = field
            break

    if name_field:
        if name_field.get('autoNumber'):
            xml += '    <nameField>\n'
            xml += '        <displayFormat>{0}</displayFormat>\n'
            xml += f'        <label>{escape_xml(name_field.get("label", "Name"))}</label>\n'
            xml += '        <type>AutoNumber</type>\n'
            xml += '    </nameField>\n'
        else:
            xml += '    <nameField>\n'
            xml += f'        <label>{escape_xml(name_field.get("label", "Name"))}</label>\n'
            xml += '        <type>Text</type>\n'
            xml += '    </nameField>\n'

    xml += f'    <pluralLabel>{escape_xml(label_plural)}</pluralLabel>\n'
    xml += '    <searchLayouts/>\n'
    xml += '    <sharingModel>ReadWrite</sharingModel>\n'
    xml += '    <visibility>Public</visibility>\n'
    xml += '</CustomObject>\n'

    return xml

def process_describe_json(json_file, output_dir):
    """Process a describe JSON file and generate metadata."""
    print(f"Processing: {json_file}")

    with open(json_file, 'r') as f:
        describe_data = json.load(f)

    object_name = describe_data.get('name', 'Unknown__c')
    print(f"Object: {object_name}")

    # Create object directory
    object_dir = os.path.join(output_dir, 'objects', object_name)
    fields_dir = os.path.join(object_dir, 'fields')
    os.makedirs(fields_dir, exist_ok=True)

    # Generate object XML
    object_xml = generate_object_xml(describe_data)
    object_file = os.path.join(object_dir, f'{object_name}.object-meta.xml')
    with open(object_file, 'w') as f:
        f.write(object_xml)
    print(f"Created: {object_file}")

    # Generate field XMLs
    field_count = 0
    for field in describe_data.get('fields', []):
        field_xml = generate_field_xml(field, object_name)
        if field_xml:
            field_name = field.get('name', '')
            field_file = os.path.join(fields_dir, f'{field_name}.field-meta.xml')
            with open(field_file, 'w') as f:
                f.write(field_xml)
            field_count += 1
            print(f"  Created field: {field_name}")

    print(f"Created {field_count} custom fields for {object_name}")
    return object_name, field_count

def main():
    base_dir = '/Users/rreboucas/Documents/SFDX Projects/fdesdo/Fdesdo'
    dataimport_dir = os.path.join(base_dir, 'dataimport')
    output_dir = os.path.join(base_dir, 'force-app/main/default')

    # Process GuestroomType__c first (parent)
    guestroom_type_file = os.path.join(dataimport_dir, 'GuestriimType__c.json')
    if os.path.exists(guestroom_type_file):
        process_describe_json(guestroom_type_file, output_dir)
    else:
        print(f"File not found: {guestroom_type_file}")

    # Process GuestroomTypeDay__c second (child)
    guestroom_type_day_file = os.path.join(dataimport_dir, 'GuestroomTypeDay__c.json')
    if os.path.exists(guestroom_type_day_file):
        process_describe_json(guestroom_type_day_file, output_dir)
    else:
        print(f"File not found: {guestroom_type_day_file}")

if __name__ == '__main__':
    main()

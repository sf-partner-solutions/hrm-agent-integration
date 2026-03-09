#!/usr/bin/env python3
"""
Script to fix the order of elements in the Delphi_Admin permission set.
Moves fieldPermissions to before hasActivationRequired.
"""

import re

def main():
    perm_set_file = '/Users/rreboucas/Documents/SFDX Projects/fdesdo/Fdesdo/force-app/main/default/permissionsets/Delphi_Admin.permissionset-meta.xml'

    with open(perm_set_file, 'r') as f:
        content = f.read()

    # Find fieldPermissions that appear after label
    # Pattern: find the section from <label> to the first <objectPermissions>

    # Split the content at <hasActivationRequired>
    parts = content.split('<hasActivationRequired>')

    if len(parts) != 2:
        print("Unexpected format - could not find hasActivationRequired")
        return

    before_has_activation = parts[0]
    after_has_activation = '<hasActivationRequired>' + parts[1]

    # Now find fieldPermissions after label in the after_has_activation part
    # Split at <label>
    label_parts = after_has_activation.split('<label>')

    if len(label_parts) != 2:
        print("Unexpected format - could not find label")
        return

    before_label = label_parts[0]  # contains hasActivationRequired
    after_label = '<label>' + label_parts[1]

    # Find the fieldPermissions after the label closing tag
    # Split after </label>
    label_end_parts = after_label.split('</label>')

    if len(label_end_parts) != 2:
        print("Unexpected format - could not find label end")
        return

    label_section = label_end_parts[0] + '</label>'
    after_label_end = label_end_parts[1]

    # Extract fieldPermissions from after_label_end
    # Find all fieldPermissions
    field_perm_pattern = r'(\s*<fieldPermissions>.*?</fieldPermissions>)'
    field_perms = re.findall(field_perm_pattern, after_label_end, re.DOTALL)

    if not field_perms:
        print("No fieldPermissions found after label")
        return

    print(f"Found {len(field_perms)} fieldPermissions after label that need to be moved")

    # Remove the fieldPermissions from after_label_end
    remaining_after_label = after_label_end
    for fp in field_perms:
        remaining_after_label = remaining_after_label.replace(fp, '', 1)

    # Combine fieldPermissions as a string
    field_perms_str = '\n'.join(field_perms)

    # Reconstruct the file:
    # before_has_activation (includes existing fieldPermissions)
    # + NEW fieldPermissions
    # + before_label (hasActivationRequired line)
    # + label_section
    # + remaining_after_label (objectPermissions, tabSettings, etc)

    # Insert new field permissions before hasActivationRequired
    new_content = before_has_activation.rstrip() + '\n' + field_perms_str + '\n    ' + before_label.strip() + '\n    ' + label_section.strip() + remaining_after_label

    with open(perm_set_file, 'w') as f:
        f.write(new_content)

    print("Fixed permission set order")

if __name__ == '__main__':
    main()

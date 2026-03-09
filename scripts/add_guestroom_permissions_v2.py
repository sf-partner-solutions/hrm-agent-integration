#!/usr/bin/env python3
"""
Script to add GuestroomType__c and GuestroomTypeDay__c permissions to Delphi_Admin permission set.
Fixed version that maintains proper XML element ordering.
"""

import os

# Field lists
guestroom_type_fields = [
    "Abbreviation__c", "AlternateAbbreviationDE__c", "AlternateAbbreviationEL__c",
    "AlternateAbbreviationENUS__c", "AlternateAbbreviationES__c", "AlternateAbbreviationFR__c",
    "AlternateAbbreviationHU__c", "AlternateAbbreviationIT__c", "AlternateAbbreviationJA__c",
    "AlternateAbbreviationNLNL__c", "AlternateAbbreviationPL__c", "AlternateAbbreviationPTBR__c",
    "AlternateAbbreviationPTPT__c", "AlternateAbbreviationRU__c", "AlternateAbbreviationTR__c",
    "AlternateAbbreviationZHCN__c", "AlternateAbbreviationZHTW__c", "AlternateAbbreviation__c",
    "AlternateLanguageCode__c", "AlternateNameDE__c", "AlternateNameEL__c", "AlternateNameENUS__c",
    "AlternateNameES__c", "AlternateNameFR__c", "AlternateNameHU__c", "AlternateNameIT__c",
    "AlternateNameJA__c", "AlternateNameNLNL__c", "AlternateNamePL__c", "AlternateNamePTBR__c",
    "AlternateNamePTPT__c", "AlternateNameRU__c", "AlternateNameTR__c", "AlternateNameZHCN__c",
    "AlternateNameZHTW__c", "AlternateName__c", "DoubleAllocation__c", "ExternalId__c",
    "GuestroomCategoryName__c", "GuestroomCategory__c", "Inventory__c", "IsActive__c",
    "IsRunOfHouse__c", "LSDefaultBudgetedRate__c", "LSDefaultBudgetedRooms__c",
    "LSDefaultMinimumAcceptableRate__c", "LSDefaultOutOfService__c", "LSDefaultRackRate__c",
    "LSDefaultTransientProtected__c", "LSRulesJSON__c", "Location__c", "MaxOccupants__c",
    "NIHRMMigrations_ExternalID__c", "NumberOfBeds__c", "Property__c", "QuadAllocation__c",
    "SingleAllocation__c", "SortOrder__c", "SourceSystemExternalId__c", "TripleAllocation__c",
    "UniqueExternalId__c"
]

guestroom_type_day_fields = [
    "AverageRateBlockedDefTent__c", "AverageRateBlockedDef__c", "AverageRateBlockedTent__c",
    "BlockedDefTent__c", "BlockedDefinite__c", "BlockedProspect__c", "BlockedTentative__c",
    "BudgetedRate__c", "BudgetedRooms__c", "DailyRoomInventory__c", "EffectiveDateString__c",
    "EffectiveDate__c", "ExternalId__c", "ForecastedOccupancy__c", "GroupAvailable__c",
    "GuestroomType__c", "IsRunOfHouse__c", "Location__c", "MinimumAcceptableRate__c",
    "NIHRMMigrations_ExternalID__c", "OccupancyPercentage__c", "OutOfService__c",
    "PMSOnlyTransient__c", "PhysicalRoomInventory__c", "RackRate__c", "RevenueBlockedDef__c",
    "RevenueBlockedTent__c", "RevenueDefTent__c", "RoomTypeAvailable__c",
    "SourceSystemExternalId__c", "TotalAverageRateBlockedDefTent__c", "TotalAverageRateBlockedDef__c",
    "TotalAverageRateBlockedTent__c", "TotalBlockedDefTent__c", "TotalBlockedDefinite__c",
    "TotalBlockedProspect__c", "TotalBlockedTentative__c", "TotalDailyRoomInventory__c",
    "TotalForecastedOccupancy__c", "TotalGroupAvailable__c", "TotalGroupCeiling__c",
    "TotalOccupancyPercentage__c", "TotalOutOfService__c", "TotalPhysicalRoomInventory__c",
    "TotalRevenueBlockedDef__c", "TotalRevenueBlockedTent__c", "TotalRevenueDefTent__c",
    "TotalRoomTypeAvailable__c", "TotalTransientProtected__c", "TotalTransientSold__c",
    "TransientProtectedRemaining__c", "TransientProtected__c", "TransientSold__c",
    "UniqueExternalId__c"
]

def generate_field_permissions(object_name, fields):
    """Generate field permission XML entries."""
    result = []
    for field in fields:
        result.append(f"""    <fieldPermissions>
        <editable>true</editable>
        <field>{object_name}.{field}</field>
        <readable>true</readable>
    </fieldPermissions>""")
    return '\n'.join(result)

def generate_object_permissions(object_name):
    """Generate object permission XML entry."""
    return f"""    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>true</allowDelete>
        <allowEdit>true</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>true</modifyAllRecords>
        <object>{object_name}</object>
        <viewAllFields>true</viewAllFields>
        <viewAllRecords>true</viewAllRecords>
    </objectPermissions>"""

def generate_tab_settings(object_name):
    """Generate tab settings XML entry."""
    return f"""    <tabSettings>
        <tab>{object_name}</tab>
        <visibility>Visible</visibility>
    </tabSettings>"""

def main():
    base_dir = '/Users/rreboucas/Documents/SFDX Projects/fdesdo/Fdesdo'
    perm_set_file = os.path.join(base_dir, 'force-app/main/default/permissionsets/Delphi_Admin.permissionset-meta.xml')

    # Read current permission set
    with open(perm_set_file, 'r') as f:
        content = f.read()

    # Generate new field permissions
    guestroom_type_perms = generate_field_permissions('GuestroomType__c', guestroom_type_fields)
    guestroom_type_day_perms = generate_field_permissions('GuestroomTypeDay__c', guestroom_type_day_fields)

    # Generate object permissions
    guestroom_type_obj_perm = generate_object_permissions('GuestroomType__c')
    guestroom_type_day_obj_perm = generate_object_permissions('GuestroomTypeDay__c')

    # Generate tab settings
    guestroom_type_tab = generate_tab_settings('GuestroomType__c')
    guestroom_type_day_tab = generate_tab_settings('GuestroomTypeDay__c')

    # Find the position to insert field permissions (before hasActivationRequired)
    has_activation_pos = content.find('    <hasActivationRequired>')
    if has_activation_pos == -1:
        print("Could not find hasActivationRequired in permission set")
        return

    # Insert field permissions before hasActivationRequired
    new_field_perms = guestroom_type_perms + '\n' + guestroom_type_day_perms + '\n'
    content = content[:has_activation_pos] + new_field_perms + content[has_activation_pos:]

    # Find where to insert object permissions (before tabSettings)
    tab_settings_pos = content.find('    <tabSettings>')
    if tab_settings_pos == -1:
        print("Could not find tabSettings in permission set")
        return

    new_obj_perms = guestroom_type_obj_perm + '\n' + guestroom_type_day_obj_perm + '\n'
    content = content[:tab_settings_pos] + new_obj_perms + content[tab_settings_pos:]

    # Find where to insert tab settings (before userPermissions)
    user_perm_pos = content.find('    <userPermissions>')
    if user_perm_pos == -1:
        print("Could not find userPermissions in permission set")
        return

    new_tab_settings = guestroom_type_tab + '\n' + guestroom_type_day_tab + '\n'
    content = content[:user_perm_pos] + new_tab_settings + content[user_perm_pos:]

    # Write updated permission set
    with open(perm_set_file, 'w') as f:
        f.write(content)

    print(f"Added {len(guestroom_type_fields)} GuestroomType__c field permissions")
    print(f"Added {len(guestroom_type_day_fields)} GuestroomTypeDay__c field permissions")
    print("Added object permissions for both objects")
    print("Added tab settings for both objects")

if __name__ == '__main__':
    main()

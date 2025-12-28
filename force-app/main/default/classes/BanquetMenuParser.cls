/**
 * @description Parser class to handle JSON output from Banquet Menu Ingestion prompt template
 * Converts extracted menu data into Item__c records
 */
public with sharing class BanquetMenuParser {

    /**
     * @description Wrapper class for the extraction metadata
     */
    public class ExtractionMetadata {
        @AuraEnabled public String venue_name;
        @AuraEnabled public String menu_title;
        @AuraEnabled public String extracted_date;
        @AuraEnabled public String source_file;
        @AuraEnabled public Integer total_items_found;
        @AuraEnabled public String extraction_notes;
    }

    /**
     * @description Wrapper class for menu items
     */
    public class MenuItem {
        @AuraEnabled public String Name;
        @AuraEnabled public String RecordType;
        @AuraEnabled public String ItemType;
        @AuraEnabled public Decimal UnitPrice;
        @AuraEnabled public String SoldByUnit;
        @AuraEnabled public String ServingUnit;
        @AuraEnabled public String RichDescription;
        @AuraEnabled public String Description;
        @AuraEnabled public String ItemCategory;
        @AuraEnabled public String RevenueClassification;
        @AuraEnabled public Boolean IsActive;
        @AuraEnabled public Boolean IsInclusive;
        @AuraEnabled public String QuantityCalculation;
        @AuraEnabled public String Property;
        @AuraEnabled public String MasterSource;
        @AuraEnabled public String Abbreviation;
        @AuraEnabled public String LocationId; // For property association from LWC

    }

    /**
     * @description Main response wrapper
     */
    public class MenuExtractionResponse {
        @AuraEnabled public ExtractionMetadata extraction_metadata;
        @AuraEnabled public List<MenuItem> items;
    }

    /**
     * @description Parse JSON response from prompt template
     * @param jsonResponse The JSON string from the prompt template
     * @return MenuExtractionResponse object
     */
    @AuraEnabled
    public static MenuExtractionResponse parseMenuJSON(String jsonResponse) {
        try {
            // Remove any markdown formatting if present (defensive coding)
            if (jsonResponse.contains('```')) {
                jsonResponse = jsonResponse.substringBetween('```json', '```');
                if (String.isBlank(jsonResponse)) {
                    jsonResponse = jsonResponse.substringBetween('```', '```');
                }
            }

            // Parse JSON into wrapper class
            MenuExtractionResponse response = (MenuExtractionResponse) JSON.deserialize(
                jsonResponse,
                MenuExtractionResponse.class
            );

            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to parse menu data: ' + e.getMessage());
        }
    }

    /**
     * @description Convert MenuItem to Item__c record
     * @param menuItem The menu item from parsed JSON
     * @return Item__c record ready for insert
     */
    public static Item__c convertToItemRecord(MenuItem menuItem) {
        Item__c item = new Item__c();

        // Map basic fields
        item.Name = truncateString(menuItem.Name, 80);
        item.UnitPrice__c = menuItem.UnitPrice;
        item.SoldByUnit__c = menuItem.SoldByUnit;
        item.ServingUnit__c = menuItem.ServingUnit;
        item.RichDescription__c = menuItem.RichDescription;
        item.Description__c = menuItem.Description;
        item.IsActive__c = menuItem.IsActive != null ? menuItem.IsActive : true;
        item.IsInclusive__c = menuItem.IsInclusive != null ? menuItem.IsInclusive : false;

        // Handle QuantityCalculation__c - These picklists appear to have configuration issues
        // where values like "Per Person" show in describe but aren't valid for insert
        // For now, we'll leave these fields null to avoid errors
        // TODO: Fix picklist configuration in Salesforce Setup to allow proper values
        /*
        if (String.isNotBlank(menuItem.QuantityCalculation)) {
            item.QuantityCalculation__c = menuItem.QuantityCalculation;
        }
        if (String.isNotBlank(menuItem.MasterSource)) {
            item.MasterSource__c = menuItem.MasterSource;
        }
        */
        item.Abbreviation__c = truncateString(menuItem.Abbreviation, 24);

        // Map ItemType__c
        if (String.isNotBlank(menuItem.ItemType)) {
            item.ItemType__c = menuItem.ItemType;
        }

        // Handle ItemCategory__c - this is a restricted picklist, so we need to validate the value
        // For now, we'll skip setting this field since the picklist only has generic values
        // TODO: Configure the ItemCategoryName__c picklist with actual category values
        /*
        if (String.isNotBlank(menuItem.ItemCategory)) {
            item.ItemCategoryName__c = menuItem.ItemCategory;
        }
        */

        // Handle RevenueClassification__c - map string to lookup
        if (String.isNotBlank(menuItem.RevenueClassification)) {
            Id revenueClassId = getRevenueClassificationId(menuItem.RevenueClassification);
            if (revenueClassId != null) {
                item.RevenueClassification__c = revenueClassId;
            }
        }

        // Handle Location__c (property association from LWC)
        if (String.isNotBlank(menuItem.LocationId)) {
            item.Location__c = menuItem.LocationId;
        }

        return item;
    }

    /**
     * @description Get RevenueClassification__c Id by name
     * @param classificationName The name to search for
     * @return Id of the RevenueClassification__c record or null
     */
    private static Id getRevenueClassificationId(String classificationName) {
        try {
            List<RevenueClassification__c> classifications = [
                SELECT Id
                FROM RevenueClassification__c
                WHERE Name = :classificationName
                    AND IsActive__c = true
                LIMIT 1
            ];

            if (!classifications.isEmpty()) {
                return classifications[0].Id;
            }
        } catch (Exception e) {
            System.debug('Error finding RevenueClassification: ' + e.getMessage());
        }
        return null;
    }

    /**
     * @description Helper method to truncate strings
     * @param input The string to truncate
     * @param maxLength Maximum allowed length
     * @return Truncated string
     */
    private static String truncateString(String input, Integer maxLength) {
        if (String.isBlank(input)) {
            return input;
        }
        if (input.length() <= maxLength) {
            return input;
        }
        return input.substring(0, maxLength - 3) + '...';
    }

    /**
     * @description Get appropriate record type ID based on record type name
     * @param recordTypeName Developer name of the record type
     * @return Record Type Id
     */
    public static Id getItemRecordTypeId(String recordTypeName) {
        try {
            return Schema.SObjectType.Item__c.getRecordTypeInfosByDeveloperName()
                .get(recordTypeName).getRecordTypeId();
        } catch (Exception e) {
            // Default to Property_Item if not found
            return Schema.SObjectType.Item__c.getRecordTypeInfosByDeveloperName()
                .get('Property_Item').getRecordTypeId();
        }
    }
}
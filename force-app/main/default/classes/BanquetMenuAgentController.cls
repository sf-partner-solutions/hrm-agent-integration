/**
 * @description Controller for Banquet Menu Ingestion Agent Action
 * Handles the flow from PDF upload to Item__c record creation
 */
public with sharing class BanquetMenuAgentController {

    /**
     * @description Process the prompt template response and prepare items for review
     * @param promptResponse The JSON response from the AI prompt template
     * @return Parsed menu extraction response with items ready for review
     */
    @AuraEnabled
    public static BanquetMenuParser.MenuExtractionResponse processMenuExtraction(String promptResponse) {
        try {
            // Parse the JSON response
            BanquetMenuParser.MenuExtractionResponse response = BanquetMenuParser.parseMenuJSON(promptResponse);

            // Validate and enhance the items
            if (response != null && response.items != null) {
                for (BanquetMenuParser.MenuItem item : response.items) {
                    // Set default values if missing
                    if (item.IsActive == null) {
                        item.IsActive = true;
                    }
                    if (String.isBlank(item.MasterSource)) {
                        item.MasterSource = 'Property';
                    }
                    if (String.isBlank(item.QuantityCalculation)) {
                        item.QuantityCalculation = item.ItemType == 'Item' ? 'Per Event' : 'Per Person';
                    }
                }
            }

            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Error processing menu extraction: ' + e.getMessage());
        }
    }

    /**
     * @description Create Item__c records from the extracted menu items
     * @param menuItems List of menu items to create
     * @return Result object with success status and created record IDs
     */
    @AuraEnabled
    public static ItemCreationResult createMenuItems(List<BanquetMenuParser.MenuItem> menuItems) {
        ItemCreationResult result = new ItemCreationResult();
        List<Item__c> itemsToInsert = new List<Item__c>();
        List<String> errors = new List<String>();

        // Savepoint for transaction rollback if needed
        Savepoint sp = Database.setSavepoint();

        try {
            // Convert menu items to Item__c records
            for (BanquetMenuParser.MenuItem menuItem : menuItems) {
                try {
                    Item__c item = BanquetMenuParser.convertToItemRecord(menuItem);

                    // Set record type based on the RecordType field
                    if (String.isNotBlank(menuItem.RecordType)) {
                        item.RecordTypeId = BanquetMenuParser.getItemRecordTypeId(menuItem.RecordType);
                    }

                    itemsToInsert.add(item);
                } catch (Exception e) {
                    errors.add('Error processing item "' + menuItem.Name + '": ' + e.getMessage());
                }
            }

            // Insert items if we have any
            if (!itemsToInsert.isEmpty()) {
                Database.SaveResult[] saveResults = Database.insert(itemsToInsert, false);

                Integer successCount = 0;
                Integer failureCount = 0;

                for (Integer i = 0; i < saveResults.size(); i++) {
                    Database.SaveResult sr = saveResults[i];
                    if (sr.isSuccess()) {
                        result.createdItemIds.add(sr.getId());
                        successCount++;
                    } else {
                        failureCount++;
                        String errorMsg = 'Item "' + itemsToInsert[i].Name + '" failed: ';
                        for (Database.Error err : sr.getErrors()) {
                            errorMsg += err.getMessage() + '; ';
                        }
                        errors.add(errorMsg);
                    }
                }

                result.successCount = successCount;
                result.failureCount = failureCount;
            }

            // If there were any errors, add them to the result
            if (!errors.isEmpty()) {
                result.errors = errors;
                result.hasErrors = true;
            }

            result.success = !itemsToInsert.isEmpty() && result.failureCount == 0;
            result.message = generateResultMessage(result.successCount, result.failureCount);

        } catch (Exception e) {
            // Rollback on unexpected error
            Database.rollback(sp);
            result.success = false;
            result.hasErrors = true;
            result.message = 'Failed to create items: ' + e.getMessage();
            result.errors = new List<String>{ e.getMessage() };
        }

        return result;
    }

    /**
     * @description Validate menu items before creation
     * @param menuItems List of menu items to validate
     * @return List of validation errors (empty if no errors)
     */
    @AuraEnabled
    public static List<String> validateMenuItems(List<BanquetMenuParser.MenuItem> menuItems) {
        List<String> validationErrors = new List<String>();

        if (menuItems == null || menuItems.isEmpty()) {
            validationErrors.add('No items to validate');
            return validationErrors;
        }

        // Check for duplicate names
        Set<String> itemNames = new Set<String>();
        for (BanquetMenuParser.MenuItem item : menuItems) {
            // Check required field
            if (String.isBlank(item.Name)) {
                validationErrors.add('Item name is required');
                continue;
            }

            // Check for duplicates
            if (itemNames.contains(item.Name.toLowerCase())) {
                validationErrors.add('Duplicate item name: ' + item.Name);
            }
            itemNames.add(item.Name.toLowerCase());

            // Validate price
            if (item.UnitPrice != null && item.UnitPrice < 0) {
                validationErrors.add('Item "' + item.Name + '" has negative price');
            }

            // Validate ItemType
            if (String.isNotBlank(item.ItemType)) {
                if (!new Set<String>{'Item', 'Detailed Menu', 'Simple Menu', 'Text'}.contains(item.ItemType)) {
                    validationErrors.add('Invalid ItemType for "' + item.Name + '": ' + item.ItemType);
                }
            }
        }

        return validationErrors;
    }

    /**
     * @description Get existing Item categories for dropdown options
     * @return List of category names
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getItemCategories() {
        List<String> categories = new List<String>();

        // Get categories from SetupValue__c
        try {
            for (SetupValue__c sv : [
                SELECT Name
                FROM SetupValue__c
                WHERE SetupValueType__c = 'ItemCategory'
                    AND IsActive__c = true
                ORDER BY Name
            ]) {
                categories.add(sv.Name);
            }
        } catch (Exception e) {
            System.debug('Error fetching categories: ' + e.getMessage());
        }

        // Add default categories if none exist
        if (categories.isEmpty()) {
            categories.addAll(new List<String>{
                'Appetizers',
                'Beverages',
                'Desserts',
                'Entrees',
                'Equipment',
                'Reception Packages',
                'Service Fees',
                'Add-On Stations'
            });
        }

        return categories;
    }

    /**
     * @description Get revenue classifications for dropdown
     * @return List of revenue classification names
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getRevenueClassifications() {
        List<String> classifications = new List<String>();

        try {
            for (RevenueClassification__c rc : [
                SELECT Name
                FROM RevenueClassification__c
                WHERE IsActive__c = true
                    AND IsRootClassification__c = false
                ORDER BY Name
            ]) {
                classifications.add(rc.Name);
            }
        } catch (Exception e) {
            System.debug('Error fetching revenue classifications: ' + e.getMessage());
        }

        // Add defaults if none exist
        if (classifications.isEmpty()) {
            classifications.addAll(new List<String>{
                'Food',
                'Beverage',
                'Labor',
                'Equipment',
                'Other'
            });
        }

        return classifications;
    }

    /**
     * @description Generate result message based on success/failure counts
     * @param successCount Number of successfully created items
     * @param failureCount Number of failed items
     * @return User-friendly message
     */
    private static String generateResultMessage(Integer successCount, Integer failureCount) {
        if (successCount > 0 && failureCount == 0) {
            return 'Successfully created ' + successCount + ' item' + (successCount > 1 ? 's' : '');
        } else if (successCount > 0 && failureCount > 0) {
            return 'Created ' + successCount + ' item' + (successCount > 1 ? 's' : '') +
                   ', ' + failureCount + ' failed';
        } else if (failureCount > 0) {
            return 'Failed to create ' + failureCount + ' item' + (failureCount > 1 ? 's' : '');
        } else {
            return 'No items were created';
        }
    }

    /**
     * @description Result wrapper class for item creation
     */
    public class ItemCreationResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public List<Id> createdItemIds;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer failureCount;
        @AuraEnabled public Boolean hasErrors;
        @AuraEnabled public List<String> errors;

        public ItemCreationResult() {
            this.success = false;
            this.createdItemIds = new List<Id>();
            this.errors = new List<String>();
            this.successCount = 0;
            this.failureCount = 0;
            this.hasErrors = false;
        }
    }
}
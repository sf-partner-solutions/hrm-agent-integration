/**
 * @description Controller for managing Event Items on Booking Events
 * Handles retrieving catalogue items and creating EventItem__c records
 */
public with sharing class EventItemsController {

    /**
     * @description Get all EventItem__c records for a specific BookingEvent__c
     * @param bookingEventId The ID of the BookingEvent__c record
     * @return List of EventItem__c records with key fields
     */
    @AuraEnabled(cacheable=true)
    public static List<EventItem__c> getEventItems(Id bookingEventId) {
        return [
            SELECT Id, Name, ItemType__c, QuantityCalculation__c,
                   BookedQuantity__c, ActualQuantity__c, UnitPrice__c,
                   InclusiveUnitPrice__c, SoldByUnit__c, Description__c,
                   ServiceStartDate__c, ServiceStartDateTime__c,
                   ServiceEndDate__c, ServiceEndDateTime__c,
                   DoNotPrintOnBeo__c, DoNotPrintOnCheck__c,
                   HidePriceOnBeo__c, HideQuantityOnBeo__c,
                   Booking__c, Event__c
            FROM EventItem__c
            WHERE Event__c = :bookingEventId
            ORDER BY Name ASC
        ];
    }

    /**
     * @description Get BookingEvent__c details including property info
     * @param bookingEventId The ID of the BookingEvent__c record
     * @return BookingEvent__c record with property and booking details
     */
    @AuraEnabled(cacheable=true)
    public static BookingEvent__c getBookingEventDetails(Id bookingEventId) {
        return [
            SELECT Id, Name, Property__c, Booking__c,
                   Booking__r.Name, Booking__r.Property__c,
                   StartDateTime__c, EndDateTime__c
            FROM BookingEvent__c
            WHERE Id = :bookingEventId
            LIMIT 1
        ];
    }

    /**
     * @description Get available catalogue items from the property
     * @param propertyName The property name (picklist value) to filter items
     * @return List of Item__c records available for selection
     */
    @AuraEnabled(cacheable=true)
    public static List<Item__c> getCatalogueItems(String propertyName) {
        // First try to find items by Location name matching the property
        List<Item__c> items = [
            SELECT Id, Name, ItemType__c, QuantityCalculation__c,
                   UnitPrice__c, IsInclusive__c, SoldByUnit__c,
                   ServingUnit__c, Description__c, RichDescription__c,
                   RevenueClassification__c, ItemCategory__c,
                   AdminCharge__c, Gratuity__c, IsActive__c,
                   DoNotPrintOnBeo__c, DoNotPrintOnCheck__c,
                   HidePriceOnBeo__c, HideQuantityOnBeo__c, HideServeTimesOnBeo__c,
                   Property__c, Location__c, Location__r.Name
            FROM Item__c
            WHERE IsActive__c = true
                AND (Location__r.Name = :propertyName
                     OR Property__c = :propertyName)
            ORDER BY ItemType__c, Name ASC
            LIMIT 500
        ];

        // If no items found for the property, return corporate items
        if (items.isEmpty()) {
            items = [
                SELECT Id, Name, ItemType__c, QuantityCalculation__c,
                       UnitPrice__c, IsInclusive__c, SoldByUnit__c,
                       ServingUnit__c, Description__c, RichDescription__c,
                       RevenueClassification__c, ItemCategory__c,
                       AdminCharge__c, Gratuity__c, IsActive__c,
                       DoNotPrintOnBeo__c, DoNotPrintOnCheck__c,
                       HidePriceOnBeo__c, HideQuantityOnBeo__c, HideServeTimesOnBeo__c,
                       Property__c, Location__c, Location__r.Name
                FROM Item__c
                WHERE IsActive__c = true
                    AND Location__c = null
                ORDER BY ItemType__c, Name ASC
                LIMIT 500
            ];
        }

        return items;
    }

    /**
     * @description Create EventItem__c records from selected catalogue items
     * @param bookingEventId The BookingEvent__c to link items to
     * @param bookingId The Booking__c to link items to
     * @param selectedItemIds List of Item__c IDs to create as event items
     * @return Result object with success status and created records
     */
    @AuraEnabled
    public static EventItemCreationResult createEventItems(
        Id bookingEventId,
        Id bookingId,
        List<Id> selectedItemIds
    ) {
        EventItemCreationResult result = new EventItemCreationResult();
        List<EventItem__c> eventItemsToInsert = new List<EventItem__c>();
        List<String> errors = new List<String>();

        Savepoint sp = Database.setSavepoint();

        try {
            // Get the selected catalogue items
            Map<Id, Item__c> catalogueItems = new Map<Id, Item__c>([
                SELECT Id, Name, ItemType__c, QuantityCalculation__c,
                       UnitPrice__c, IsInclusive__c, SoldByUnit__c,
                       ServingUnit__c, Description__c, RichDescription__c,
                       RevenueClassification__c, AdminCharge__c, Gratuity__c,
                       DoNotPrintOnBeo__c, DoNotPrintOnCheck__c,
                       HidePriceOnBeo__c, HideQuantityOnBeo__c, HideServeTimesOnBeo__c,
                       AdminIsIncludedInInclusivePrice__c, GratuityIsIncludedInInclusivePrice__c,
                       AllowDecimalQuantities__c, EstimatedConsumptionPercentage__c
                FROM Item__c
                WHERE Id IN :selectedItemIds
            ]);

            // Get the BookingEvent to inherit dates
            BookingEvent__c bookingEvent = [
                SELECT Id, StartDateTime__c, EndDateTime__c,
                       StartDate__c, EndDate__c
                FROM BookingEvent__c
                WHERE Id = :bookingEventId
                LIMIT 1
            ];

            // Create EventItem__c records
            for (Id itemId : selectedItemIds) {
                Item__c catalogueItem = catalogueItems.get(itemId);
                if (catalogueItem == null) {
                    errors.add('Item not found: ' + itemId);
                    continue;
                }

                EventItem__c eventItem = new EventItem__c();
                eventItem.Name = catalogueItem.Name;
                eventItem.Event__c = bookingEventId;
                eventItem.Booking__c = bookingId;

                // Copy fields from catalogue item
                eventItem.ItemType__c = catalogueItem.ItemType__c;
                eventItem.QuantityCalculation__c = catalogueItem.QuantityCalculation__c;
                eventItem.UnitPrice__c = catalogueItem.UnitPrice__c;
                eventItem.SoldByUnit__c = catalogueItem.SoldByUnit__c;
                eventItem.Description__c = catalogueItem.Description__c;
                eventItem.RichDescription__c = catalogueItem.RichDescription__c;
                eventItem.AdminCharge__c = catalogueItem.AdminCharge__c;
                eventItem.Gratuity__c = catalogueItem.Gratuity__c;
                eventItem.DoNotPrintOnBeo__c = catalogueItem.DoNotPrintOnBeo__c;
                eventItem.DoNotPrintOnCheck__c = catalogueItem.DoNotPrintOnCheck__c;
                eventItem.HidePriceOnBeo__c = catalogueItem.HidePriceOnBeo__c;
                eventItem.HideQuantityOnBeo__c = catalogueItem.HideQuantityOnBeo__c;
                eventItem.HideServeTimesOnBeo__c = catalogueItem.HideServeTimesOnBeo__c;
                eventItem.AdminIsIncludedInInclusivePrice__c = catalogueItem.AdminIsIncludedInInclusivePrice__c;
                eventItem.GratuityIsIncludedInInclusivePrice__c = catalogueItem.GratuityIsIncludedInInclusivePrice__c;
                eventItem.AllowDecimalQuantities__c = catalogueItem.AllowDecimalQuantities__c;
                eventItem.EstimatedConsumptionPercentage__c = catalogueItem.EstimatedConsumptionPercentage__c;

                // Set inclusive price if item is marked as inclusive
                if (catalogueItem.IsInclusive__c == true) {
                    eventItem.InclusiveUnitPrice__c = catalogueItem.UnitPrice__c;
                }

                // Set default quantities
                eventItem.BookedQuantity__c = 1;

                // Set service dates/times from event
                eventItem.ServiceStartDate__c = bookingEvent.StartDate__c;
                eventItem.ServiceEndDate__c = bookingEvent.EndDate__c;
                eventItem.ServiceStartDateTime__c = bookingEvent.StartDateTime__c;
                eventItem.ServiceEndDateTime__c = bookingEvent.EndDateTime__c;

                eventItemsToInsert.add(eventItem);
            }

            // Insert event items
            if (!eventItemsToInsert.isEmpty()) {
                Database.SaveResult[] saveResults = Database.insert(eventItemsToInsert, false);

                Integer successCount = 0;
                Integer failureCount = 0;

                for (Integer i = 0; i < saveResults.size(); i++) {
                    Database.SaveResult sr = saveResults[i];
                    if (sr.isSuccess()) {
                        result.createdItemIds.add(sr.getId());
                        successCount++;
                    } else {
                        failureCount++;
                        String errorMsg = 'Item "' + eventItemsToInsert[i].Name + '" failed: ';
                        for (Database.Error err : sr.getErrors()) {
                            errorMsg += err.getMessage() + '; ';
                        }
                        errors.add(errorMsg);
                    }
                }

                result.successCount = successCount;
                result.failureCount = failureCount;
            }

            if (!errors.isEmpty()) {
                result.errors = errors;
                result.hasErrors = true;
            }

            result.success = !eventItemsToInsert.isEmpty() && result.failureCount == 0;
            result.message = generateResultMessage(result.successCount, result.failureCount);

        } catch (Exception e) {
            Database.rollback(sp);
            result.success = false;
            result.hasErrors = true;
            result.message = 'Failed to create event items: ' + e.getMessage();
            result.errors = new List<String>{ e.getMessage() };
        }

        return result;
    }

    /**
     * @description Delete EventItem__c records
     * @param eventItemIds List of EventItem__c IDs to delete
     * @return Result object with success status
     */
    @AuraEnabled
    public static EventItemCreationResult deleteEventItems(List<Id> eventItemIds) {
        EventItemCreationResult result = new EventItemCreationResult();

        try {
            List<EventItem__c> itemsToDelete = [
                SELECT Id, Name
                FROM EventItem__c
                WHERE Id IN :eventItemIds
            ];

            if (!itemsToDelete.isEmpty()) {
                Database.DeleteResult[] deleteResults = Database.delete(itemsToDelete, false);

                Integer successCount = 0;
                Integer failureCount = 0;
                List<String> errors = new List<String>();

                for (Integer i = 0; i < deleteResults.size(); i++) {
                    if (deleteResults[i].isSuccess()) {
                        successCount++;
                    } else {
                        failureCount++;
                        for (Database.Error err : deleteResults[i].getErrors()) {
                            errors.add('Failed to delete "' + itemsToDelete[i].Name + '": ' + err.getMessage());
                        }
                    }
                }

                result.successCount = successCount;
                result.failureCount = failureCount;
                result.success = failureCount == 0;
                result.message = successCount + ' item(s) deleted successfully';

                if (!errors.isEmpty()) {
                    result.errors = errors;
                    result.hasErrors = true;
                }
            }
        } catch (Exception e) {
            result.success = false;
            result.hasErrors = true;
            result.message = 'Failed to delete items: ' + e.getMessage();
            result.errors = new List<String>{ e.getMessage() };
        }

        return result;
    }

    /**
     * @description Update EventItem__c records
     * @param eventItemsJson JSON string of event items to update
     * @return Result object with success status
     */
    @AuraEnabled
    public static EventItemCreationResult updateEventItems(String eventItemsJson) {
        EventItemCreationResult result = new EventItemCreationResult();

        try {
            List<Map<String, Object>> itemUpdates = (List<Map<String, Object>>)
                JSON.deserializeUntyped(eventItemsJson);

            List<EventItem__c> itemsToUpdate = new List<EventItem__c>();

            for (Map<String, Object> itemData : itemUpdates) {
                EventItem__c item = new EventItem__c();
                item.Id = (Id) itemData.get('Id');

                if (itemData.containsKey('BookedQuantity__c')) {
                    item.BookedQuantity__c = (Decimal) itemData.get('BookedQuantity__c');
                }
                if (itemData.containsKey('ActualQuantity__c')) {
                    item.ActualQuantity__c = (Decimal) itemData.get('ActualQuantity__c');
                }
                if (itemData.containsKey('UnitPrice__c')) {
                    item.UnitPrice__c = (Decimal) itemData.get('UnitPrice__c');
                }

                itemsToUpdate.add(item);
            }

            if (!itemsToUpdate.isEmpty()) {
                Database.SaveResult[] saveResults = Database.update(itemsToUpdate, false);

                Integer successCount = 0;
                Integer failureCount = 0;
                List<String> errors = new List<String>();

                for (Integer i = 0; i < saveResults.size(); i++) {
                    if (saveResults[i].isSuccess()) {
                        successCount++;
                    } else {
                        failureCount++;
                        for (Database.Error err : saveResults[i].getErrors()) {
                            errors.add(err.getMessage());
                        }
                    }
                }

                result.successCount = successCount;
                result.failureCount = failureCount;
                result.success = failureCount == 0;
                result.message = successCount + ' item(s) updated successfully';

                if (!errors.isEmpty()) {
                    result.errors = errors;
                    result.hasErrors = true;
                }
            }
        } catch (Exception e) {
            result.success = false;
            result.hasErrors = true;
            result.message = 'Failed to update items: ' + e.getMessage();
            result.errors = new List<String>{ e.getMessage() };
        }

        return result;
    }

    /**
     * @description Generate result message
     */
    private static String generateResultMessage(Integer successCount, Integer failureCount) {
        if (successCount > 0 && failureCount == 0) {
            return 'Successfully added ' + successCount + ' item' + (successCount > 1 ? 's' : '');
        } else if (successCount > 0 && failureCount > 0) {
            return 'Added ' + successCount + ' item' + (successCount > 1 ? 's' : '') +
                   ', ' + failureCount + ' failed';
        } else if (failureCount > 0) {
            return 'Failed to add ' + failureCount + ' item' + (failureCount > 1 ? 's' : '');
        } else {
            return 'No items were added';
        }
    }

    /**
     * @description Result wrapper class
     */
    public class EventItemCreationResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public List<Id> createdItemIds;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer failureCount;
        @AuraEnabled public Boolean hasErrors;
        @AuraEnabled public List<String> errors;

        public EventItemCreationResult() {
            this.success = false;
            this.createdItemIds = new List<Id>();
            this.errors = new List<String>();
            this.successCount = 0;
            this.failureCount = 0;
            this.hasErrors = false;
        }
    }
}

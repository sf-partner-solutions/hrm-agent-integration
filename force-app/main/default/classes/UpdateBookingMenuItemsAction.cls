/**
 * @description Invocable Apex class for updating menu items across multiple bookings
 * Allows Agentforce agents to update EventItem__c records (price, name, quantity, etc.)
 */
global with sharing class UpdateBookingMenuItemsAction {

    /**
     * @description Input wrapper for the invocable method
     */
    global class UpdateMenuItemsInput {
        @InvocableVariable(label='Event Item IDs' description='Comma-separated list of EventItem IDs to update (from Find Bookings action)' required=false)
        public String eventItemIds;

        @InvocableVariable(label='Property ID' description='Property ID to search within if not using specific IDs' required=false)
        public String propertyId;

        @InvocableVariable(label='Item Name to Find' description='Search for items with this name to update (supports partial matching)' required=false)
        public String itemNameToFind;

        @InvocableVariable(label='New Price' description='New unit price to set for the matching items (e.g., 13.00)' required=false)
        public Decimal newPrice;

        @InvocableVariable(label='New Name' description='New name to set for the matching items' required=false)
        public String newName;

        @InvocableVariable(label='New Booked Quantity' description='New booked quantity to set for the matching items' required=false)
        public Decimal newBookedQuantity;

        @InvocableVariable(label='New Description' description='New description to set for the matching items' required=false)
        public String newDescription;

        @InvocableVariable(label='Booking IDs' description='Comma-separated list of Booking IDs to limit the update scope' required=false)
        public String bookingIds;
    }

    /**
     * @description Output wrapper for the invocable method
     */
    global class UpdateMenuItemsOutput {
        @InvocableVariable(label='Success' description='Whether the update was successful')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-friendly message describing the results')
        public String message;

        @InvocableVariable(label='Items Updated' description='Number of menu items successfully updated')
        public Integer itemsUpdated;

        @InvocableVariable(label='Bookings Affected' description='Number of bookings affected by the update')
        public Integer bookingsAffected;

        @InvocableVariable(label='Update Summary' description='Detailed summary of what was updated')
        public String updateSummary;

        @InvocableVariable(label='Errors' description='Any errors that occurred during the update')
        public String errors;

        @InvocableVariable(label='Updated Item IDs' description='Comma-separated list of successfully updated EventItem IDs')
        public String updatedItemIds;
    }

    /**
     * @description Main invocable method for Agent Action - Update Booking Menu Items
     * @param inputs List of update requests
     * @return List of update results
     */
    @InvocableMethod(
        label='Update Booking Menu Items'
        description='Updates menu items (EventItem__c) across multiple bookings with new values such as price, name, or quantity. Can update specific items by ID or search by name.'
        category='Delphi Booking Management'
    )
    global static List<UpdateMenuItemsOutput> updateMenuItems(List<UpdateMenuItemsInput> inputs) {
        List<UpdateMenuItemsOutput> outputs = new List<UpdateMenuItemsOutput>();

        for (UpdateMenuItemsInput input : inputs) {
            UpdateMenuItemsOutput output = new UpdateMenuItemsOutput();

            try {
                // Validate that we have something to update
                if (input.newPrice == null && String.isBlank(input.newName) &&
                    input.newBookedQuantity == null && String.isBlank(input.newDescription)) {
                    output.success = false;
                    output.message = 'Please specify at least one field to update (price, name, quantity, or description).';
                    outputs.add(output);
                    continue;
                }

                // Get the EventItem__c records to update
                List<EventItem__c> itemsToUpdate = new List<EventItem__c>();

                if (String.isNotBlank(input.eventItemIds)) {
                    // Use specific IDs provided
                    List<String> idList = input.eventItemIds.split(',');
                    Set<Id> eventItemIdSet = new Set<Id>();
                    for (String idStr : idList) {
                        try {
                            eventItemIdSet.add(Id.valueOf(idStr.trim()));
                        } catch (Exception e) {
                            // Skip invalid IDs
                            System.debug('Invalid ID skipped: ' + idStr);
                        }
                    }

                    if (!eventItemIdSet.isEmpty()) {
                        itemsToUpdate = [
                            SELECT Id, Name, UnitPrice__c, BookedQuantity__c, Description__c,
                                   Booking__c, Booking__r.Name, Event__c, Event__r.Name
                            FROM EventItem__c
                            WHERE Id IN :eventItemIdSet
                        ];
                    }
                } else if (String.isNotBlank(input.itemNameToFind)) {
                    // Search by name
                    String searchPattern = '%' + input.itemNameToFind + '%';

                    // Build query based on available filters
                    String query = 'SELECT Id, Name, UnitPrice__c, BookedQuantity__c, Description__c, ' +
                                  'Booking__c, Booking__r.Name, Booking__r.Property__c, Event__c, Event__r.Name ' +
                                  'FROM EventItem__c WHERE Name LIKE :searchPattern';

                    // Add property filter if provided
                    String propertyName = null;
                    if (String.isNotBlank(input.propertyId)) {
                        propertyName = getPropertyName(input.propertyId);
                        if (propertyName != null) {
                            query += ' AND Booking__r.Property__c = :propertyName';
                        }
                    }

                    // Add booking IDs filter if provided
                    Set<Id> bookingIdSet = new Set<Id>();
                    if (String.isNotBlank(input.bookingIds)) {
                        for (String idStr : input.bookingIds.split(',')) {
                            try {
                                bookingIdSet.add(Id.valueOf(idStr.trim()));
                            } catch (Exception e) {
                                // Skip invalid IDs
                            }
                        }
                        if (!bookingIdSet.isEmpty()) {
                            query += ' AND Booking__c IN :bookingIdSet';
                        }
                    }

                    query += ' LIMIT 500';
                    itemsToUpdate = Database.query(query);
                } else {
                    output.success = false;
                    output.message = 'Please provide either Event Item IDs to update, or an item name to search for.';
                    outputs.add(output);
                    continue;
                }

                if (itemsToUpdate.isEmpty()) {
                    output.success = true;
                    output.message = 'No menu items found matching your criteria to update.';
                    output.itemsUpdated = 0;
                    output.bookingsAffected = 0;
                    outputs.add(output);
                    continue;
                }

                // Track what we're updating for the summary
                List<String> updateDetails = new List<String>();
                Set<Id> affectedBookingIds = new Set<Id>();
                Decimal oldPrice = null;
                String oldName = null;

                // Capture original values from first item for summary
                if (!itemsToUpdate.isEmpty()) {
                    oldPrice = itemsToUpdate[0].UnitPrice__c;
                    oldName = itemsToUpdate[0].Name;
                }

                // Apply updates
                for (EventItem__c item : itemsToUpdate) {
                    if (input.newPrice != null) {
                        item.UnitPrice__c = input.newPrice;
                    }
                    if (String.isNotBlank(input.newName)) {
                        item.Name = input.newName;
                    }
                    if (input.newBookedQuantity != null) {
                        item.BookedQuantity__c = input.newBookedQuantity;
                    }
                    if (String.isNotBlank(input.newDescription)) {
                        item.Description__c = input.newDescription;
                    }

                    if (item.Booking__c != null) {
                        affectedBookingIds.add(item.Booking__c);
                    }
                }

                // Build update details for summary
                if (input.newPrice != null) {
                    String priceChange = 'Price: ';
                    if (oldPrice != null) {
                        priceChange += '$' + oldPrice.setScale(2) + ' -> ';
                    }
                    priceChange += '$' + input.newPrice.setScale(2);
                    updateDetails.add(priceChange);
                }
                if (String.isNotBlank(input.newName)) {
                    String nameChange = 'Name: ';
                    if (String.isNotBlank(oldName)) {
                        nameChange += '"' + oldName + '" -> ';
                    }
                    nameChange += '"' + input.newName + '"';
                    updateDetails.add(nameChange);
                }
                if (input.newBookedQuantity != null) {
                    updateDetails.add('Booked Quantity: ' + input.newBookedQuantity.intValue());
                }
                if (String.isNotBlank(input.newDescription)) {
                    updateDetails.add('Description updated');
                }

                // Perform the update with partial success handling
                Database.SaveResult[] saveResults = Database.update(itemsToUpdate, false);

                // Process results
                Integer successCount = 0;
                Integer failureCount = 0;
                List<String> errorMessages = new List<String>();
                List<String> updatedIds = new List<String>();

                for (Integer i = 0; i < saveResults.size(); i++) {
                    Database.SaveResult sr = saveResults[i];
                    if (sr.isSuccess()) {
                        successCount++;
                        updatedIds.add(sr.getId());
                    } else {
                        failureCount++;
                        for (Database.Error err : sr.getErrors()) {
                            errorMessages.add('Item "' + itemsToUpdate[i].Name + '": ' + err.getMessage());
                        }
                    }
                }

                // Build output
                output.itemsUpdated = successCount;
                output.bookingsAffected = affectedBookingIds.size();
                output.updatedItemIds = String.join(updatedIds, ',');

                // Build summary
                List<String> summaryLines = new List<String>();
                summaryLines.add('**Updates Applied:**');
                summaryLines.addAll(updateDetails);
                summaryLines.add('');
                summaryLines.add('**Scope:**');
                summaryLines.add('- ' + successCount + ' menu item(s) updated');
                summaryLines.add('- ' + affectedBookingIds.size() + ' booking(s) affected');

                output.updateSummary = String.join(summaryLines, '\n');

                if (failureCount > 0) {
                    output.errors = String.join(errorMessages, '\n');
                    output.success = successCount > 0;
                    output.message = 'Partially completed: Updated ' + successCount + ' item(s), ' +
                                    failureCount + ' failed.\n\n' + output.updateSummary;
                } else {
                    output.success = true;
                    String itemSearchDesc = String.isNotBlank(input.itemNameToFind) ?
                        '"' + input.itemNameToFind + '"' : 'the specified';
                    output.message = 'Successfully updated ' + successCount + ' ' + itemSearchDesc +
                                    ' menu item(s) across ' + affectedBookingIds.size() + ' booking(s).\n\n' +
                                    output.updateSummary;
                }

            } catch (Exception e) {
                output.success = false;
                output.message = 'An error occurred while updating menu items: ' + e.getMessage();
                output.errors = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Error in updateMenuItems: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }

            outputs.add(output);
        }

        return outputs;
    }

    /**
     * @description Gets the property name from a Location__c ID
     */
    private static String getPropertyName(String propertyId) {
        try {
            List<Location__c> locations = [
                SELECT Name
                FROM Location__c
                WHERE Id = :propertyId
                LIMIT 1
            ];

            if (!locations.isEmpty()) {
                return locations[0].Name;
            }
        } catch (Exception e) {
            System.debug('Error getting property name: ' + e.getMessage());
        }
        return null;
    }

    /**
     * @description AuraEnabled method for LWC to update EventItem prices
     * @param updates List of maps containing eventItemId and newPrice
     * @return Map with success status, message, and counts
     */
    @AuraEnabled
    public static Map<String, Object> updateEventItemPrices(List<Map<String, Object>> updates) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            if (updates == null || updates.isEmpty()) {
                result.put('success', false);
                result.put('message', 'No updates provided');
                result.put('itemsUpdated', 0);
                result.put('bookingsAffected', 0);
                return result;
            }

            // Collect IDs and build update map
            Map<Id, Decimal> priceUpdates = new Map<Id, Decimal>();
            for (Map<String, Object> updateMap : updates) {
                String eventItemId = (String) updateMap.get('eventItemId');
                Object priceObj = updateMap.get('newPrice');
                Decimal newPrice = null;

                if (priceObj instanceof Decimal) {
                    newPrice = (Decimal) priceObj;
                } else if (priceObj instanceof Double) {
                    newPrice = Decimal.valueOf((Double) priceObj);
                } else if (priceObj instanceof Integer) {
                    newPrice = Decimal.valueOf((Integer) priceObj);
                } else if (priceObj instanceof String) {
                    newPrice = Decimal.valueOf((String) priceObj);
                }

                if (String.isNotBlank(eventItemId) && newPrice != null) {
                    priceUpdates.put(Id.valueOf(eventItemId), newPrice);
                }
            }

            if (priceUpdates.isEmpty()) {
                result.put('success', false);
                result.put('message', 'No valid price updates found');
                result.put('itemsUpdated', 0);
                result.put('bookingsAffected', 0);
                return result;
            }

            // Query the EventItems
            List<EventItem__c> itemsToUpdate = [
                SELECT Id, Name, UnitPrice__c, Booking__c, Booking__r.Name
                FROM EventItem__c
                WHERE Id IN :priceUpdates.keySet()
            ];

            // Track affected bookings
            Set<Id> affectedBookingIds = new Set<Id>();

            // Apply price updates
            for (EventItem__c item : itemsToUpdate) {
                Decimal newPrice = priceUpdates.get(item.Id);
                if (newPrice != null) {
                    item.UnitPrice__c = newPrice;
                    if (item.Booking__c != null) {
                        affectedBookingIds.add(item.Booking__c);
                    }
                }
            }

            // Perform the update
            Database.SaveResult[] saveResults = Database.update(itemsToUpdate, false);

            // Count successes and failures
            Integer successCount = 0;
            Integer failureCount = 0;
            List<String> errorMessages = new List<String>();

            for (Integer i = 0; i < saveResults.size(); i++) {
                Database.SaveResult sr = saveResults[i];
                if (sr.isSuccess()) {
                    successCount++;
                } else {
                    failureCount++;
                    for (Database.Error err : sr.getErrors()) {
                        errorMessages.add('Item "' + itemsToUpdate[i].Name + '": ' + err.getMessage());
                    }
                }
            }

            // Build result
            result.put('success', successCount > 0);
            result.put('itemsUpdated', successCount);
            result.put('bookingsAffected', affectedBookingIds.size());

            if (failureCount > 0) {
                result.put('message', 'Updated ' + successCount + ' item(s), ' + failureCount + ' failed.');
                result.put('errors', errorMessages);
            } else {
                result.put('message', 'Successfully updated ' + successCount + ' menu item(s) across ' + affectedBookingIds.size() + ' booking(s).');
            }

        } catch (Exception e) {
            result.put('success', false);
            result.put('message', 'Error updating prices: ' + e.getMessage());
            result.put('itemsUpdated', 0);
            result.put('bookingsAffected', 0);
            System.debug(LoggingLevel.ERROR, 'Error in updateEventItemPrices: ' + e.getMessage());
        }

        return result;
    }
}

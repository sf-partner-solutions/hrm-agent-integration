/**
 * @description Invocable Apex class for finding bookings by menu item criteria
 * Allows Agentforce agents to search for bookings that contain specific menu items
 */
global with sharing class FindBookingsByMenuItemAction {

    /**
     * @description Input wrapper for the invocable method
     */
    global class FindBookingsInput {
        @InvocableVariable(label='Property ID' description='The ID of the property (Location__c) to search within' required=true)
        public String propertyId;

        @InvocableVariable(label='Item Name Search' description='The menu item name to search for (supports partial matching). Example: "Dry Snack" or "Coffee"' required=false)
        public String itemNameSearch;

        @InvocableVariable(label='Item Price' description='Search for items with this specific price (e.g., 10.00)' required=false)
        public Decimal itemPrice;

        @InvocableVariable(label='Search Type' description='Type of search: "name", "price", or "both". Defaults to "name" if not specified.' required=false)
        public String searchType;

        @InvocableVariable(label='Date Range Start' description='Start date to filter bookings (format: YYYY-MM-DD). Defaults to today if not specified.' required=false)
        public Date dateRangeStart;

        @InvocableVariable(label='Date Range End' description='End date to filter bookings (format: YYYY-MM-DD). Defaults to 12 months from today if not specified.' required=false)
        public Date dateRangeEnd;
    }

    /**
     * @description Output wrapper for the invocable method
     */
    global class FindBookingsOutput {
        @InvocableVariable(label='Success' description='Whether the search was successful')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-friendly message describing the results')
        public String message;

        @InvocableVariable(label='Bookings Found' description='Number of bookings found matching the criteria')
        public Integer bookingsFound;

        @InvocableVariable(label='Menu Items Found' description='Number of menu items found matching the criteria')
        public Integer menuItemsFound;

        @InvocableVariable(label='Booking IDs' description='Comma-separated list of Booking IDs that match the criteria')
        public String bookingIds;

        @InvocableVariable(label='Event Item IDs' description='Comma-separated list of EventItem IDs that match the criteria')
        public String eventItemIds;

        @InvocableVariable(label='Results Summary' description='Formatted summary of found bookings with their menu items')
        public String resultsSummary;

        @InvocableVariable(label='Search Criteria Used' description='Description of the search criteria that was applied')
        public String searchCriteriaUsed;

        @InvocableVariable(label='Item Name Searched' description='The item name that was searched for')
        public String itemNameSearched;

        @InvocableVariable(label='Property ID' description='The property ID that was searched')
        public String propertyId;
    }

    /**
     * @description Main invocable method for Agent Action - Find Bookings by Menu Item
     * @param inputs List of search criteria inputs
     * @return List of search results
     */
    @InvocableMethod(
        label='Find Bookings by Menu Item'
        description='Searches for bookings that contain specific menu items based on name or price. Returns a list of matching bookings and their menu items.'
        category='Delphi Booking Management'
    )
    global static List<FindBookingsOutput> findBookings(List<FindBookingsInput> inputs) {
        List<FindBookingsOutput> outputs = new List<FindBookingsOutput>();

        for (FindBookingsInput input : inputs) {
            FindBookingsOutput output = new FindBookingsOutput();

            try {
                // Validate required input
                if (String.isBlank(input.propertyId)) {
                    output.success = false;
                    output.message = 'Property ID is required to search for bookings.';
                    outputs.add(output);
                    continue;
                }

                // Get the property name from the ID for filtering
                String propertyName = getPropertyName(input.propertyId);
                output.propertyId = input.propertyId;

                // Determine search type
                String effectiveSearchType = String.isNotBlank(input.searchType) ? input.searchType.toLowerCase() : 'name';

                // Always use today to 12 months from today for date range
                // Ignoring input.dateRangeStart and input.dateRangeEnd as agent may pass incorrect values
                Date effectiveDateStart = Date.today();
                Date effectiveDateEnd = Date.today().addMonths(12);

                // Build the search criteria description
                List<String> criteriaDescriptions = new List<String>();

                // Build dynamic SOQL query for EventItem__c
                String query = 'SELECT Id, Name, UnitPrice__c, BookedQuantity__c, ActualQuantity__c, ' +
                              'Event__c, Event__r.Name, Event__r.StartDateTime__c, Event__r.EndDateTime__c, ' +
                              'Booking__c, Booking__r.Name, Booking__r.Property__c ' +
                              'FROM EventItem__c WHERE ';

                List<String> conditions = new List<String>();
                Map<String, Object> bindVars = new Map<String, Object>();

                // Property filter via Booking relationship - Property__c stores the name as text, not an ID
                if (String.isNotBlank(propertyName)) {
                    conditions.add('Booking__r.Property__c = :propertyName');
                    bindVars.put('propertyName', propertyName);
                    criteriaDescriptions.add('Property: ' + propertyName);
                }

                // Item name search (partial match)
                if (String.isNotBlank(input.itemNameSearch) && (effectiveSearchType == 'name' || effectiveSearchType == 'both')) {
                    String searchPattern = '%' + input.itemNameSearch + '%';
                    conditions.add('Name LIKE :searchPattern');
                    bindVars.put('searchPattern', searchPattern);
                    criteriaDescriptions.add('Item name contains: "' + input.itemNameSearch + '"');
                    output.itemNameSearched = input.itemNameSearch;
                }

                // Price search
                if (input.itemPrice != null && (effectiveSearchType == 'price' || effectiveSearchType == 'both')) {
                    conditions.add('UnitPrice__c = :itemPrice');
                    bindVars.put('itemPrice', input.itemPrice);
                    criteriaDescriptions.add('Price: $' + input.itemPrice);
                }

                // Date range filter - always applied (defaults to today + 12 months if not specified)
                // Handle null StartDateTime by using EndDateTime as fallback
                // Include events where StartDateTime >= dateStart, OR where StartDateTime is null but EndDateTime >= dateStart
                conditions.add('(Event__r.StartDateTime__c >= :dateStart OR (Event__r.StartDateTime__c = null AND Event__r.EndDateTime__c >= :dateStart))');
                bindVars.put('dateStart', Datetime.newInstance(effectiveDateStart, Time.newInstance(0,0,0,0)));
                criteriaDescriptions.add('From: ' + effectiveDateStart.format());

                conditions.add('Event__r.EndDateTime__c <= :dateEnd');
                bindVars.put('dateEnd', Datetime.newInstance(effectiveDateEnd, Time.newInstance(23,59,59,0)));
                criteriaDescriptions.add('To: ' + effectiveDateEnd.format());

                // If no search criteria beyond property, return error
                if (String.isBlank(input.itemNameSearch) && input.itemPrice == null) {
                    output.success = false;
                    output.message = 'Please provide either an item name or price to search for.';
                    outputs.add(output);
                    continue;
                }

                query += String.join(conditions, ' AND ');
                query += ' ORDER BY Booking__r.Name, Event__r.StartDateTime__c LIMIT 500';

                output.searchCriteriaUsed = String.join(criteriaDescriptions, ', ');

                // Execute query with dynamic binding
                List<EventItem__c> eventItems = executeSearchQuery(query, bindVars);

                if (eventItems.isEmpty()) {
                    output.success = true;
                    output.message = 'No bookings found with menu items matching your criteria: ' + output.searchCriteriaUsed;
                    output.bookingsFound = 0;
                    output.menuItemsFound = 0;
                    outputs.add(output);
                    continue;
                }

                // Process results
                Set<Id> bookingIdSet = new Set<Id>();
                List<String> eventItemIdList = new List<String>();
                Map<Id, List<EventItem__c>> bookingToItems = new Map<Id, List<EventItem__c>>();

                for (EventItem__c item : eventItems) {
                    if (item.Booking__c != null) {
                        bookingIdSet.add(item.Booking__c);
                        eventItemIdList.add(item.Id);

                        if (!bookingToItems.containsKey(item.Booking__c)) {
                            bookingToItems.put(item.Booking__c, new List<EventItem__c>());
                        }
                        bookingToItems.get(item.Booking__c).add(item);
                    }
                }

                // Build results summary
                List<String> summaryLines = new List<String>();
                for (Id bookingId : bookingToItems.keySet()) {
                    List<EventItem__c> items = bookingToItems.get(bookingId);
                    EventItem__c firstItem = items[0];

                    String bookingName = firstItem.Booking__r != null ? firstItem.Booking__r.Name : 'Unknown Booking';
                    String eventName = firstItem.Event__r != null ? firstItem.Event__r.Name : 'Unknown Event';
                    Datetime eventDate = firstItem.Event__r != null ? firstItem.Event__r.StartDateTime__c : null;

                    String line = '- **' + bookingName + '** (' + eventName + ')';
                    if (eventDate != null) {
                        line += ' on ' + eventDate.format('MMM d, yyyy');
                    }
                    line += ': ';

                    List<String> itemDetails = new List<String>();
                    for (EventItem__c item : items) {
                        String detail = item.Name;
                        if (item.UnitPrice__c != null) {
                            detail += ' ($' + item.UnitPrice__c.setScale(2) + ')';
                        }
                        if (item.BookedQuantity__c != null) {
                            detail += ' x' + item.BookedQuantity__c.intValue();
                        }
                        itemDetails.add(detail);
                    }
                    line += String.join(itemDetails, ', ');
                    summaryLines.add(line);
                }

                // Populate output
                output.success = true;
                output.bookingsFound = bookingIdSet.size();
                output.menuItemsFound = eventItems.size();
                output.bookingIds = String.join(new List<Id>(bookingIdSet), ',');
                output.eventItemIds = String.join(eventItemIdList, ',');
                output.resultsSummary = String.join(summaryLines, '\n');

                // Build user-friendly message
                String itemDescription = String.isNotBlank(input.itemNameSearch) ? '"' + input.itemNameSearch + '"' : 'matching items';
                output.message = 'Found ' + output.bookingsFound + ' booking(s) with ' + output.menuItemsFound +
                                ' ' + itemDescription + ' menu item(s).\n\n' + output.resultsSummary +
                                '\n\nWould you like to update any values on these menu items (such as price or name)?';

            } catch (Exception e) {
                output.success = false;
                output.message = 'An error occurred while searching for bookings: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Error in findBookings: ' + e.getMessage());
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
     * @description Executes the search query with dynamic binding
     * This method uses Database.query with bind variables
     */
    private static List<EventItem__c> executeSearchQuery(String queryTemplate, Map<String, Object> bindVars) {
        // Since we can't use dynamic bind variables directly,
        // we need to use actual variable binding
        // NOTE: Property__c on Booking stores the property NAME as text, not a lookup ID
        String propertyName = (String) bindVars.get('propertyName');
        String searchPattern = (String) bindVars.get('searchPattern');
        Decimal itemPrice = (Decimal) bindVars.get('itemPrice');
        Datetime dateStart = (Datetime) bindVars.get('dateStart');
        Datetime dateEnd = (Datetime) bindVars.get('dateEnd');

        // DEBUG: Log all bind variables
        System.debug('=== DEBUG: executeSearchQuery ===');
        System.debug('DEBUG: propertyName = ' + propertyName);
        System.debug('DEBUG: searchPattern = ' + searchPattern);
        System.debug('DEBUG: itemPrice = ' + itemPrice);
        System.debug('DEBUG: dateStart = ' + dateStart);
        System.debug('DEBUG: dateEnd = ' + dateEnd);

        // DEBUG: Run diagnostic queries to isolate the issue
        runDiagnosticQueries(propertyName, searchPattern, dateStart, dateEnd);

        // Build conditions list dynamically
        List<String> conditions = new List<String>();

        if (propertyName != null) {
            conditions.add('Booking__r.Property__c = :propertyName');
        }
        if (searchPattern != null) {
            conditions.add('Name LIKE :searchPattern');
        }
        if (itemPrice != null) {
            conditions.add('UnitPrice__c = :itemPrice');
        }
        if (dateStart != null) {
            // Include events where StartDateTime >= dateStart, OR where StartDateTime is null but EndDateTime >= dateStart
            conditions.add('(Event__r.StartDateTime__c >= :dateStart OR (Event__r.StartDateTime__c = null AND Event__r.EndDateTime__c >= :dateStart))');
        }
        if (dateEnd != null) {
            conditions.add('Event__r.EndDateTime__c <= :dateEnd');
        }

        String query = 'SELECT Id, Name, UnitPrice__c, BookedQuantity__c, ActualQuantity__c, ' +
                      'Event__c, Event__r.Name, Event__r.StartDateTime__c, Event__r.EndDateTime__c, ' +
                      'Booking__c, Booking__r.Name, Booking__r.Property__c ' +
                      'FROM EventItem__c WHERE ' +
                      String.join(conditions, ' AND ') +
                      ' ORDER BY Booking__r.Name, Event__r.StartDateTime__c LIMIT 500';

        System.debug('DEBUG: Final query = ' + query);

        List<EventItem__c> results = Database.query(query);
        System.debug('DEBUG: Query returned ' + results.size() + ' results');

        return results;
    }

    /**
     * @description Runs diagnostic queries to isolate which condition is causing zero results
     */
    private static void runDiagnosticQueries(String propertyName, String searchPattern, Datetime dateStart, Datetime dateEnd) {
        System.debug('=== DEBUG: Running Diagnostic Queries ===');

        // 1. Check total EventItems in the system
        Integer totalEventItems = [SELECT COUNT() FROM EventItem__c];
        System.debug('DEBUG [1]: Total EventItem__c records in system: ' + totalEventItems);

        // 2. Check EventItems with matching name pattern (no other filters)
        if (searchPattern != null) {
            Integer matchingName = [SELECT COUNT() FROM EventItem__c WHERE Name LIKE :searchPattern];
            System.debug('DEBUG [2]: EventItems matching name pattern "' + searchPattern + '": ' + matchingName);

            // Show sample matching items
            List<EventItem__c> sampleNameMatches = [
                SELECT Id, Name, Booking__c, Booking__r.Name, Booking__r.Property__c, Event__c, Event__r.Name, Event__r.StartDateTime__c, Event__r.EndDateTime__c
                FROM EventItem__c
                WHERE Name LIKE :searchPattern
                LIMIT 5
            ];
            for (EventItem__c item : sampleNameMatches) {
                System.debug('DEBUG [2-sample]: Item "' + item.Name + '" | Booking: ' + item.Booking__r?.Name +
                           ' | Property__c: ' + item.Booking__r?.Property__c +
                           ' | Event: ' + item.Event__r?.Name +
                           ' | StartDateTime: ' + item.Event__r?.StartDateTime__c +
                           ' | EndDateTime: ' + item.Event__r?.EndDateTime__c);
            }
        }

        // 3. Check EventItems for this property NAME (Property__c is a text field, not a lookup)
        if (propertyName != null) {
            Integer matchingProperty = [SELECT COUNT() FROM EventItem__c WHERE Booking__r.Property__c = :propertyName];
            System.debug('DEBUG [3]: EventItems for property name "' + propertyName + '": ' + matchingProperty);

            // Also check what Property__c values look like
            List<EventItem__c> samplePropertyItems = [
                SELECT Id, Name, Booking__r.Property__c
                FROM EventItem__c
                WHERE Booking__c != null
                LIMIT 5
            ];
            for (EventItem__c item : samplePropertyItems) {
                System.debug('DEBUG [3-sample]: Item "' + item.Name + '" has Booking.Property__c = ' + item.Booking__r?.Property__c);
            }
        }

        // 4. Check EventItems matching name AND property
        if (searchPattern != null && propertyName != null) {
            Integer matchingNameAndProperty = [SELECT COUNT() FROM EventItem__c WHERE Name LIKE :searchPattern AND Booking__r.Property__c = :propertyName];
            System.debug('DEBUG [4]: EventItems matching name AND property: ' + matchingNameAndProperty);
        }

        // 5. Check EventItems matching name, property, AND date range
        if (searchPattern != null && propertyName != null && dateStart != null && dateEnd != null) {
            // Check with just start date
            Integer withStartDate = [SELECT COUNT() FROM EventItem__c WHERE Name LIKE :searchPattern AND Booking__r.Property__c = :propertyName AND Event__r.StartDateTime__c >= :dateStart];
            System.debug('DEBUG [5a]: + StartDateTime >= ' + dateStart + ': ' + withStartDate);

            // Check with just end date
            Integer withEndDate = [SELECT COUNT() FROM EventItem__c WHERE Name LIKE :searchPattern AND Booking__r.Property__c = :propertyName AND Event__r.EndDateTime__c <= :dateEnd];
            System.debug('DEBUG [5b]: + EndDateTime <= ' + dateEnd + ': ' + withEndDate);

            // Check with both dates
            Integer withBothDates = [SELECT COUNT() FROM EventItem__c WHERE Name LIKE :searchPattern AND Booking__r.Property__c = :propertyName AND Event__r.StartDateTime__c >= :dateStart AND Event__r.EndDateTime__c <= :dateEnd];
            System.debug('DEBUG [5c]: + Both date conditions: ' + withBothDates);
        }

        // 6. Show what date values actually exist for matching items
        if (searchPattern != null && propertyName != null) {
            List<EventItem__c> itemsWithDates = [
                SELECT Id, Name, Event__r.StartDateTime__c, Event__r.EndDateTime__c
                FROM EventItem__c
                WHERE Name LIKE :searchPattern AND Booking__r.Property__c = :propertyName
                LIMIT 5
            ];
            for (EventItem__c item : itemsWithDates) {
                System.debug('DEBUG [6]: Item "' + item.Name + '" | StartDateTime: ' + item.Event__r?.StartDateTime__c + ' | EndDateTime: ' + item.Event__r?.EndDateTime__c);
            }
        }

        System.debug('=== DEBUG: End Diagnostic Queries ===');
    }
}

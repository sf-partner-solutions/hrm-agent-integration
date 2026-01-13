/**
 * @description Lightning Type wrapper classes for Booking Menu Items agent action responses
 * Used as return types for Agentforce agent actions to display in LWC components
 */
global with sharing class BookingMenuItemsLightningTypes {

    /**
     * @description Wrapper for agent action response
     * This is the outer wrapper that Agentforce expects
     */
    global class BookingMenuItemsResponse {
        @InvocableVariable
        public BookingSearchOutput searchResults;
    }

    /**
     * @description Output wrapper containing the booking search results
     * Maps to the FindBookingsByMenuItemAction output fields
     */
    global class BookingSearchOutput {
        @AuraEnabled
        @InvocableVariable(label='Success' description='Whether the search was successful')
        public Boolean success;

        @AuraEnabled
        @InvocableVariable(label='Message' description='User-friendly message describing the results')
        public String message;

        @AuraEnabled
        @InvocableVariable(label='Bookings Found' description='Number of bookings found matching the criteria')
        public Integer bookingsFound;

        @AuraEnabled
        @InvocableVariable(label='Menu Items Found' description='Number of menu items found matching the criteria')
        public Integer menuItemsFound;

        @AuraEnabled
        @InvocableVariable(label='Booking IDs' description='Comma-separated list of Booking IDs that match the criteria')
        public String bookingIds;

        @AuraEnabled
        @InvocableVariable(label='Event Item IDs' description='Comma-separated list of EventItem IDs that match the criteria')
        public String eventItemIds;

        @AuraEnabled
        @InvocableVariable(label='Results Summary' description='Formatted summary of found bookings with their menu items')
        public String resultsSummary;

        @AuraEnabled
        @InvocableVariable(label='Search Criteria Used' description='Description of the search criteria that was applied')
        public String searchCriteriaUsed;

        @AuraEnabled
        @InvocableVariable(label='Item Name Searched' description='The item name that was searched for')
        public String itemNameSearched;

        @AuraEnabled
        @InvocableVariable(label='Property ID' description='The property ID that was searched')
        public String propertyId;

        @AuraEnabled
        @InvocableVariable(label='Items JSON' description='JSON array of structured booking item data for LWC display')
        public String itemsJson;
    }

    /**
     * @description Individual booking item for structured data display
     */
    global class BookingItemData {
        @AuraEnabled public String bookingId;
        @AuraEnabled public String bookingName;
        @AuraEnabled public String eventId;
        @AuraEnabled public String eventName;
        @AuraEnabled public Datetime eventDate;
        @AuraEnabled public String eventItemId;
        @AuraEnabled public String itemName;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal bookedQuantity;
    }
}

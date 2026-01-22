/**
 * @description Flow-invocable action for booking confirmation
 * Sets booking status to Definite, assigns Agentforce Agent contact,
 * and blocks inventory by updating GuestroomTypeDay__c records
 */
public with sharing class ConfirmBookingAction {

    // Agentforce Agent Contact ID
    private static final String AGENTFORCE_CONTACT_ID = '003Ka0000416c4CIAQ';

    /**
     * @description Input parameters for the invocable action
     */
    public class Input {
        @InvocableVariable(label='Booking ID' description='ID of the Booking to confirm' required=true)
        public Id bookingId;

        @InvocableVariable(label='Rooms to Block' description='Number of rooms to block in inventory' required=false)
        public Integer roomsToBlock;

        @InvocableVariable(label='Room Type Name' description='Specific room type to block (optional)' required=false)
        public String roomTypeName;
    }

    /**
     * @description Output results from the invocable action
     */
    public class Output {
        @InvocableVariable(label='Success' description='True if booking was confirmed successfully')
        public Boolean success;

        @InvocableVariable(label='Booking ID' description='ID of the confirmed Booking')
        public Id bookingId;

        @InvocableVariable(label='Rooms Blocked' description='Number of rooms blocked in inventory')
        public Integer roomsBlocked;

        @InvocableVariable(label='Error Message' description='Error message if confirmation failed')
        public String errorMessage;
    }

    /**
     * @description Invocable method to confirm a booking
     * @param inputs List of Input objects
     * @return List of Output objects with confirmation results
     */
    @InvocableMethod(label='Confirm Booking' description='Confirms a booking, sets status to Definite, and blocks inventory' category='Email Processing')
    public static List<Output> confirmBooking(List<Input> inputs) {
        List<Output> results = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();
            output.bookingId = input.bookingId;
            output.roomsBlocked = 0;

            try {
                // Validate booking ID
                if (input.bookingId == null) {
                    throw new ConfirmBookingException('Booking ID is required');
                }

                // Query the booking to get dates and property
                Booking__c booking = [
                    SELECT Id, Name, BookingStatus__c, BookingAgent__c,
                           ArrivalDate__c, DepartureDate__c, Property__c
                    FROM Booking__c
                    WHERE Id = :input.bookingId
                    LIMIT 1
                ];

                // Update booking status and agent
                booking.BookingStatus__c = 'Definite';
                booking.BookingAgent__c = AGENTFORCE_CONTACT_ID;
                update booking;

                System.debug('Booking ' + booking.Id + ' confirmed with status Definite');

                // Block inventory if rooms specified
                if (input.roomsToBlock != null && input.roomsToBlock > 0 &&
                    booking.ArrivalDate__c != null && booking.DepartureDate__c != null) {

                    Integer blocked = blockInventory(
                        booking.Property__c,
                        booking.ArrivalDate__c,
                        booking.DepartureDate__c,
                        input.roomsToBlock,
                        input.roomTypeName
                    );
                    output.roomsBlocked = blocked;
                }

                output.success = true;

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'ConfirmBookingAction error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }

            results.add(output);
        }

        return results;
    }

    /**
     * @description Blocks inventory by updating GuestroomTypeDay__c.BlockedDefinite__c
     * @param property The property picklist value
     * @param checkInDate Check-in date (inclusive)
     * @param checkOutDate Check-out date (exclusive)
     * @param roomsToBlock Number of rooms to block
     * @param roomTypeName Optional specific room type
     * @return Number of GuestroomTypeDay records updated
     */
    private static Integer blockInventory(
        String property,
        Date checkInDate,
        Date checkOutDate,
        Integer roomsToBlock,
        String roomTypeName
    ) {
        // Find Location by property name
        List<Location__c> locations = [
            SELECT Id, Name
            FROM Location__c
            WHERE Name = :property
            LIMIT 1
        ];

        if (locations.isEmpty()) {
            System.debug('No location found for property: ' + property);
            return 0;
        }

        Id locationId = locations[0].Id;

        // Build query for GuestroomTypeDay records
        String query = 'SELECT Id, BlockedDefinite__c, EffectiveDate__c, GuestroomType__r.Name ' +
                       'FROM GuestroomTypeDay__c ' +
                       'WHERE Location__c = :locationId ' +
                       'AND EffectiveDate__c >= :checkInDate ' +
                       'AND EffectiveDate__c < :checkOutDate';

        // Filter by room type if specified
        Boolean filterByRoomType = String.isNotBlank(roomTypeName) && roomTypeName != 'Any';

        List<GuestroomTypeDay__c> inventoryRecords = Database.query(query);

        if (inventoryRecords.isEmpty()) {
            System.debug('No inventory records found for date range');
            return 0;
        }

        List<GuestroomTypeDay__c> recordsToUpdate = new List<GuestroomTypeDay__c>();

        for (GuestroomTypeDay__c inv : inventoryRecords) {
            // Apply room type filter if specified
            if (filterByRoomType && inv.GuestroomType__r.Name != roomTypeName) {
                continue;
            }

            // Increment BlockedDefinite__c
            Decimal currentBlocked = inv.BlockedDefinite__c != null ? inv.BlockedDefinite__c : 0;
            inv.BlockedDefinite__c = currentBlocked + roomsToBlock;
            recordsToUpdate.add(inv);
        }

        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
            System.debug('Updated ' + recordsToUpdate.size() + ' GuestroomTypeDay records with BlockedDefinite__c = ' + roomsToBlock);
        }

        return recordsToUpdate.size();
    }

    /**
     * @description Custom exception for booking confirmation errors
     */
    public class ConfirmBookingException extends Exception {}
}

/**
 * @description Flow-invocable action to create a Booking record from email processing data
 * Creates Booking__c with associated Account, Contact, and property information
 */
public with sharing class CreateBookingFromEmailAction {

    /**
     * @description Input parameters for the invocable action
     */
    public class Input {
        @InvocableVariable(label='Account ID' description='ID of the Account for the booking' required=true)
        public Id accountId;

        @InvocableVariable(label='Contact ID' description='ID of the Contact for the booking' required=true)
        public Id contactId;

        @InvocableVariable(label='Location ID' description='ID of the Location__c record' required=true)
        public Id locationId;

        @InvocableVariable(label='Booking Name' description='Name/title for the booking (event name)' required=true)
        public String bookingName;

        @InvocableVariable(label='Arrival Date' description='Check-in date' required=true)
        public Date arrivalDate;

        @InvocableVariable(label='Departure Date' description='Check-out date' required=true)
        public Date departureDate;

        @InvocableVariable(label='Rooms Requested' description='Number of rooms requested' required=false)
        public Integer roomsRequested;

        @InvocableVariable(label='Room Type' description='Preferred room type' required=false)
        public String roomType;

        @InvocableVariable(label='Special Requests' description='Any special requests from the guest' required=false)
        public String specialRequests;

        @InvocableVariable(label='Estimated Revenue' description='Estimated total revenue' required=false)
        public Decimal estimatedRevenue;

        @InvocableVariable(label='Email Processing Log ID' description='ID of the Email Processing Log to link' required=false)
        public Id emailLogId;
    }

    /**
     * @description Output results from the invocable action
     */
    public class Output {
        @InvocableVariable(label='Booking ID' description='ID of the created Booking record')
        public Id bookingId;

        @InvocableVariable(label='Booking Name' description='Name of the created Booking')
        public String bookingName;

        @InvocableVariable(label='Success' description='True if booking was created successfully')
        public Boolean success;

        @InvocableVariable(label='Error Message' description='Error message if creation failed')
        public String errorMessage;
    }

    /**
     * @description Invocable method to create a Booking record
     * @param inputs List of Input objects
     * @return List of Output objects with Booking IDs
     */
    @InvocableMethod(label='Create Booking from Email' description='Creates a Booking__c record from email processing data' category='Email Processing')
    public static List<Output> createBooking(List<Input> inputs) {
        List<Output> results = new List<Output>();

        // Collect all Location IDs to query
        Set<Id> locationIds = new Set<Id>();
        for (Input input : inputs) {
            if (input.locationId != null) {
                locationIds.add(input.locationId);
            }
        }

        // Query Location records to get names for Property mapping
        Map<Id, Location__c> locationMap = new Map<Id, Location__c>([
            SELECT Id, Name
            FROM Location__c
            WHERE Id IN :locationIds
        ]);

        for (Input input : inputs) {
            Output output = new Output();

            try {
                // Validate required fields
                if (input.accountId == null) {
                    throw new BookingCreationException('Account ID is required');
                }
                if (input.contactId == null) {
                    throw new BookingCreationException('Contact ID is required');
                }
                if (input.locationId == null) {
                    throw new BookingCreationException('Location ID is required');
                }
                if (input.arrivalDate == null) {
                    throw new BookingCreationException('Arrival Date is required');
                }
                if (input.departureDate == null) {
                    throw new BookingCreationException('Departure Date is required');
                }

                // Get the property name from the Location
                Location__c location = locationMap.get(input.locationId);
                String propertyValue = getPropertyPicklistValue(location != null ? location.Name : null);

                // Build the booking name
                String finalBookingName = input.bookingName;
                if (String.isBlank(finalBookingName)) {
                    finalBookingName = 'Email Booking - ' + input.arrivalDate.format();
                }

                // Create the Booking record
                Booking__c newBooking = new Booking__c(
                    Name = finalBookingName,
                    Account__c = input.accountId,
                    BookingContact__c = input.contactId,
                    Property__c = propertyValue,
                    ArrivalDate__c = input.arrivalDate,
                    DepartureDate__c = input.departureDate,
                    BookingStatus__c = 'Prospect',  // Start as Prospect status
                    BookedDate__c = Date.today()    // Required field - date booking was created
                );

                // Set optional fields if available
                if (input.roomsRequested != null) {
                    // Check if the field exists before setting
                    // newBooking.put('Rooms_Requested__c', input.roomsRequested);
                }
                if (String.isNotBlank(input.specialRequests)) {
                    // newBooking.put('Special_Requests__c', input.specialRequests);
                }

                insert newBooking;

                output.bookingId = newBooking.Id;
                output.bookingName = newBooking.Name;
                output.success = true;

                System.debug('Created Booking: ' + newBooking.Id + ' - ' + newBooking.Name);

                // Update the Email Processing Log to link to this Booking
                if (input.emailLogId != null) {
                    // Query the log to get its Email_Thread__c reference
                    Email_Processing_Log__c existingLog = [
                        SELECT Id, Email_Thread__c
                        FROM Email_Processing_Log__c
                        WHERE Id = :input.emailLogId
                        LIMIT 1
                    ];

                    Email_Processing_Log__c logToUpdate = new Email_Processing_Log__c(
                        Id = input.emailLogId,
                        Booking__c = newBooking.Id
                    );
                    update logToUpdate;
                    System.debug('Updated Email Processing Log ' + input.emailLogId + ' with Booking__c = ' + newBooking.Id);

                    // Link booking to Email Thread
                    if (existingLog.Email_Thread__c != null) {
                        EmailThreadService.linkBookingToThread(existingLog.Email_Thread__c, newBooking.Id);
                        System.debug('Linked Email Thread ' + existingLog.Email_Thread__c + ' to Booking ' + newBooking.Id);
                    }
                }

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'CreateBookingFromEmailAction error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }

            results.add(output);
        }

        return results;
    }

    /**
     * @description Maps a Location name to the Property__c picklist value
     * @param locationName The name of the Location__c record
     * @return The matching Property__c picklist value, or 'Default' if not found
     */
    private static String getPropertyPicklistValue(String locationName) {
        if (String.isBlank(locationName)) {
            return 'Default';
        }

        // Map of Location names to Property picklist values
        // These should match exactly or be close enough for the picklist
        Map<String, String> propertyMapping = new Map<String, String>{
            'Ashworth by the Sea' => 'Ashworth by the Sea',
            'Ashworth' => 'Ashworth by the Sea',
            'Westwood Inn' => 'Westwood Inn',
            'Red Mountain Resort' => 'Red Mountain Resort',
            'Red Mountain Inn' => 'Red Mountain Inn',
            'Strafford Hotel Portsmouth' => 'Strafford Hotel Portsmouth',
            'Strafford Hotel' => 'Strafford Hotel Portsmouth',
            'Royal Hotel Stratham' => 'Royal Hotel Stratham',
            'Royal Hotel' => 'Royal Hotel Stratham',
            'Strafford Horse Sanctuary & Inn' => 'Strafford Horse Sanctuary & Inn',
            'Strafford Horse Sanctuary' => 'Strafford Horse Sanctuary & Inn',
            'Delphi Default Property' => 'Delphi Default Property'
        };

        // Try exact match first
        if (propertyMapping.containsKey(locationName)) {
            return propertyMapping.get(locationName);
        }

        // Try case-insensitive match
        for (String key : propertyMapping.keySet()) {
            if (key.equalsIgnoreCase(locationName)) {
                return propertyMapping.get(key);
            }
        }

        // Try contains match for partial names
        for (String key : propertyMapping.keySet()) {
            if (locationName.containsIgnoreCase(key) || key.containsIgnoreCase(locationName)) {
                return propertyMapping.get(key);
            }
        }

        // If the location name itself is a valid picklist value, use it directly
        Set<String> validPicklistValues = new Set<String>{
            'Default',
            'Delphi Default Property',
            'Westwood Inn',
            'Red Mountain Resort',
            'Red Mountain Inn',
            'Strafford Hotel Portsmouth',
            'Royal Hotel Stratham',
            'Ashworth by the Sea',
            'Strafford Horse Sanctuary & Inn'
        };

        if (validPicklistValues.contains(locationName)) {
            return locationName;
        }

        // Default fallback
        return 'Default';
    }

    /**
     * @description Custom exception for booking creation errors
     */
    public class BookingCreationException extends Exception {}
}

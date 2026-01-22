/**
 * @description Flow-invocable action wrapper for parsing booking emails
 * Uses BookingEmailPromptService to invoke the Parse_Hotel_Booking_Email prompt template
 */
global with sharing class InvokeParseBookingEmailAction {

    /**
     * @description Input class for the invocable method
     */
    global class Input {
        @InvocableVariable(label='Email Body' description='Raw email body text' required=true)
        public String emailBody;

        @InvocableVariable(label='Email Subject' description='Email subject line' required=true)
        public String emailSubject;

        @InvocableVariable(label='Sender Name' description='Name of the email sender' required=false)
        public String senderName;

        @InvocableVariable(label='Today Date' description='Todays date for relative date parsing (YYYY-MM-DD)' required=false)
        public String todayDate;
    }

    /**
     * @description Output class containing parsed booking request data
     */
    global class Output {
        @InvocableVariable(label='Check-In Date')
        public Date checkInDate;

        @InvocableVariable(label='Check-Out Date')
        public Date checkOutDate;

        @InvocableVariable(label='Number of Nights')
        public Integer numberOfNights;

        @InvocableVariable(label='Total Rooms Requested')
        public Integer totalRoomsRequested;

        @InvocableVariable(label='Room Type Preference')
        public String roomTypePreference;

        @InvocableVariable(label='Guest Name')
        public String guestName;

        @InvocableVariable(label='Organization Name')
        public String organizationName;

        @InvocableVariable(label='Event Name')
        public String eventName;

        @InvocableVariable(label='Special Requests')
        public String specialRequests;

        @InvocableVariable(label='Is Booking Request')
        public Boolean isBookingRequest;

        @InvocableVariable(label='Is Urgent')
        public Boolean isUrgent;

        @InvocableVariable(label='Confidence Level')
        public String confidence;

        @InvocableVariable(label='Suggested Action')
        public String suggestedAction;

        @InvocableVariable(label='Raw JSON Response')
        public String rawJson;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    /**
     * @description Invocable method to parse booking emails
     * @param inputs List of Input objects containing email data
     * @return List of Output objects containing parsed booking data
     */
    @InvocableMethod(
        label='Parse Booking Email'
        description='Extracts structured booking request details from hotel inquiry emails using AI'
        category='Email Booking Automation'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                // Validate required inputs
                if (String.isBlank(input.emailBody)) {
                    output.success = false;
                    output.errorMessage = 'Email body is required';
                    outputs.add(output);
                    continue;
                }

                // Call the prompt service
                BookingEmailPromptService.ParsedBookingRequest result =
                    BookingEmailPromptService.parseBookingEmail(
                        input.emailBody,
                        input.emailSubject,
                        input.senderName
                    );

                // Map the result to the output
                output.success = true;
                output.isBookingRequest = result.isBookingRequest != false; // Default to true if null
                output.checkInDate = result.checkInDate;
                output.checkOutDate = result.checkOutDate;
                output.numberOfNights = result.numberOfNights;
                output.totalRoomsRequested = result.totalRoomsRequested;
                output.roomTypePreference = result.roomTypePreference;
                output.guestName = result.guestName;
                output.organizationName = result.organizationName;
                output.eventName = result.eventName;
                output.specialRequests = result.specialRequests;
                output.isUrgent = result.isUrgent;
                output.confidence = result.confidence;
                output.suggestedAction = result.suggestedAction;
                output.rawJson = result.rawJson;

                System.debug('Successfully parsed booking email. Check-in: ' + output.checkInDate +
                    ', Check-out: ' + output.checkOutDate + ', Rooms: ' + output.totalRoomsRequested);

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = 'Error parsing email: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'InvokeParseBookingEmailAction error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }

            outputs.add(output);
        }

        return outputs;
    }
}

/**
 * @description Flow-invocable action for generating booking response emails
 * Uses BookingEmailPromptService to invoke the Generate_Booking_Response_Email prompt template
 */
global with sharing class InvokeGenerateResponseAction {

    /**
     * @description Input class for the invocable method
     */
    global class Input {
        @InvocableVariable(label='Sender Info JSON' description='JSON with firstName, fullName, organizationName, originalSubject' required=true)
        public String senderInfoJson;

        @InvocableVariable(label='Booking Request JSON' description='Parsed booking request as JSON' required=true)
        public String bookingRequestJson;

        @InvocableVariable(label='Availability JSON' description='Availability analysis result as JSON' required=true)
        public String availabilityJson;

        @InvocableVariable(label='Hotel Info JSON' description='JSON with hotelName, phone, email, salespersonName, salespersonTitle' required=true)
        public String hotelInfoJson;
    }

    /**
     * @description Output class containing generated email content
     */
    global class Output {
        @InvocableVariable(label='Email Subject')
        public String emailSubject;

        @InvocableVariable(label='Email Body HTML')
        public String emailBodyHtml;

        @InvocableVariable(label='Email Body Plain')
        public String emailBodyPlain;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    /**
     * @description Invocable method to generate response email
     * @param inputs List of Input objects containing context data
     * @return List of Output objects containing generated email content
     */
    @InvocableMethod(
        label='Generate Booking Response Email'
        description='Generates a personalized booking response email using AI'
        category='Email Booking Automation'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                // Validate required inputs
                if (String.isBlank(input.senderInfoJson)) {
                    output.success = false;
                    output.errorMessage = 'Sender info JSON is required';
                    outputs.add(output);
                    continue;
                }

                if (String.isBlank(input.bookingRequestJson)) {
                    output.success = false;
                    output.errorMessage = 'Booking request JSON is required';
                    outputs.add(output);
                    continue;
                }

                if (String.isBlank(input.availabilityJson)) {
                    output.success = false;
                    output.errorMessage = 'Availability JSON is required';
                    outputs.add(output);
                    continue;
                }

                if (String.isBlank(input.hotelInfoJson)) {
                    output.success = false;
                    output.errorMessage = 'Hotel info JSON is required';
                    outputs.add(output);
                    continue;
                }

                // Call the prompt service
                BookingEmailPromptService.GeneratedResponse result =
                    BookingEmailPromptService.generateResponse(
                        input.senderInfoJson,
                        input.bookingRequestJson,
                        input.availabilityJson,
                        input.hotelInfoJson
                    );

                // Map the result to the output
                output.success = result.success;
                output.emailSubject = result.emailSubject;
                output.emailBodyHtml = result.emailBodyHtml;
                output.emailBodyPlain = result.emailBodyPlain;
                output.errorMessage = result.errorMessage;

                System.debug('Response email generated. Subject: ' + output.emailSubject);

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = 'Error generating response: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'InvokeGenerateResponseAction error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }

            outputs.add(output);
        }

        return outputs;
    }

    /**
     * @description Helper method to build sender info JSON from Email_Processing_Log__c fields
     * @param senderEmail The sender's email address
     * @param senderName The sender's full name
     * @param organizationName The organization name (optional)
     * @param originalSubject The original email subject
     * @return JSON string with sender info
     */
    public static String buildSenderInfoJson(String senderEmail, String senderName, String organizationName, String originalSubject) {
        Map<String, Object> senderInfo = new Map<String, Object>();

        // Parse first name from full name
        String firstName = senderName;
        if (String.isNotBlank(senderName) && senderName.contains(' ')) {
            firstName = senderName.substringBefore(' ');
        }

        senderInfo.put('firstName', firstName);
        senderInfo.put('fullName', senderName);
        senderInfo.put('email', senderEmail);
        senderInfo.put('organizationName', organizationName);
        senderInfo.put('originalSubject', originalSubject);

        return JSON.serialize(senderInfo);
    }

    /**
     * @description Helper method to build hotel info JSON from Location__c fields
     * @param location The Location__c record
     * @param salespersonName Name of the salesperson
     * @param salespersonTitle Title of the salesperson
     * @return JSON string with hotel info
     */
    public static String buildHotelInfoJson(Location__c location, String salespersonName, String salespersonTitle) {
        Map<String, Object> hotelInfo = new Map<String, Object>();

        hotelInfo.put('hotelName', location.Name);
        hotelInfo.put('phone', location.Phone__c);
        hotelInfo.put('email', location.Email__c);
        hotelInfo.put('salespersonName', String.isNotBlank(salespersonName) ? salespersonName : 'Hotel Reservations Team');
        hotelInfo.put('salespersonTitle', String.isNotBlank(salespersonTitle) ? salespersonTitle : 'Group Sales');

        return JSON.serialize(hotelInfo);
    }
}

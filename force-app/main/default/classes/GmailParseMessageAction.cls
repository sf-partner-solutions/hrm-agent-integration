/**
 * @description Invocable action to parse Gmail message and find Location
 */
global with sharing class GmailParseMessageAction {

    global class Input {
        @InvocableVariable(label='Access Token' required=true)
        public String accessToken;

        @InvocableVariable(label='Message ID' required=true)
        public String messageId;
    }

    global class Output {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Location Found')
        public Boolean locationFound;

        @InvocableVariable(label='Location ID')
        public String locationId;

        @InvocableVariable(label='Location Name')
        public String locationName;

        @InvocableVariable(label='Recipient Email')
        public String recipientEmail;

        @InvocableVariable(label='Sender Email')
        public String senderEmail;

        @InvocableVariable(label='Sender Name')
        public String senderName;

        @InvocableVariable(label='Sender First Name')
        public String senderFirstName;

        @InvocableVariable(label='Subject')
        public String subject;

        @InvocableVariable(label='Email Body')
        public String emailBody;

        @InvocableVariable(label='Thread ID')
        public String threadId;

        @InvocableVariable(label='Is Booking Request')
        public Boolean isBookingRequest;

        @InvocableVariable(label='Hotel Phone')
        public String hotelPhone;

        @InvocableVariable(label='Hotel Email')
        public String hotelEmail;

        @InvocableVariable(label='Salesperson Name')
        public String salespersonName;

        @InvocableVariable(label='Salesperson Title')
        public String salespersonTitle;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Parse Gmail Message and Find Location'
        description='Gets message details and matches recipient to Location'
        category='Gmail Integration'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();
            output.success = false;
            output.locationFound = false;
            output.isBookingRequest = false;

            try {
                GmailAPIService.GmailMessageDetail messageDetail =
                    GmailAPIService.getMessage(input.accessToken, input.messageId);

                if (messageDetail == null) {
                    output.errorMessage = 'Failed to retrieve message';
                    outputs.add(output);
                    continue;
                }

                output.threadId = messageDetail.threadId;
                output.subject = GmailMessageParser.getSubject(messageDetail);
                output.emailBody = GmailMessageParser.getEmailBody(messageDetail);
                output.recipientEmail = GmailMessageParser.extractRecipientEmail(messageDetail);

                GmailMessageParser.SenderInfo senderInfo =
                    GmailMessageParser.extractSenderInfo(messageDetail);
                output.senderEmail = senderInfo.email;
                output.senderName = senderInfo.name;
                output.senderFirstName = senderInfo.firstName;

                output.isBookingRequest = GmailMessageParser.isLikelyBookingRequest(
                    output.subject, output.emailBody
                );

                if (String.isNotBlank(output.recipientEmail)) {
                    LocationEmailMappingService.LocationLookupResult locationResult =
                        LocationEmailMappingService.findLocationByEmail(output.recipientEmail);

                    if (locationResult.found) {
                        output.locationFound = true;
                        output.locationId = locationResult.locationId;
                        output.locationName = locationResult.locationName;
                        output.hotelPhone = locationResult.phone;
                        output.hotelEmail = locationResult.email;
                        output.salespersonName = LocationEmailMappingService.getSalespersonName(locationResult);
                        output.salespersonTitle = LocationEmailMappingService.getSalespersonTitle(locationResult);
                    }
                }

                output.success = true;

            } catch (Exception e) {
                output.errorMessage = 'Exception: ' + e.getMessage();
            }

            outputs.add(output);
        }

        return outputs;
    }
}

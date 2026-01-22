/**
 * @description Invocable action to create email processing log
 */
global with sharing class GmailCreateLogAction {

    global class Input {
        @InvocableVariable(label='Message ID' required=true)
        public String messageId;

        @InvocableVariable(label='Thread ID')
        public String threadId;

        @InvocableVariable(label='Sender Email')
        public String senderEmail;

        @InvocableVariable(label='Sender Name')
        public String senderName;

        @InvocableVariable(label='Recipient Email')
        public String recipientEmail;

        @InvocableVariable(label='Subject')
        public String subject;

        @InvocableVariable(label='Location ID')
        public String locationId;

        @InvocableVariable(label='Gmail Connection State ID')
        public String gmailConnectionStateId;

        @InvocableVariable(label='Booking Request JSON')
        public String bookingRequestJson;

        @InvocableVariable(label='Availability Result JSON')
        public String availabilityResultJson;

        @InvocableVariable(label='Response Sent')
        public Boolean responseSent;

        @InvocableVariable(label='Processing Status')
        public String processingStatus;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        @InvocableVariable(label='Check-In Date')
        public Date checkInDate;

        @InvocableVariable(label='Check-Out Date')
        public Date checkOutDate;

        @InvocableVariable(label='Rooms Requested')
        public Integer roomsRequested;

        @InvocableVariable(label='Rooms Available')
        public Integer roomsAvailable;
    }

    global class Output {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Log Record ID')
        public String logRecordId;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Create Email Processing Log'
        description='Creates an Email_Processing_Log__c record for audit trail'
        category='Gmail Integration'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                Email_Processing_Log__c log = new Email_Processing_Log__c();
                log.Message_Id__c = input.messageId;
                log.Thread_Id__c = input.threadId;
                log.Sender_Email__c = input.senderEmail;
                log.Sender_Name__c = input.senderName;
                log.Recipient_Email__c = input.recipientEmail;
                log.Subject__c = input.subject;

                if (String.isNotBlank(input.locationId)) {
                    log.Location__c = Id.valueOf(input.locationId);
                }
                if (String.isNotBlank(input.gmailConnectionStateId)) {
                    log.Gmail_Connection_State__c = Id.valueOf(input.gmailConnectionStateId);
                }

                log.Booking_Request_JSON__c = input.bookingRequestJson;
                log.Availability_Result_JSON__c = input.availabilityResultJson;
                log.Response_Sent__c = input.responseSent == true;
                log.Response_Date__c = input.responseSent == true ? DateTime.now() : null;
                log.Processing_Status__c = String.isNotBlank(input.processingStatus) ?
                    input.processingStatus : 'Processed';
                log.Error_Message__c = input.errorMessage;
                log.Check_In_Date__c = input.checkInDate;
                log.Check_Out_Date__c = input.checkOutDate;
                log.Rooms_Requested__c = input.roomsRequested;
                log.Rooms_Available__c = input.roomsAvailable;

                insert log;

                output.success = true;
                output.logRecordId = log.Id;

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = 'Exception: ' + e.getMessage();
            }

            outputs.add(output);
        }

        return outputs;
    }
}

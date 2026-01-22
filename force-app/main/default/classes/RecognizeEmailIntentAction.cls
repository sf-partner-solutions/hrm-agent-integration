/**
 * @description Flow-invocable action to recognize the intent of an incoming email
 * Uses AI prompt template to classify emails as new inquiries, follow-ups, confirmations, etc.
 */
public with sharing class RecognizeEmailIntentAction {

    /**
     * @description Input parameters for the invocable action
     */
    public class Input {
        @InvocableVariable(label='Email Body' description='The raw email body text' required=true)
        public String emailBody;

        @InvocableVariable(label='Email Subject' description='The email subject line' required=true)
        public String emailSubject;

        @InvocableVariable(label='Sender Name' description='The name of the email sender' required=false)
        public String senderName;

        @InvocableVariable(label='Thread ID' description='Gmail thread ID to check for existing conversation' required=false)
        public String threadId;

        @InvocableVariable(label='Log Record ID' description='ID of the Email Processing Log record' required=false)
        public Id logRecordId;
    }

    /**
     * @description Output results from the invocable action
     */
    public class Output {
        @InvocableVariable(label='Email Intent' description='Classified intent: New_Inquiry, Follow_Up_Answer, Booking_Confirmation, Booking_Rejection, General_Question, Modification_Request')
        public String emailIntent;

        @InvocableVariable(label='Confidence' description='Confidence level: high, medium, low')
        public String confidence;

        @InvocableVariable(label='Reasoning' description='AI explanation for the classification')
        public String reasoning;

        @InvocableVariable(label='Guest Name' description='Extracted guest name from the email')
        public String guestName;

        @InvocableVariable(label='Organization Name' description='Extracted organization name from the email')
        public String organizationName;

        @InvocableVariable(label='Event Name' description='Extracted event name from the email')
        public String eventName;

        @InvocableVariable(label='Has Booking Confirmation' description='True if the email confirms a booking')
        public Boolean hasBookingConfirmation;

        @InvocableVariable(label='Has Rejection' description='True if the email rejects/cancels a booking')
        public Boolean hasRejection;

        @InvocableVariable(label='Is Follow Up' description='True if this is a follow-up to an existing thread')
        public Boolean isFollowUp;

        @InvocableVariable(label='Original Inquiry Log ID' description='ID of the original Email Processing Log for this thread')
        public Id originalInquiryLogId;

        @InvocableVariable(label='Success' description='True if intent recognition was successful')
        public Boolean success;

        @InvocableVariable(label='Error Message' description='Error message if recognition failed')
        public String errorMessage;

        @InvocableVariable(label='Raw JSON' description='Full JSON response from the prompt')
        public String rawJson;
    }

    /**
     * @description Invocable method to recognize email intent
     * @param inputs List of Input objects
     * @return List of Output objects with intent classification results
     */
    @InvocableMethod(label='Recognize Email Intent' description='Analyzes an email to determine its intent (inquiry, confirmation, rejection, etc.)' category='Email Processing')
    public static List<Output> recognizeIntent(List<Input> inputs) {
        List<Output> results = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                // First, check if this is a follow-up to an existing thread
                String previousContext = '';
                if (String.isNotBlank(input.threadId)) {
                    // Query for existing Email Processing Log records in this thread
                    List<Email_Processing_Log__c> existingLogs = [
                        SELECT Id, Subject__c, Booking_Request_JSON__c, Generated_Email_Body__c,
                               Email_Intent__c, Processing_Status__c
                        FROM Email_Processing_Log__c
                        WHERE Thread_Id__c = :input.threadId
                        AND Id != :input.logRecordId
                        ORDER BY CreatedDate ASC
                        LIMIT 10
                    ];

                    if (!existingLogs.isEmpty()) {
                        output.isFollowUp = true;
                        // Get the original inquiry log (first in thread)
                        for (Email_Processing_Log__c log : existingLogs) {
                            if (log.Email_Intent__c == 'New_Inquiry' || log.Email_Intent__c == null) {
                                output.originalInquiryLogId = log.Id;
                                break;
                            }
                        }
                        // If no explicit New_Inquiry found, use the first log in the thread
                        if (output.originalInquiryLogId == null) {
                            output.originalInquiryLogId = existingLogs[0].Id;
                        }

                        // Build context from previous emails
                        previousContext = buildPreviousContext(existingLogs);
                    } else {
                        output.isFollowUp = false;
                    }
                } else {
                    output.isFollowUp = false;
                }

                // Call the prompt service to recognize intent
                BookingEmailPromptService.EmailIntentResult intentResult =
                    BookingEmailPromptService.recognizeEmailIntent(
                        input.emailBody,
                        input.emailSubject,
                        input.senderName,
                        previousContext
                    );

                // Map the results
                output.emailIntent = intentResult.intent;
                output.confidence = intentResult.confidence;
                output.reasoning = intentResult.reasoning;
                output.guestName = intentResult.extractedGuestName;
                output.organizationName = intentResult.extractedOrganizationName;
                output.eventName = intentResult.extractedEventName;
                output.hasBookingConfirmation = intentResult.hasBookingConfirmation;
                output.hasRejection = intentResult.hasRejection;
                output.rawJson = intentResult.rawJson;
                output.success = true;

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'RecognizeEmailIntentAction error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }

            results.add(output);
        }

        return results;
    }

    /**
     * @description Builds context string from previous emails in the thread
     * @param logs List of previous Email Processing Log records
     * @return String containing summary of previous conversation
     */
    private static String buildPreviousContext(List<Email_Processing_Log__c> logs) {
        List<String> contextParts = new List<String>();

        for (Email_Processing_Log__c log : logs) {
            String part = 'Previous email - Subject: ' + (log.Subject__c != null ? log.Subject__c : 'N/A');
            if (log.Email_Intent__c != null) {
                part += ', Intent: ' + log.Email_Intent__c;
            }
            if (log.Generated_Email_Body__c != null) {
                // Include a summary of our response
                String responsePreview = log.Generated_Email_Body__c.stripHtmlTags();
                if (responsePreview.length() > 500) {
                    responsePreview = responsePreview.substring(0, 500) + '...';
                }
                part += ', Our Response: ' + responsePreview;
            }
            contextParts.add(part);
        }

        return String.join(contextParts, '\n---\n');
    }
}

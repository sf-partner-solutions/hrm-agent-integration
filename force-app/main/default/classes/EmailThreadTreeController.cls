/**
 * @description Controller for the emailThreadViewer LWC component
 * Provides methods to retrieve email logs and thread details for tree-grid display
 */
public with sharing class EmailThreadTreeController {

    /**
     * @description Wrapper class for email log data with nested structure
     */
    public class EmailLogWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String subject;
        @AuraEnabled public String senderEmail;
        @AuraEnabled public String senderName;
        @AuraEnabled public String emailIntent;
        @AuraEnabled public String processingStatus;
        @AuraEnabled public String originalEmail;
        @AuraEnabled public String generatedResponse;
        @AuraEnabled public Boolean responseSent;
        @AuraEnabled public Id bookingId;
        @AuraEnabled public String bookingName;
        @AuraEnabled public List<EmailLogWrapper> children;
    }

    /**
     * @description Gets all email logs for a thread with nested child structure for tree-grid
     * @param threadId The ID of the Email_Thread__c record
     * @return List of EmailLogWrapper objects (newest first, with children for expandable content)
     */
    @AuraEnabled(cacheable=true)
    public static List<EmailLogWrapper> getEmailLogs(Id threadId) {
        if (threadId == null) {
            return new List<EmailLogWrapper>();
        }

        List<Email_Processing_Log__c> logs = [
            SELECT Id, Name, CreatedDate, Subject__c, Sender_Email__c, Sender_Name__c,
                   Email_Intent__c, Processing_Status__c, Booking_Request_JSON__c,
                   Generated_Email_Body__c, Response_Sent__c, Booking__c, Booking__r.Name
            FROM Email_Processing_Log__c
            WHERE Email_Thread__c = :threadId
            ORDER BY CreatedDate DESC
        ];

        List<EmailLogWrapper> result = new List<EmailLogWrapper>();

        for (Email_Processing_Log__c log : logs) {
            EmailLogWrapper wrapper = new EmailLogWrapper();
            wrapper.id = log.Id;
            wrapper.name = log.Name;
            wrapper.createdDate = log.CreatedDate;
            wrapper.subject = log.Subject__c;
            wrapper.senderEmail = log.Sender_Email__c;
            wrapper.senderName = log.Sender_Name__c;
            wrapper.emailIntent = log.Email_Intent__c;
            wrapper.processingStatus = log.Processing_Status__c;
            wrapper.originalEmail = truncateText(log.Booking_Request_JSON__c, 500);
            wrapper.generatedResponse = truncateText(log.Generated_Email_Body__c, 500);
            wrapper.responseSent = log.Response_Sent__c;
            wrapper.bookingId = log.Booking__c;
            wrapper.bookingName = log.Booking__r != null ? log.Booking__r.Name : null;

            // Create children for expandable content
            wrapper.children = createChildren(log);

            result.add(wrapper);
        }

        return result;
    }

    /**
     * @description Creates child wrapper objects for expandable tree-grid rows
     * @param log The parent Email_Processing_Log__c record
     * @return List of child EmailLogWrapper objects
     */
    private static List<EmailLogWrapper> createChildren(Email_Processing_Log__c log) {
        List<EmailLogWrapper> children = new List<EmailLogWrapper>();

        // Add original email as a child row
        if (String.isNotBlank(log.Booking_Request_JSON__c)) {
            EmailLogWrapper originalChild = new EmailLogWrapper();
            originalChild.id = log.Id + '_original';
            originalChild.name = 'Original Email';
            originalChild.originalEmail = log.Booking_Request_JSON__c;
            originalChild.children = new List<EmailLogWrapper>();
            children.add(originalChild);
        }

        // Add generated response as a child row
        if (String.isNotBlank(log.Generated_Email_Body__c)) {
            EmailLogWrapper responseChild = new EmailLogWrapper();
            responseChild.id = log.Id + '_response';
            responseChild.name = 'Generated Response';
            responseChild.generatedResponse = log.Generated_Email_Body__c;
            responseChild.children = new List<EmailLogWrapper>();
            children.add(responseChild);
        }

        return children;
    }

    /**
     * @description Gets thread details for the header display
     * @param threadId The ID of the Email_Thread__c record
     * @return The Email_Thread__c record with related data
     */
    @AuraEnabled(cacheable=true)
    public static Email_Thread__c getThreadDetails(Id threadId) {
        if (threadId == null) {
            return null;
        }

        List<Email_Thread__c> threads = [
            SELECT Id, Name, Thread_Id__c, Thread_Subject__c, Sender_Email__c,
                   Sender_Name__c, First_Email_Date__c, Last_Email_Date__c,
                   Thread_Status__c, Booking__c, Booking__r.Name,
                   Location__c, Location__r.Name
            FROM Email_Thread__c
            WHERE Id = :threadId
            LIMIT 1
        ];

        return threads.isEmpty() ? null : threads[0];
    }

    /**
     * @description Gets the count of email logs in a thread
     * @param threadId The ID of the Email_Thread__c record
     * @return Number of email logs in the thread
     */
    @AuraEnabled(cacheable=true)
    public static Integer getEmailLogCount(Id threadId) {
        if (threadId == null) {
            return 0;
        }

        return [
            SELECT COUNT()
            FROM Email_Processing_Log__c
            WHERE Email_Thread__c = :threadId
        ];
    }

    /**
     * @description Truncates text to a maximum length with ellipsis
     * @param text The text to truncate
     * @param maxLength Maximum length before truncation
     * @return Truncated text with ellipsis if needed
     */
    private static String truncateText(String text, Integer maxLength) {
        if (String.isBlank(text)) {
            return text;
        }
        if (text.length() <= maxLength) {
            return text;
        }
        return text.substring(0, maxLength) + '...';
    }

    /**
     * @description Gets all email threads linked to a booking
     * @param bookingId The ID of the Booking__c record
     * @return List of Email_Thread__c records linked to the booking
     */
    @AuraEnabled(cacheable=true)
    public static List<Email_Thread__c> getThreadsForBooking(Id bookingId) {
        if (bookingId == null) {
            return new List<Email_Thread__c>();
        }

        return [
            SELECT Id, Name, Thread_Id__c, Thread_Subject__c, Sender_Email__c,
                   Sender_Name__c, First_Email_Date__c, Last_Email_Date__c,
                   Thread_Status__c, Booking__c, Booking__r.Name,
                   Location__c, Location__r.Name
            FROM Email_Thread__c
            WHERE Booking__c = :bookingId
            ORDER BY Last_Email_Date__c DESC
        ];
    }

    /**
     * @description Gets all email logs for a booking (across all threads)
     * @param bookingId The ID of the Booking__c record
     * @return List of EmailLogWrapper objects for all threads linked to the booking
     */
    @AuraEnabled(cacheable=true)
    public static List<EmailLogWrapper> getEmailLogsForBooking(Id bookingId) {
        if (bookingId == null) {
            return new List<EmailLogWrapper>();
        }

        List<Email_Processing_Log__c> logs = [
            SELECT Id, Name, CreatedDate, Subject__c, Sender_Email__c, Sender_Name__c,
                   Email_Intent__c, Processing_Status__c, Booking_Request_JSON__c,
                   Generated_Email_Body__c, Response_Sent__c, Booking__c, Booking__r.Name,
                   Email_Thread__c, Email_Thread__r.Thread_Subject__c
            FROM Email_Processing_Log__c
            WHERE Email_Thread__c IN (
                SELECT Id FROM Email_Thread__c WHERE Booking__c = :bookingId
            )
            ORDER BY CreatedDate DESC
        ];

        List<EmailLogWrapper> result = new List<EmailLogWrapper>();

        for (Email_Processing_Log__c log : logs) {
            EmailLogWrapper wrapper = new EmailLogWrapper();
            wrapper.id = log.Id;
            wrapper.name = log.Name;
            wrapper.createdDate = log.CreatedDate;
            wrapper.subject = log.Subject__c;
            wrapper.senderEmail = log.Sender_Email__c;
            wrapper.senderName = log.Sender_Name__c;
            wrapper.emailIntent = log.Email_Intent__c;
            wrapper.processingStatus = log.Processing_Status__c;
            wrapper.originalEmail = truncateText(log.Booking_Request_JSON__c, 500);
            wrapper.generatedResponse = truncateText(log.Generated_Email_Body__c, 500);
            wrapper.responseSent = log.Response_Sent__c;
            wrapper.bookingId = log.Booking__c;
            wrapper.bookingName = log.Booking__r != null ? log.Booking__r.Name : null;

            // Create children for expandable content
            wrapper.children = createChildren(log);

            result.add(wrapper);
        }

        return result;
    }

    /**
     * @description Gets the first/primary thread details for a booking
     * @param bookingId The ID of the Booking__c record
     * @return The primary Email_Thread__c record linked to the booking
     */
    @AuraEnabled(cacheable=true)
    public static Email_Thread__c getThreadDetailsForBooking(Id bookingId) {
        if (bookingId == null) {
            return null;
        }

        List<Email_Thread__c> threads = [
            SELECT Id, Name, Thread_Id__c, Thread_Subject__c, Sender_Email__c,
                   Sender_Name__c, First_Email_Date__c, Last_Email_Date__c,
                   Thread_Status__c, Booking__c, Booking__r.Name,
                   Location__c, Location__r.Name
            FROM Email_Thread__c
            WHERE Booking__c = :bookingId
            ORDER BY First_Email_Date__c ASC
            LIMIT 1
        ];

        return threads.isEmpty() ? null : threads[0];
    }
}

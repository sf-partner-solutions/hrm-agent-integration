/**
 * @description Service class for Email_Thread__c operations
 * Handles finding, creating, and managing email thread records
 */
public with sharing class EmailThreadService {

    /**
     * @description Finds an existing Email_Thread__c by threadId or creates a new one
     * @param threadId The Gmail thread ID
     * @param senderEmail Email address of the sender
     * @param senderName Name of the sender
     * @param subject Email subject line
     * @param locationId ID of the Location__c record
     * @return The found or newly created Email_Thread__c record
     */
    public static Email_Thread__c findOrCreateThread(
        String threadId,
        String senderEmail,
        String senderName,
        String subject,
        Id locationId
    ) {
        if (String.isBlank(threadId)) {
            return null;
        }

        // Try to find existing thread
        List<Email_Thread__c> existingThreads = [
            SELECT Id, Thread_Id__c, Booking__c, Location__c, Thread_Subject__c,
                   Sender_Email__c, Sender_Name__c, First_Email_Date__c,
                   Last_Email_Date__c, Thread_Status__c
            FROM Email_Thread__c
            WHERE Thread_Id__c = :threadId
            LIMIT 1
        ];

        Email_Thread__c thread;

        if (!existingThreads.isEmpty()) {
            // Update existing thread with latest email date
            thread = existingThreads[0];
            thread.Last_Email_Date__c = DateTime.now();
            update thread;
        } else {
            // Create new thread
            thread = new Email_Thread__c(
                Thread_Id__c = threadId,
                Sender_Email__c = senderEmail,
                Sender_Name__c = senderName,
                Thread_Subject__c = subject,
                Location__c = locationId,
                First_Email_Date__c = DateTime.now(),
                Last_Email_Date__c = DateTime.now(),
                Thread_Status__c = 'Active'
            );
            insert thread;
        }

        return thread;
    }

    /**
     * @description Links a Booking record to an Email Thread
     * @param threadId The ID of the Email_Thread__c record
     * @param bookingId The ID of the Booking__c record to link
     */
    public static void linkBookingToThread(Id threadId, Id bookingId) {
        if (threadId == null || bookingId == null) {
            return;
        }

        Email_Thread__c thread = new Email_Thread__c(
            Id = threadId,
            Booking__c = bookingId
        );
        update thread;
    }

    /**
     * @description Updates the thread status
     * @param threadId The ID of the Email_Thread__c record
     * @param status The new status value (Active, Closed, Pending_Response)
     */
    public static void updateThreadStatus(Id threadId, String status) {
        if (threadId == null || String.isBlank(status)) {
            return;
        }

        Email_Thread__c thread = new Email_Thread__c(
            Id = threadId,
            Thread_Status__c = status
        );
        update thread;
    }

    /**
     * @description Gets the Email Thread record by its Gmail thread ID
     * @param threadId The Gmail thread ID
     * @return The Email_Thread__c record if found, null otherwise
     */
    public static Email_Thread__c getThreadByGmailId(String threadId) {
        if (String.isBlank(threadId)) {
            return null;
        }

        List<Email_Thread__c> threads = [
            SELECT Id, Thread_Id__c, Booking__c, Location__c, Thread_Subject__c,
                   Sender_Email__c, Sender_Name__c, First_Email_Date__c,
                   Last_Email_Date__c, Thread_Status__c
            FROM Email_Thread__c
            WHERE Thread_Id__c = :threadId
            LIMIT 1
        ];

        return threads.isEmpty() ? null : threads[0];
    }
}

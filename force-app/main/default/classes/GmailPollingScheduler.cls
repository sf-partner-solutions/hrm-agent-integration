/**
 * @description Scheduled Apex class for polling Gmail inboxes
 * Checks for new booking request emails
 *
 * To schedule every 5 minutes (creates 12 jobs):
 * GmailPollingScheduler.scheduleEvery5Minutes();
 *
 * To schedule hourly (single job):
 * GmailPollingScheduler.scheduleJob();
 *
 * To unschedule all Gmail jobs:
 * GmailPollingScheduler.unscheduleAllJobs();
 */
global with sharing class GmailPollingScheduler implements Schedulable {

    /**
     * @description Main execute method called by the scheduler
     * Enqueues a Queueable job to handle callouts (scheduled Apex cannot make callouts directly)
     * @param ctx The SchedulableContext
     */
    global void execute(SchedulableContext ctx) {
        // Scheduled Apex cannot make HTTP callouts directly
        // Enqueue a Queueable job that implements Database.AllowsCallouts
        System.enqueueJob(new GmailPollingQueueable());
    }

    /**
     * @description Processes all active Gmail connections
     * Can also be called directly for testing
     */
    public static void processAllActiveConnections() {
        try {
            // Get all active connections
            List<Gmail_Connection__mdt> connections = GmailOAuthService.getActiveConnections();

            if (connections.isEmpty()) {
                System.debug('No active Gmail connections found');
                return;
            }

            // Process each connection
            for (Gmail_Connection__mdt connection : connections) {
                try {
                    processSingleConnection(connection.DeveloperName);
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'Error processing connection ' +
                        connection.DeveloperName + ': ' + e.getMessage());

                    // Log error to state record
                    Gmail_Connection_State__c state =
                        GmailOAuthService.getState(connection.DeveloperName);
                    if (state != null) {
                        state.Last_Error_Message__c = 'Scheduler error: ' + e.getMessage();
                        state.Poll_In_Progress__c = false;
                        update state;
                    }
                }
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in Gmail polling scheduler: ' + e.getMessage());
        }
    }

    /**
     * @description Wrapper class to hold message processing data between callout and DML phases
     */
    private class MessageProcessingData {
        public String messageId;
        public GmailAPIService.GmailMessageDetail messageDetail;
        public String recipientEmail;
        public GmailMessageParser.SenderInfo senderInfo;
        public String subject;
        public String emailBody;
        public Boolean isBookingRequest;
        public LocationEmailMappingService.LocationLookupResult location;
        public Boolean alreadyProcessed;
        public String errorMessage;
    }

    /**
     * @description Processes a single Gmail connection
     * IMPORTANT: All callouts must happen BEFORE any DML operations
     * @param connectionDeveloperName Developer name of the connection
     */
    public static void processSingleConnection(String connectionDeveloperName) {
        // Get connection metadata (no DML)
        Gmail_Connection__mdt connection = GmailOAuthService.getConnection(connectionDeveloperName);
        if (connection == null || !connection.Is_Active__c) {
            System.debug('Connection not found or inactive: ' + connectionDeveloperName);
            return;
        }

        // Query for existing state - DO NOT create yet (no DML before callouts)
        Gmail_Connection_State__c state = GmailOAuthService.getState(connectionDeveloperName);
        Boolean stateExists = (state != null);
        String lastHistoryId = stateExists ? state.Last_History_Id__c : null;

        // Check if another poll is in progress (prevent concurrent execution)
        if (stateExists && state.Poll_In_Progress__c) {
            System.debug('Poll already in progress for: ' + connectionDeveloperName);
            return;
        }

        Integer emailsProcessed = 0;
        String newHistoryId = null;
        Boolean success = false;
        String errorMessage = null;
        String accessToken = null;
        List<GmailAPIService.GmailMessage> messagesToProcess = new List<GmailAPIService.GmailMessage>();
        GmailOAuthService.TokenRefreshResult tokenResult = null;
        List<MessageProcessingData> processedMessages = new List<MessageProcessingData>();

        // Get list of already processed message IDs (query only, no DML)
        Set<String> alreadyProcessedIds = new Set<String>();

        try {
            // ============================================
            // PHASE 1: ALL CALLOUTS (before any DML)
            // ============================================

            // Step 1: Refresh OAuth token (callout - NO DML happens inside)
            tokenResult = GmailOAuthService.refreshAccessToken(connectionDeveloperName);

            if (!tokenResult.success) {
                throw new GmailPollingException('Token refresh failed: ' + tokenResult.errorMessage);
            }

            accessToken = tokenResult.accessToken;

            // Step 2: Get new messages (callout)
            GmailAPIService.ListMessagesResult messagesResult;

            if (String.isNotBlank(lastHistoryId)) {
                // Use incremental sync
                messagesResult = GmailAPIService.getHistoryList(accessToken, lastHistoryId);

                // If history ID expired, fall back to list messages
                if (!messagesResult.success && messagesResult.errorMessage != null &&
                    messagesResult.errorMessage.contains('expired')) {
                    System.debug('History ID expired, falling back to list messages');
                    messagesResult = GmailAPIService.listMessages(accessToken, 'is:unread in:inbox', 10);
                }
            } else {
                // Initial sync - get recent unread messages
                messagesResult = GmailAPIService.listMessages(accessToken, 'is:unread in:inbox', 10);
            }

            if (!messagesResult.success) {
                throw new GmailPollingException('Failed to get messages: ' + messagesResult.errorMessage);
            }

            newHistoryId = messagesResult.newHistoryId;
            messagesToProcess = messagesResult.messages;

            // Step 3: Get message IDs to check which are already processed (query only)
            if (!messagesToProcess.isEmpty()) {
                Set<String> messageIds = new Set<String>();
                for (GmailAPIService.GmailMessage msg : messagesToProcess) {
                    messageIds.add(msg.id);
                }
                for (Email_Processing_Log__c log : [
                    SELECT Message_Id__c FROM Email_Processing_Log__c
                    WHERE Message_Id__c IN :messageIds
                ]) {
                    alreadyProcessedIds.add(log.Message_Id__c);
                }
            }

            // Step 4: Get details for each NEW message (callouts)
            for (GmailAPIService.GmailMessage message : messagesToProcess) {
                MessageProcessingData data = new MessageProcessingData();
                data.messageId = message.id;

                // Skip if already processed
                if (alreadyProcessedIds.contains(message.id)) {
                    data.alreadyProcessed = true;
                    processedMessages.add(data);
                    continue;
                }

                data.alreadyProcessed = false;

                try {
                    // Get message details (callout)
                    data.messageDetail = GmailAPIService.getMessage(accessToken, message.id);

                    if (data.messageDetail == null) {
                        data.errorMessage = 'Failed to get message details';
                        processedMessages.add(data);
                        continue;
                    }

                    // Parse message (no callout, just processing)
                    data.recipientEmail = GmailMessageParser.extractRecipientEmail(data.messageDetail);
                    data.senderInfo = GmailMessageParser.extractSenderInfo(data.messageDetail);
                    data.subject = GmailMessageParser.getSubject(data.messageDetail);
                    data.emailBody = GmailMessageParser.getEmailBody(data.messageDetail);

                    // Check if it's a booking request
                    data.isBookingRequest = GmailMessageParser.isLikelyBookingRequest(data.subject, data.emailBody);

                    // Find location (no callout, just query)
                    data.location = LocationEmailMappingService.findLocationByEmail(data.recipientEmail);

                    // Mark message as read (callout) - only if it's a valid booking request
                    if (data.isBookingRequest && data.location != null && data.location.found) {
                        GmailAPIService.markAsRead(accessToken, message.id);
                    }

                } catch (Exception e) {
                    data.errorMessage = e.getMessage();
                    System.debug(LoggingLevel.ERROR, 'Error getting message ' + message.id + ': ' + e.getMessage());
                }

                processedMessages.add(data);
            }

            // ============================================
            // PHASE 2: DML OPERATIONS (after all callouts)
            // ============================================

            // First, save the token refresh state if needed
            if (tokenResult.stateToSave != null) {
                state = tokenResult.stateToSave;
                state.Poll_In_Progress__c = true;
                if (tokenResult.stateNeedsInsert) {
                    insert state;
                    stateExists = true;
                } else {
                    update state;
                }
            } else if (!stateExists) {
                // Create state record if it doesn't exist and wasn't created by token refresh
                state = new Gmail_Connection_State__c(
                    Name = connectionDeveloperName,
                    Connection_Developer_Name__c = connectionDeveloperName,
                    Emails_Processed_Today__c = 0,
                    Poll_In_Progress__c = true
                );
                insert state;
                stateExists = true;
            } else {
                // Mark poll as in progress
                state.Poll_In_Progress__c = true;
                update state;
            }

            // Step 5: Create log records for all messages (DML)
            List<Email_Processing_Log__c> logsToInsert = new List<Email_Processing_Log__c>();

            for (MessageProcessingData data : processedMessages) {
                // Skip already processed messages
                if (data.alreadyProcessed) {
                    System.debug('Message already processed: ' + data.messageId);
                    continue;
                }

                // Skip messages with errors getting details
                if (data.messageDetail == null) {
                    System.debug('Skipping message with error: ' + data.messageId + ' - ' + data.errorMessage);
                    continue;
                }

                // Find or create Email_Thread__c for this message
                Email_Thread__c thread = EmailThreadService.findOrCreateThread(
                    data.messageDetail.threadId,
                    data.senderInfo != null ? data.senderInfo.email : null,
                    data.senderInfo != null ? data.senderInfo.name : null,
                    data.subject,
                    data.location != null && data.location.found ? data.location.locationId : null
                );

                Email_Processing_Log__c log = new Email_Processing_Log__c();
                log.Message_Id__c = data.messageId;
                log.Thread_Id__c = data.messageDetail.threadId;
                log.Email_Thread__c = thread != null ? thread.Id : null;
                log.Sender_Email__c = data.senderInfo != null ? data.senderInfo.email : null;
                log.Sender_Name__c = data.senderInfo != null ? data.senderInfo.name : null;
                log.Recipient_Email__c = data.recipientEmail;
                log.Subject__c = data.subject;
                log.Gmail_Connection_State__c = state.Id;
                log.Response_Sent__c = false;

                if (!data.isBookingRequest) {
                    log.Processing_Status__c = 'Skipped';
                    log.Error_Message__c = 'Not a booking request';
                } else if (data.location == null || !data.location.found) {
                    log.Processing_Status__c = 'Error';
                    log.Error_Message__c = 'No matching location found for: ' + data.recipientEmail;
                    log.Booking_Request_JSON__c = data.emailBody;  // Store body for debugging
                } else {
                    log.Location__c = data.location.locationId;
                    log.Booking_Request_JSON__c = data.emailBody;
                    log.Processing_Status__c = 'Manual_Review';
                    log.Error_Message__c = 'Requires prompt template processing via Flow';
                    emailsProcessed++;
                }

                logsToInsert.add(log);
            }

            if (!logsToInsert.isEmpty()) {
                insert logsToInsert;
            }

            success = true;

        } catch (Exception e) {
            errorMessage = e.getMessage();
            System.debug(LoggingLevel.ERROR, 'Error in processSingleConnection: ' + e.getMessage());
        } finally {
            // Update state record with results
            if (state != null && state.Id != null) {
                GmailOAuthService.updateStateAfterPoll(state, newHistoryId, emailsProcessed, success, errorMessage);
            } else if (!stateExists && errorMessage != null) {
                // Create state record to store the error (use tokenResult.stateToSave if available)
                if (tokenResult != null && tokenResult.stateToSave != null) {
                    state = tokenResult.stateToSave;
                } else {
                    state = new Gmail_Connection_State__c(
                        Name = connectionDeveloperName,
                        Connection_Developer_Name__c = connectionDeveloperName,
                        Emails_Processed_Today__c = 0
                    );
                }
                state.Poll_In_Progress__c = false;
                state.Last_Error_Message__c = errorMessage;
                state.Last_Poll_Timestamp__c = DateTime.now();
                insert state;
            }
        }
    }

    /**
     * @description Processes a single email message - DEPRECATED, kept for backwards compatibility
     * Use processSingleConnection which now handles all messages in batch
     */
    @TestVisible
    private static Boolean processMessage(
        String accessToken,
        String messageId,
        Gmail_Connection__mdt connection,
        Gmail_Connection_State__c state
    ) {
        // This method is no longer used by processSingleConnection
        // All message processing is now done in batch to ensure callouts happen before DML
        return false;
    }

    /**
     * @description Creates an Email_Processing_Log__c record
     */
    private static void createProcessingLog(
        String messageId,
        String threadId,
        GmailMessageParser.SenderInfo senderInfo,
        String recipientEmail,
        String subject,
        Id locationId,
        Id gmailConnectionStateId,
        String bookingRequestJson,
        String availabilityResultJson,
        Boolean responseSent,
        String processingStatus,
        String errorMessage,
        Date checkInDate,
        Date checkOutDate,
        Integer roomsRequested,
        Integer roomsAvailable
    ) {
        try {
            Email_Processing_Log__c log = new Email_Processing_Log__c();
            log.Message_Id__c = messageId;
            log.Thread_Id__c = threadId;
            log.Sender_Email__c = senderInfo != null ? senderInfo.email : null;
            log.Sender_Name__c = senderInfo != null ? senderInfo.name : null;
            log.Recipient_Email__c = recipientEmail;
            log.Subject__c = subject;
            log.Location__c = locationId;
            log.Gmail_Connection_State__c = gmailConnectionStateId;
            log.Booking_Request_JSON__c = bookingRequestJson;
            log.Availability_Result_JSON__c = availabilityResultJson;
            log.Response_Sent__c = responseSent;
            log.Response_Date__c = responseSent ? DateTime.now() : null;
            log.Processing_Status__c = processingStatus;
            log.Error_Message__c = errorMessage;
            log.Check_In_Date__c = checkInDate;
            log.Check_Out_Date__c = checkOutDate;
            log.Rooms_Requested__c = roomsRequested;
            log.Rooms_Available__c = roomsAvailable;

            insert log;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating processing log: ' + e.getMessage());
        }
    }

    /**
     * @description Custom exception for Gmail polling errors
     */
    public class GmailPollingException extends Exception {}

    /**
     * @description Schedules the Gmail polling job at a specific minute
     * @param jobName Name for the scheduled job
     * @param minute The minute to run (0-59)
     * @return The scheduled job ID
     */
    public static String scheduleJobAtMinute(String jobName, Integer minute) {
        // Format: Seconds Minutes Hours Day_of_month Month Day_of_week
        String cronExp = '0 ' + minute + ' * * * ?';
        return System.schedule(jobName, cronExp, new GmailPollingScheduler());
    }

    /**
     * @description Schedules the Gmail polling job for every 5 minutes
     * Creates 12 scheduled jobs, one for each 5-minute interval
     * @return List of scheduled job IDs
     */
    public static List<String> scheduleEvery5Minutes() {
        return scheduleEvery5Minutes('Gmail Inbox Monitor');
    }

    /**
     * @description Schedules the Gmail polling job for every 5 minutes with custom name prefix
     * Creates 12 scheduled jobs, one for each 5-minute interval
     * @param jobNamePrefix Prefix for the scheduled job names
     * @return List of scheduled job IDs
     */
    public static List<String> scheduleEvery5Minutes(String jobNamePrefix) {
        List<String> jobIds = new List<String>();
        Integer[] minutes = new Integer[]{0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55};

        for (Integer minute : minutes) {
            String jobName = jobNamePrefix + ' - ' + String.valueOf(minute).leftPad(2, '0');
            String jobId = scheduleJobAtMinute(jobName, minute);
            jobIds.add(jobId);
        }

        return jobIds;
    }

    /**
     * @description Schedules a single Gmail polling job (hourly)
     * @param jobName Name for the scheduled job
     * @return The scheduled job ID
     */
    public static String scheduleJob(String jobName) {
        // Schedule hourly at minute 0
        return scheduleJobAtMinute(jobName, 0);
    }

    /**
     * @description Schedules a single Gmail polling job with default name (hourly)
     * @return The scheduled job ID
     */
    public static String scheduleJob() {
        return scheduleJob('Gmail Inbox Monitor');
    }

    /**
     * @description Unschedules all Gmail polling jobs
     */
    public static void unscheduleAllJobs() {
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE '%Gmail%'
        ];

        for (CronTrigger job : jobs) {
            System.abortJob(job.Id);
        }
    }
}

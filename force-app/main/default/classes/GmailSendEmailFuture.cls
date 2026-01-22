/**
 * @description Future method to send Gmail replies asynchronously
 * Uses @future instead of Queueable to avoid the "Too many queueable jobs" limit
 * when multiple emails need to be processed in the same transaction.
 *
 * @future limit is 50 per transaction vs 1 for Queueable chaining.
 */
public with sharing class GmailSendEmailFuture {

    /**
     * @description Sends a Gmail reply asynchronously using @future
     * @param logRecordId The Email_Processing_Log__c record ID to update with results
     * @param connectionDeveloperName The Gmail_Connection__mdt developer name
     * @param threadId The Gmail thread ID to reply to
     * @param toEmail The recipient email address
     * @param fromEmail The sender email address
     * @param subject The email subject
     * @param bodyHtml The HTML body of the email
     */
    @future(callout=true)
    public static void sendEmailAsync(
        Id logRecordId,
        String connectionDeveloperName,
        String threadId,
        String toEmail,
        String fromEmail,
        String subject,
        String bodyHtml
    ) {
        String errorMessage = null;
        Boolean success = false;

        try {
            // Step 1: Refresh the OAuth token
            GmailOAuthService.TokenRefreshResult tokenResult =
                GmailOAuthService.refreshAccessToken(connectionDeveloperName);

            if (!tokenResult.success) {
                errorMessage = 'Token refresh failed: ' + tokenResult.errorMessage;
                System.debug(LoggingLevel.ERROR, errorMessage);
            } else {
                // Step 2: Send the email reply
                Boolean sent = GmailAPIService.sendReply(
                    tokenResult.accessToken,
                    threadId,
                    toEmail,
                    subject,
                    bodyHtml,
                    fromEmail
                );

                if (sent) {
                    success = true;
                    System.debug('Gmail reply sent successfully to: ' + toEmail);
                } else {
                    errorMessage = 'Failed to send Gmail reply';
                    System.debug(LoggingLevel.ERROR, errorMessage);
                }
            }

        } catch (Exception e) {
            errorMessage = 'Exception in GmailSendEmailFuture: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, errorMessage);
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }

        // Step 3: Update the log record with the result
        updateLogRecord(logRecordId, success, errorMessage);
    }

    /**
     * @description Updates the Email_Processing_Log__c record with send results
     */
    private static void updateLogRecord(Id logRecordId, Boolean success, String errorMessage) {
        try {
            Email_Processing_Log__c log = new Email_Processing_Log__c(Id = logRecordId);

            if (success) {
                log.Processing_Status__c = 'Processed';
                log.Response_Sent__c = true;
                log.Response_Date__c = DateTime.now();
                log.Error_Message__c = null;
            } else {
                log.Processing_Status__c = 'Error';
                log.Error_Message__c = errorMessage;
            }

            update log;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error updating log record: ' + e.getMessage());
        }
    }
}

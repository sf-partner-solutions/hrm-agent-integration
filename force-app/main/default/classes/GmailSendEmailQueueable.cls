/**
 * @description Queueable job to send Gmail replies asynchronously
 * This is necessary because record-triggered Flows cannot make HTTP callouts
 * after DML operations in the same transaction.
 */
public with sharing class GmailSendEmailQueueable implements Queueable, Database.AllowsCallouts {

    private Id logRecordId;
    private String connectionDeveloperName;
    private String threadId;
    private String toEmail;
    private String fromEmail;
    private String subject;
    private String bodyHtml;

    /**
     * @description Constructor with all required parameters
     */
    public GmailSendEmailQueueable(
        Id logRecordId,
        String connectionDeveloperName,
        String threadId,
        String toEmail,
        String fromEmail,
        String subject,
        String bodyHtml
    ) {
        this.logRecordId = logRecordId;
        this.connectionDeveloperName = connectionDeveloperName;
        this.threadId = threadId;
        this.toEmail = toEmail;
        this.fromEmail = fromEmail;
        this.subject = subject;
        this.bodyHtml = bodyHtml;
    }

    /**
     * @description Execute method called by the Queueable framework
     */
    public void execute(QueueableContext context) {
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
            errorMessage = 'Exception in GmailSendEmailQueueable: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, errorMessage);
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }

        // Step 3: Update the log record with the result
        updateLogRecord(success, errorMessage);
    }

    /**
     * @description Updates the Email_Processing_Log__c record with send results
     */
    private void updateLogRecord(Boolean success, String errorMessage) {
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

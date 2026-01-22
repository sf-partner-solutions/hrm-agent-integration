/**
 * @description Flow-invocable action that schedules Gmail reply sending asynchronously
 * This action does NOT make HTTP callouts directly - it calls a @future method
 * that will make the callouts after the current transaction commits.
 *
 * Uses @future instead of Queueable to avoid the "Too many queueable jobs" limit
 * when multiple emails are processed in the same transaction.
 * (@future limit is 50 per transaction vs 1 for Queueable chaining)
 */
global with sharing class SendGmailReplyAsyncAction {

    global class Input {
        @InvocableVariable(label='Log Record ID' description='ID of the Email_Processing_Log__c record' required=true)
        public Id logRecordId;

        @InvocableVariable(label='Connection Developer Name' description='Developer name of Gmail_Connection__mdt' required=true)
        public String connectionDeveloperName;

        @InvocableVariable(label='Thread ID' required=true)
        public String threadId;

        @InvocableVariable(label='To Email' required=true)
        public String toEmail;

        @InvocableVariable(label='From Email' required=true)
        public String fromEmail;

        @InvocableVariable(label='Subject' required=true)
        public String subject;

        @InvocableVariable(label='Body HTML' required=true)
        public String bodyHtml;
    }

    global class Output {
        @InvocableVariable(label='Job Enqueued')
        public Boolean jobEnqueued;

        @InvocableVariable(label='Job ID')
        public String jobId;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Send Gmail Reply Async'
        description='Schedules a @future method to send Gmail reply. The log record will be updated when the email is sent.'
        category='Gmail Integration'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                // Validate required inputs
                if (input.logRecordId == null) {
                    output.jobEnqueued = false;
                    output.errorMessage = 'Log Record ID is required';
                    outputs.add(output);
                    continue;
                }

                if (String.isBlank(input.threadId) || String.isBlank(input.toEmail) ||
                    String.isBlank(input.subject) || String.isBlank(input.bodyHtml)) {
                    output.jobEnqueued = false;
                    output.errorMessage = 'Thread ID, To Email, Subject, and Body HTML are all required';
                    outputs.add(output);
                    continue;
                }

                // Call the @future method instead of enqueueing a Queueable
                // @future has a limit of 50 per transaction vs 1 for Queueable chaining
                GmailSendEmailFuture.sendEmailAsync(
                    input.logRecordId,
                    input.connectionDeveloperName,
                    input.threadId,
                    input.toEmail,
                    input.fromEmail,
                    input.subject,
                    input.bodyHtml
                );

                output.jobEnqueued = true;
                output.jobId = 'future-' + input.logRecordId; // @future doesn't return a job ID

                System.debug('Gmail send @future scheduled for log: ' + input.logRecordId);

            } catch (Exception e) {
                output.jobEnqueued = false;
                output.errorMessage = 'Failed to schedule @future: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'SendGmailReplyAsyncAction error: ' + e.getMessage());
            }

            outputs.add(output);
        }

        return outputs;
    }
}

/**
 * @description Invocable action to send Gmail reply
 */
global with sharing class GmailSendReplyAction {

    global class Input {
        @InvocableVariable(label='Access Token' required=true)
        public String accessToken;

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
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Send Gmail Reply'
        description='Sends a reply email via Gmail API'
        category='Gmail Integration'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                Boolean sent = GmailAPIService.sendReply(
                    input.accessToken,
                    input.threadId,
                    input.toEmail,
                    input.subject,
                    input.bodyHtml,
                    input.fromEmail
                );

                output.success = sent;
                if (!sent) {
                    output.errorMessage = 'Failed to send email';
                }

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = 'Exception: ' + e.getMessage();
            }

            outputs.add(output);
        }

        return outputs;
    }
}

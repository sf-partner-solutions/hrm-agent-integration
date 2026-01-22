/**
 * @description Invocable action to mark Gmail message as read
 */
global with sharing class GmailMarkReadAction {

    global class Input {
        @InvocableVariable(label='Access Token' required=true)
        public String accessToken;

        @InvocableVariable(label='Message ID' required=true)
        public String messageId;
    }

    global class Output {
        @InvocableVariable(label='Success')
        public Boolean success;
    }

    @InvocableMethod(
        label='Mark Gmail Message as Read'
        description='Marks a Gmail message as read'
        category='Gmail Integration'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();
            output.success = GmailAPIService.markAsRead(input.accessToken, input.messageId);
            outputs.add(output);
        }

        return outputs;
    }
}

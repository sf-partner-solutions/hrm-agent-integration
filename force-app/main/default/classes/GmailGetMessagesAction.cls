/**
 * @description Invocable action to get new Gmail messages
 */
global with sharing class GmailGetMessagesAction {

    global class Input {
        @InvocableVariable(label='Access Token' required=true)
        public String accessToken;

        @InvocableVariable(label='Connection Developer Name' required=true)
        public String connectionDeveloperName;

        @InvocableVariable(label='Use History API' description='Use incremental sync with historyId')
        public Boolean useHistoryApi;

        @InvocableVariable(label='Max Messages' description='Maximum messages to retrieve')
        public Integer maxMessages;
    }

    global class Output {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message Count')
        public Integer messageCount;

        @InvocableVariable(label='Message IDs JSON')
        public String messageIdsJson;

        @InvocableVariable(label='New History ID')
        public String newHistoryId;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Get New Gmail Messages'
        description='Retrieves new messages from Gmail inbox'
        category='Gmail Integration'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                Gmail_Connection_State__c state =
                    GmailOAuthService.getState(input.connectionDeveloperName);

                GmailAPIService.ListMessagesResult result;

                if (input.useHistoryApi == true && state != null &&
                    String.isNotBlank(state.Last_History_Id__c)) {
                    result = GmailAPIService.getHistoryList(
                        input.accessToken,
                        state.Last_History_Id__c
                    );
                } else {
                    Integer maxResults = input.maxMessages != null ? input.maxMessages : 10;
                    result = GmailAPIService.listMessages(
                        input.accessToken,
                        'is:unread in:inbox',
                        maxResults
                    );
                }

                output.success = result.success;
                output.messageCount = result.messages.size();
                output.newHistoryId = result.newHistoryId;
                output.errorMessage = result.errorMessage;

                List<String> messageIds = new List<String>();
                for (GmailAPIService.GmailMessage msg : result.messages) {
                    messageIds.add(msg.id);
                }
                output.messageIdsJson = JSON.serialize(messageIds);

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = 'Exception: ' + e.getMessage();
            }

            outputs.add(output);
        }

        return outputs;
    }
}

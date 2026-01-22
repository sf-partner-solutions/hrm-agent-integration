/**
 * @description Invocable action to update Gmail connection state
 */
global with sharing class GmailUpdateStateAction {

    global class Input {
        @InvocableVariable(label='Connection Developer Name' required=true)
        public String connectionDeveloperName;

        @InvocableVariable(label='New History ID')
        public String newHistoryId;

        @InvocableVariable(label='Emails Processed')
        public Integer emailsProcessed;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    global class Output {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Update Gmail Connection State'
        description='Updates the state record after polling'
        category='Gmail Integration'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                Gmail_Connection_State__c state =
                    GmailOAuthService.getState(input.connectionDeveloperName);

                if (state != null) {
                    GmailOAuthService.updateStateAfterPoll(
                        state,
                        input.newHistoryId,
                        input.emailsProcessed,
                        input.success == true,
                        input.errorMessage
                    );
                    output.success = true;
                } else {
                    output.success = false;
                    output.errorMessage = 'State record not found';
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

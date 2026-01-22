/**
 * @description Invocable action to refresh Gmail OAuth token
 */
global with sharing class GmailRefreshTokenAction {

    global class Input {
        @InvocableVariable(label='Connection Developer Name' description='Developer name of Gmail_Connection__mdt record' required=true)
        public String connectionDeveloperName;
    }

    global class Output {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Access Token')
        public String accessToken;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        @InvocableVariable(label='State Record ID')
        public String stateRecordId;
    }

    @InvocableMethod(
        label='Refresh Gmail OAuth Token'
        description='Refreshes the OAuth access token for a Gmail connection'
        category='Gmail Integration'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                GmailOAuthService.TokenRefreshResult result =
                    GmailOAuthService.refreshAccessToken(input.connectionDeveloperName);

                output.success = result.success;
                output.accessToken = result.accessToken;
                output.errorMessage = result.errorMessage;

                Gmail_Connection_State__c state =
                    GmailOAuthService.getState(input.connectionDeveloperName);
                if (state != null) {
                    output.stateRecordId = state.Id;
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

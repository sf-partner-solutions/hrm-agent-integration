/**
 * @description Service class for managing Gmail OAuth 2.0 token operations
 * Handles token refresh, validation, and storage
 */
public with sharing class GmailOAuthService {

    private static final String TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
    private static final Integer TOKEN_BUFFER_MINUTES = 5; // Refresh 5 minutes before expiry

    /**
     * @description Result wrapper for token refresh operations
     */
    public class TokenRefreshResult {
        public Boolean success;
        public String accessToken;
        public DateTime expiresAt;
        public String errorMessage;
        public Gmail_Connection_State__c stateToSave; // State record that needs to be saved by caller
        public Boolean stateNeedsInsert; // True if state needs insert, false if update

        public TokenRefreshResult() {
            this.success = false;
            this.stateNeedsInsert = false;
        }
    }

    /**
     * @description Refreshes the OAuth access token for a Gmail connection
     * IMPORTANT: This method does NOT perform any DML. The caller must save stateToSave
     * after all callouts are complete.
     * @param connectionDeveloperName The developer name of the Gmail_Connection__mdt record
     * @return TokenRefreshResult containing the new token or error details
     */
    public static TokenRefreshResult refreshAccessToken(String connectionDeveloperName) {
        TokenRefreshResult result = new TokenRefreshResult();

        try {
            // Get the connection metadata
            Gmail_Connection__mdt connection = getConnection(connectionDeveloperName);
            if (connection == null) {
                result.errorMessage = 'Gmail connection not found: ' + connectionDeveloperName;
                return result;
            }

            // Query for existing state (no DML)
            Gmail_Connection_State__c state = getState(connectionDeveloperName);
            Boolean stateExists = (state != null);

            // Check if token is still valid (only if state exists)
            if (stateExists && isTokenValid(state)) {
                result.success = true;
                result.accessToken = state.Access_Token__c;
                result.expiresAt = state.Token_Expiry__c;
                // No state changes needed
                return result;
            }

            // Refresh the token (callout - NO DML in this method)
            HttpRequest req = new HttpRequest();
            req.setEndpoint(TOKEN_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            String body = 'client_id=' + EncodingUtil.urlEncode(connection.Client_Id__c, 'UTF-8') +
                         '&client_secret=' + EncodingUtil.urlEncode(connection.Client_Secret__c, 'UTF-8') +
                         '&refresh_token=' + EncodingUtil.urlEncode(connection.Refresh_Token__c, 'UTF-8') +
                         '&grant_type=refresh_token';
            req.setBody(body);
            req.setTimeout(30000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            // Prepare state record (but do NOT save it - caller will handle DML)
            if (!stateExists) {
                state = new Gmail_Connection_State__c(
                    Name = connectionDeveloperName,
                    Connection_Developer_Name__c = connectionDeveloperName,
                    Emails_Processed_Today__c = 0,
                    Poll_In_Progress__c = false
                );
                result.stateNeedsInsert = true;
            } else {
                result.stateNeedsInsert = false;
            }

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                String newAccessToken = (String) responseMap.get('access_token');
                Integer expiresIn = (Integer) responseMap.get('expires_in');

                // Calculate expiry time
                DateTime expiresAt = DateTime.now().addSeconds(expiresIn);

                // Prepare the state record with new token (NO DML here)
                state.Access_Token__c = newAccessToken;
                state.Token_Expiry__c = expiresAt;
                state.Last_Error_Message__c = null;

                result.success = true;
                result.accessToken = newAccessToken;
                result.expiresAt = expiresAt;
                result.stateToSave = state; // Caller must save this after all callouts
            } else {
                result.errorMessage = 'Token refresh failed: ' + res.getStatusCode() + ' - ' + res.getBody();

                // Prepare error state (NO DML here)
                state.Last_Error_Message__c = result.errorMessage;
                result.stateToSave = state; // Caller must save this after all callouts
            }

        } catch (Exception e) {
            result.errorMessage = 'Exception during token refresh: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'Token refresh error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }

        return result;
    }

    /**
     * @description Checks if the current access token is valid
     * @param state The Gmail_Connection_State__c record
     * @return True if token is valid for at least TOKEN_BUFFER_MINUTES
     */
    public static Boolean isTokenValid(Gmail_Connection_State__c state) {
        if (state == null || String.isBlank(state.Access_Token__c) || state.Token_Expiry__c == null) {
            return false;
        }

        // Check if token expires within buffer period
        DateTime bufferTime = DateTime.now().addMinutes(TOKEN_BUFFER_MINUTES);
        return state.Token_Expiry__c > bufferTime;
    }

    /**
     * @description Gets the Gmail_Connection__mdt record by developer name
     * @param developerName The developer name of the connection
     * @return The Gmail_Connection__mdt record or null
     */
    public static Gmail_Connection__mdt getConnection(String developerName) {
        List<Gmail_Connection__mdt> connections = [
            SELECT DeveloperName, MasterLabel, Mailbox_Email__c, Client_Id__c,
                   Client_Secret__c, Refresh_Token__c, Location_Id__c, Is_Active__c
            FROM Gmail_Connection__mdt
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];

        return connections.isEmpty() ? null : connections[0];
    }

    /**
     * @description Gets all active Gmail connections
     * @return List of active Gmail_Connection__mdt records
     */
    public static List<Gmail_Connection__mdt> getActiveConnections() {
        return [
            SELECT DeveloperName, MasterLabel, Mailbox_Email__c, Client_Id__c,
                   Client_Secret__c, Refresh_Token__c, Location_Id__c, Is_Active__c
            FROM Gmail_Connection__mdt
            WHERE Is_Active__c = true
        ];
    }

    /**
     * @description Gets or creates the state record for a connection
     * @param connectionDeveloperName The developer name of the connection
     * @return The Gmail_Connection_State__c record
     */
    public static Gmail_Connection_State__c getOrCreateState(String connectionDeveloperName) {
        List<Gmail_Connection_State__c> states = [
            SELECT Id, Name, Connection_Developer_Name__c, Access_Token__c,
                   Token_Expiry__c, Last_Poll_Timestamp__c, Last_History_Id__c,
                   Last_Error_Message__c, Last_Successful_Poll__c,
                   Emails_Processed_Today__c, Poll_In_Progress__c
            FROM Gmail_Connection_State__c
            WHERE Connection_Developer_Name__c = :connectionDeveloperName
            LIMIT 1
        ];

        if (!states.isEmpty()) {
            return states[0];
        }

        // Create new state record
        Gmail_Connection_State__c newState = new Gmail_Connection_State__c(
            Name = connectionDeveloperName,
            Connection_Developer_Name__c = connectionDeveloperName,
            Emails_Processed_Today__c = 0,
            Poll_In_Progress__c = false
        );
        insert newState;
        return newState;
    }

    /**
     * @description Gets the state record by connection developer name
     * @param connectionDeveloperName The developer name of the connection
     * @return The Gmail_Connection_State__c record or null
     */
    public static Gmail_Connection_State__c getState(String connectionDeveloperName) {
        List<Gmail_Connection_State__c> states = [
            SELECT Id, Name, Connection_Developer_Name__c, Access_Token__c,
                   Token_Expiry__c, Last_Poll_Timestamp__c, Last_History_Id__c,
                   Last_Error_Message__c, Last_Successful_Poll__c,
                   Emails_Processed_Today__c, Poll_In_Progress__c
            FROM Gmail_Connection_State__c
            WHERE Connection_Developer_Name__c = :connectionDeveloperName
            LIMIT 1
        ];

        return states.isEmpty() ? null : states[0];
    }

    /**
     * @description Updates the state record after a polling operation
     * @param state The state record to update
     * @param newHistoryId The new Gmail history ID
     * @param emailsProcessed Number of emails processed in this poll
     * @param success Whether the poll was successful
     * @param errorMessage Error message if poll failed
     */
    public static void updateStateAfterPoll(
        Gmail_Connection_State__c state,
        String newHistoryId,
        Integer emailsProcessed,
        Boolean success,
        String errorMessage
    ) {
        state.Last_Poll_Timestamp__c = DateTime.now();
        state.Poll_In_Progress__c = false;

        if (success) {
            if (String.isNotBlank(newHistoryId)) {
                state.Last_History_Id__c = newHistoryId;
            }
            state.Last_Successful_Poll__c = DateTime.now();
            state.Last_Error_Message__c = null;
            if (emailsProcessed != null && emailsProcessed > 0) {
                state.Emails_Processed_Today__c =
                    (state.Emails_Processed_Today__c != null ? state.Emails_Processed_Today__c : 0) + emailsProcessed;
            }
        } else {
            state.Last_Error_Message__c = errorMessage;
        }

        update state;
    }
}

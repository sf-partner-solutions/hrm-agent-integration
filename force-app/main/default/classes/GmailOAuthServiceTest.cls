/**
 * @description Test class for GmailOAuthService
 * Tests OAuth token refresh and state management
 */
@isTest
private class GmailOAuthServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create a Gmail Connection State record for testing
        Gmail_Connection_State__c state = new Gmail_Connection_State__c(
            Name = 'Test_Connection',
            Connection_Developer_Name__c = 'Test_Connection',
            Access_Token__c = 'test_access_token',
            Token_Expiry__c = DateTime.now().addHours(1),
            Emails_Processed_Today__c = 0,
            Poll_In_Progress__c = false
        );
        insert state;
    }

    /**
     * @description Mock class for successful token refresh
     */
    private class SuccessfulTokenRefreshMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"access_token": "new_access_token_123", "expires_in": 3600, "token_type": "Bearer"}');
            return res;
        }
    }

    /**
     * @description Mock class for failed token refresh
     */
    private class FailedTokenRefreshMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(401);
            res.setBody('{"error": "invalid_grant", "error_description": "Token has been revoked"}');
            return res;
        }
    }

    @isTest
    static void testIsTokenValid_ValidToken() {
        Gmail_Connection_State__c state = new Gmail_Connection_State__c(
            Access_Token__c = 'test_token',
            Token_Expiry__c = DateTime.now().addHours(1)
        );

        Test.startTest();
        Boolean isValid = GmailOAuthService.isTokenValid(state);
        Test.stopTest();

        System.assertEquals(true, isValid, 'Token should be valid when expiry is in the future');
    }

    @isTest
    static void testIsTokenValid_ExpiredToken() {
        Gmail_Connection_State__c state = new Gmail_Connection_State__c(
            Access_Token__c = 'test_token',
            Token_Expiry__c = DateTime.now().addMinutes(-10)
        );

        Test.startTest();
        Boolean isValid = GmailOAuthService.isTokenValid(state);
        Test.stopTest();

        System.assertEquals(false, isValid, 'Token should be invalid when expiry is in the past');
    }

    @isTest
    static void testIsTokenValid_TokenAboutToExpire() {
        Gmail_Connection_State__c state = new Gmail_Connection_State__c(
            Access_Token__c = 'test_token',
            Token_Expiry__c = DateTime.now().addMinutes(2) // Less than 5 minute buffer
        );

        Test.startTest();
        Boolean isValid = GmailOAuthService.isTokenValid(state);
        Test.stopTest();

        System.assertEquals(false, isValid, 'Token should be invalid when expiring within buffer period');
    }

    @isTest
    static void testIsTokenValid_NullState() {
        Test.startTest();
        Boolean isValid = GmailOAuthService.isTokenValid(null);
        Test.stopTest();

        System.assertEquals(false, isValid, 'Null state should return invalid');
    }

    @isTest
    static void testIsTokenValid_BlankToken() {
        Gmail_Connection_State__c state = new Gmail_Connection_State__c(
            Access_Token__c = '',
            Token_Expiry__c = DateTime.now().addHours(1)
        );

        Test.startTest();
        Boolean isValid = GmailOAuthService.isTokenValid(state);
        Test.stopTest();

        System.assertEquals(false, isValid, 'Blank token should return invalid');
    }

    @isTest
    static void testGetOrCreateState_ExistingState() {
        Test.startTest();
        Gmail_Connection_State__c state = GmailOAuthService.getOrCreateState('Test_Connection');
        Test.stopTest();

        System.assertNotEquals(null, state, 'Should return existing state');
        System.assertEquals('Test_Connection', state.Connection_Developer_Name__c, 'Should return correct state');
    }

    @isTest
    static void testGetOrCreateState_NewState() {
        Test.startTest();
        Gmail_Connection_State__c state = GmailOAuthService.getOrCreateState('New_Connection');
        Test.stopTest();

        System.assertNotEquals(null, state, 'Should create new state');
        System.assertEquals('New_Connection', state.Connection_Developer_Name__c, 'Should have correct developer name');
        System.assertNotEquals(null, state.Id, 'Should be inserted');
    }

    @isTest
    static void testGetState_ExistingState() {
        Test.startTest();
        Gmail_Connection_State__c state = GmailOAuthService.getState('Test_Connection');
        Test.stopTest();

        System.assertNotEquals(null, state, 'Should return existing state');
    }

    @isTest
    static void testGetState_NonExistentState() {
        Test.startTest();
        Gmail_Connection_State__c state = GmailOAuthService.getState('Nonexistent_Connection');
        Test.stopTest();

        System.assertEquals(null, state, 'Should return null for non-existent state');
    }

    @isTest
    static void testUpdateStateAfterPoll_Success() {
        Gmail_Connection_State__c state = [
            SELECT Id, Connection_Developer_Name__c, Last_History_Id__c,
                   Emails_Processed_Today__c, Last_Successful_Poll__c,
                   Last_Error_Message__c, Poll_In_Progress__c
            FROM Gmail_Connection_State__c
            WHERE Connection_Developer_Name__c = 'Test_Connection'
            LIMIT 1
        ];
        state.Poll_In_Progress__c = true;
        update state;

        Test.startTest();
        GmailOAuthService.updateStateAfterPoll(state, 'history123', 5, true, null);
        Test.stopTest();

        Gmail_Connection_State__c updatedState = [
            SELECT Last_History_Id__c, Emails_Processed_Today__c,
                   Last_Successful_Poll__c, Last_Error_Message__c, Poll_In_Progress__c
            FROM Gmail_Connection_State__c
            WHERE Id = :state.Id
        ];

        System.assertEquals('history123', updatedState.Last_History_Id__c, 'History ID should be updated');
        System.assertEquals(5, updatedState.Emails_Processed_Today__c, 'Emails processed should be updated');
        System.assertNotEquals(null, updatedState.Last_Successful_Poll__c, 'Last successful poll should be set');
        System.assertEquals(null, updatedState.Last_Error_Message__c, 'Error message should be cleared');
        System.assertEquals(false, updatedState.Poll_In_Progress__c, 'Poll in progress should be false');
    }

    @isTest
    static void testUpdateStateAfterPoll_Failure() {
        Gmail_Connection_State__c state = [
            SELECT Id, Connection_Developer_Name__c, Last_History_Id__c,
                   Emails_Processed_Today__c, Last_Successful_Poll__c,
                   Last_Error_Message__c, Poll_In_Progress__c
            FROM Gmail_Connection_State__c
            WHERE Connection_Developer_Name__c = 'Test_Connection'
            LIMIT 1
        ];

        Test.startTest();
        GmailOAuthService.updateStateAfterPoll(state, null, 0, false, 'Test error message');
        Test.stopTest();

        Gmail_Connection_State__c updatedState = [
            SELECT Last_Error_Message__c, Poll_In_Progress__c
            FROM Gmail_Connection_State__c
            WHERE Id = :state.Id
        ];

        System.assertEquals('Test error message', updatedState.Last_Error_Message__c, 'Error message should be set');
        System.assertEquals(false, updatedState.Poll_In_Progress__c, 'Poll in progress should be false');
    }

    @isTest
    static void testRefreshAccessToken_ConnectionNotFound() {
        Test.startTest();
        GmailOAuthService.TokenRefreshResult result =
            GmailOAuthService.refreshAccessToken('Nonexistent_Connection');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail for non-existent connection');
        System.assert(result.errorMessage.contains('not found'), 'Error should mention not found');
    }

    @isTest
    static void testGetActiveConnections() {
        // This test verifies the method doesn't throw errors
        // Actual results depend on Custom Metadata which can't be created in tests
        Test.startTest();
        List<Gmail_Connection__mdt> connections = GmailOAuthService.getActiveConnections();
        Test.stopTest();

        // Just verify it returns a list (may be empty)
        System.assertNotEquals(null, connections, 'Should return a list');
    }

    @isTest
    static void testGetConnection_NotFound() {
        Test.startTest();
        Gmail_Connection__mdt connection = GmailOAuthService.getConnection('Nonexistent');
        Test.stopTest();

        System.assertEquals(null, connection, 'Should return null for non-existent connection');
    }
}

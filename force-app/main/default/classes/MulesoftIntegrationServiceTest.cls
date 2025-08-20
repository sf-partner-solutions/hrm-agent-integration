@isTest
private class MulesoftIntegrationServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Custom Settings will use hierarchy so no test data needed for that
        // Custom Metadata is automatically available in tests
    }
    
    @isTest
    static void testInitiateApiLogin() {
        Test.startTest();
        MulesoftIntegrationService.AuthResponse result = MulesoftIntegrationService.initiateApiLogin();
        Test.stopTest();
        
        System.assert(result.success, 'Initiate API login should succeed');
        System.assert(result.authUrl.contains('partnerapiwebauth-20c01287ca0d.herokuapp.com'), 'Auth URL should contain correct domain');
        System.assert(result.authUrl.contains(UserInfo.getUserId()), 'Auth URL should contain user ID');
    }
    
    @isTest
    static void testCheckApiConnectionWithoutToken() {
        Test.startTest();
        MulesoftIntegrationService.ConnectionResponse result = MulesoftIntegrationService.checkApiConnection();
        Test.stopTest();
        
        System.assert(!result.isConnected, 'Should not be connected without token');
    }
    
    @isTest
    static void testIsUserAuthenticatedWithoutToken() {
        Test.startTest();
        Boolean isAuth = MulesoftIntegrationService.isUserAuthenticated();
        Test.stopTest();
        
        System.assertEquals(false, isAuth, 'User should not be authenticated without token');
    }
    
    @isTest
    static void testHandleAuthCallback() {
        String testToken = 'test-token-123';
        String currentUserId = UserInfo.getUserId();
        
        Test.startTest();
        MulesoftIntegrationService.AuthResponse result = MulesoftIntegrationService.handleAuthCallback(testToken, currentUserId);
        Test.stopTest();
        
        System.assert(result.success, 'Auth callback should succeed');
        
        // Verify token was stored
        API_Token__c storedToken = API_Token__c.getValues(currentUserId);
        System.assertNotEquals(null, storedToken, 'Token should be stored');
        System.assertEquals(testToken, storedToken.access_token__c, 'Stored token should match input');
        System.assertEquals(true, storedToken.Is_Active__c, 'Token should be active');
    }
    
    @isTest
    static void testCheckApiConnectionWithToken() {
        String testToken = 'test-token-123';
        String currentUserId = UserInfo.getUserId();
        
        // Set up token first
        MulesoftIntegrationService.handleAuthCallback(testToken, currentUserId);
        
        Test.startTest();
        MulesoftIntegrationService.ConnectionResponse result = MulesoftIntegrationService.checkApiConnection();
        Test.stopTest();
        
        System.assert(result.isConnected, 'Should be connected with valid token');
    }
    
    @isTest
    static void testIsUserAuthenticatedWithToken() {
        String testToken = 'test-token-123';
        String currentUserId = UserInfo.getUserId();
        
        // Set up token first
        MulesoftIntegrationService.handleAuthCallback(testToken, currentUserId);
        
        Test.startTest();
        Boolean isAuth = MulesoftIntegrationService.isUserAuthenticated();
        Test.stopTest();
        
        System.assertEquals(true, isAuth, 'User should be authenticated with valid token');
    }
    
    @isTest
    static void testDisconnectApi() {
        String testToken = 'test-token-123';
        String currentUserId = UserInfo.getUserId();
        
        // Set up token first
        MulesoftIntegrationService.handleAuthCallback(testToken, currentUserId);
        
        Test.startTest();
        MulesoftIntegrationService.AuthResponse result = MulesoftIntegrationService.disconnectApi();
        Test.stopTest();
        
        System.assert(result.success, 'Disconnect should succeed');
        
        // Verify token is inactive
        API_Token__c storedToken = API_Token__c.getValues(currentUserId);
        System.assertEquals(false, storedToken.Is_Active__c, 'Token should be inactive after disconnect');
        System.assertNotEquals(null, storedToken.Disconnected_Date__c, 'Disconnect date should be set');
    }
    
    @isTest
    static void testPollAuthStatus() {
        String testToken = 'test-token-123';
        String currentUserId = UserInfo.getUserId();
        String sessionId = 'test-session-123';
        
        // Test without token - should return false
        Test.startTest();
        MulesoftIntegrationService.ConnectionResponse result = MulesoftIntegrationService.pollAuthStatus(sessionId);
        System.assertEquals(false, result.isConnected, 'Should not be connected without recent token');
        
        // Set up recent token
        MulesoftIntegrationService.handleAuthCallback(testToken, currentUserId);
        
        // Test with recent token - should return true
        result = MulesoftIntegrationService.pollAuthStatus(sessionId);
        System.assertEquals(true, result.isConnected, 'Should be connected with recent token');
        Test.stopTest();
    }
    
    @isTest
    static void testAuthenticateUserSuccess() {
        // Create mock response for successful authentication
        Test.setMock(HttpCalloutMock.class, new MockSuccessfulAuth());
        
        String authData = '{"username":"test","password":"test"}';
        
        Test.startTest();
        MulesoftIntegrationService.AuthResponse result = MulesoftIntegrationService.authenticateUser(authData);
        Test.stopTest();
        
        System.assert(result.success, 'Authentication should succeed');
        System.assertNotEquals(null, result.token, 'Token should be returned');
        
        // Verify token was stored in custom setting
        API_Token__c storedToken = API_Token__c.getValues(UserInfo.getUserId());
        System.assertNotEquals(null, storedToken, 'Token should be stored');
        System.assertEquals('test_access_token', storedToken.access_token__c);
        System.assertEquals(true, storedToken.Is_Active__c);
    }
    
    @isTest
    static void testAuthenticateUserFailure() {
        // Create mock response for failed authentication
        Test.setMock(HttpCalloutMock.class, new MockFailedAuth());
        
        String authData = '{"username":"invalid","password":"invalid"}';
        
        Test.startTest();
        MulesoftIntegrationService.AuthResponse result = MulesoftIntegrationService.authenticateUser(authData);
        Test.stopTest();
        
        System.assert(!result.success, 'Authentication should fail');
        System.assert(result.message.contains('Authentication failed'), 'Should contain error message');
    }
    
    @isTest
    static void testCallApiWithUserTokenSuccess() {
        String testToken = 'test-token-123';
        String currentUserId = UserInfo.getUserId();
        
        // Set up token first
        MulesoftIntegrationService.handleAuthCallback(testToken, currentUserId);
        
        // Create mock response for successful API call
        Test.setMock(HttpCalloutMock.class, new MockSuccessfulApiCall());
        
        Test.startTest();
        String result = MulesoftIntegrationService.callApiWithUserToken('/test-endpoint', '{"data":"test"}');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return API response');
        System.assert(result.contains('success'), 'Should contain success response');
    }
    
    @isTest
    static void testCallApiWithUserTokenNoAuth() {
        // No token setup - should fail
        
        Test.startTest();
        try {
            String result = MulesoftIntegrationService.callApiWithUserToken('/test-endpoint', '{"data":"test"}');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not authenticated'), 'Should indicate not authenticated');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCallApiGetWithUserTokenSuccess() {
        String testToken = 'test-token-123';
        String currentUserId = UserInfo.getUserId();
        
        // Set up token first
        MulesoftIntegrationService.handleAuthCallback(testToken, currentUserId);
        
        // Create mock response for successful API call
        Test.setMock(HttpCalloutMock.class, new MockSuccessfulApiCall());
        
        Test.startTest();
        String result = MulesoftIntegrationService.callApiGetWithUserToken('/test-endpoint');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return API response');
        System.assert(result.contains('success'), 'Should contain success response');
    }
    
    @isTest
    static void testTokenExpired() {
        String currentUserId = UserInfo.getUserId();
        
        // Setup expired token
        API_Token__c tokenSetting = new API_Token__c(Name = currentUserId);
        tokenSetting.access_token__c = 'expired_token';
        tokenSetting.expires_at__c = System.now().addHours(-1); // Expired
        tokenSetting.Is_Active__c = true;
        upsert tokenSetting;
        
        Test.startTest();
        Boolean isAuth = MulesoftIntegrationService.isUserAuthenticated();
        Test.stopTest();
        
        System.assertEquals(false, isAuth, 'Expired token should not be authenticated');
    }
    
    @isTest
    static void testHandleAuthCallbackWithInvalidUserId() {
        String testToken = 'test-token-123';
        String invalidUserId = 'invalid-user-id';
        
        Test.startTest();
        MulesoftIntegrationService.AuthResponse result = MulesoftIntegrationService.handleAuthCallback(testToken, invalidUserId);
        Test.stopTest();
        
        System.assert(!result.success, 'Auth callback should fail with invalid user ID');
        System.assert(result.message.contains('User ID mismatch'), 'Should indicate user ID mismatch');
    }
    
    @isTest
    static void testHandleAuthCallbackWithEmptyToken() {
        String currentUserId = UserInfo.getUserId();
        
        Test.startTest();
        MulesoftIntegrationService.AuthResponse result = MulesoftIntegrationService.handleAuthCallback('', currentUserId);
        Test.stopTest();
        
        System.assert(!result.success, 'Auth callback should fail with empty token');
    }
    
    // Mock classes for testing
    public class MockSuccessfulAuth implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            response.setBody('{"access_token":"test_access_token","refresh_token":"test_refresh_token","token_type":"Bearer","expires_in":3600,"user_id":"test_user","client_id":"test_client"}');
            return response;
        }
    }
    
    public class MockFailedAuth implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(401);
            response.setBody('{"error": "Invalid credentials"}');
            return response;
        }
    }
    
    public class MockSuccessfulApiCall implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            response.setBody('{"status": "success", "data": "test response"}');
            return response;
        }
    }
    
    public class MockApiCallUnauthorized implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(401);
            response.setBody('{"error": "Unauthorized"}');
            return response;
        }
    }
}
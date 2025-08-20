@isTest
private class ApiLoginControllerTest {
    
    @isTest
    static void testInitiateApiLogin() {
        Test.startTest();
        ApiLoginController.AuthResponse response = ApiLoginController.initiateApiLogin();
        Test.stopTest();
        
        System.assert(response.success, 'Initiate API login should succeed');
        System.assert(response.authUrl.contains('partnerapiwebauth-20c01287ca0d.herokuapp.com'), 'Auth URL should contain correct domain');
        System.assert(response.authUrl.contains(UserInfo.getUserId()), 'Auth URL should contain user ID');
    }
    
    @isTest
    static void testCheckApiConnectionWithoutToken() {
        Test.startTest();
        ApiLoginController.ConnectionResponse response = ApiLoginController.checkApiConnection();
        Test.stopTest();
        
        System.assert(!response.isConnected, 'Should not be connected without token');
    }
    
    @isTest
    static void testHandleAuthCallback() {
        String testToken = 'test-token-123';
        String currentUserId = UserInfo.getUserId();
        
        Test.startTest();
        ApiLoginController.AuthResponse response = ApiLoginController.handleAuthCallback(testToken, currentUserId);
        Test.stopTest();
        
        System.assert(response.success, 'Auth callback should succeed');
        
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
        ApiLoginController.handleAuthCallback(testToken, currentUserId);
        
        Test.startTest();
        ApiLoginController.ConnectionResponse response = ApiLoginController.checkApiConnection();
        Test.stopTest();
        
        System.assert(response.isConnected, 'Should be connected with valid token');
    }
    
    @isTest
    static void testDisconnectApi() {
        String testToken = 'test-token-123';
        String currentUserId = UserInfo.getUserId();
        
        // Set up token first
        ApiLoginController.handleAuthCallback(testToken, currentUserId);
        
        Test.startTest();
        ApiLoginController.AuthResponse response = ApiLoginController.disconnectApi();
        Test.stopTest();
        
        System.assert(response.success, 'Disconnect should succeed');
        
        // Verify token is inactive
        API_Token__c storedToken = API_Token__c.getValues(currentUserId);
        System.assertEquals(false, storedToken.Is_Active__c, 'Token should be inactive after disconnect');
        System.assertNotEquals(null, storedToken.Disconnected_Date__c, 'Disconnect date should be set');
    }
    
    @isTest
    static void testGetApiToken() {
        String testToken = 'test-token-123';
        String currentUserId = UserInfo.getUserId();
        
        // Test without token
        Test.startTest();
        String retrievedToken = ApiLoginController.getApiToken();
        System.assertEquals(null, retrievedToken, 'Should return null when no token exists');
        
        // Set up token
        ApiLoginController.handleAuthCallback(testToken, currentUserId);
        
        // Test with token
        retrievedToken = ApiLoginController.getApiToken();
        System.assertEquals(testToken, retrievedToken, 'Should return stored token');
        Test.stopTest();
    }
    
    @isTest
    static void testValidateApiToken() {
        String testToken = 'test-token-123';
        String currentUserId = UserInfo.getUserId();
        
        // Test without token
        Test.startTest();
        ApiLoginController.AuthResponse response = ApiLoginController.validateApiToken();
        System.assert(!response.success, 'Validation should fail when no token exists');
        
        // Set up token
        ApiLoginController.handleAuthCallback(testToken, currentUserId);
        
        // Test with token
        response = ApiLoginController.validateApiToken();
        System.assert(response.success, 'Validation should succeed with valid token');
        Test.stopTest();
    }
    
    @isTest
    static void testHandleAuthCallbackWithInvalidUserId() {
        String testToken = 'test-token-123';
        String invalidUserId = 'invalid-user-id';
        
        Test.startTest();
        ApiLoginController.AuthResponse response = ApiLoginController.handleAuthCallback(testToken, invalidUserId);
        Test.stopTest();
        
        System.assert(!response.success, 'Auth callback should fail with invalid user ID');
        System.assert(response.message.contains('User ID mismatch'), 'Should indicate user ID mismatch');
    }
    
    @isTest
    static void testHandleAuthCallbackWithEmptyToken() {
        String currentUserId = UserInfo.getUserId();
        
        Test.startTest();
        ApiLoginController.AuthResponse response = ApiLoginController.handleAuthCallback('', currentUserId);
        Test.stopTest();
        
        System.assert(!response.success, 'Auth callback should fail with empty token');
    }
}
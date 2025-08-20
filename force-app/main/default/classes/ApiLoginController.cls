public with sharing class ApiLoginController {
    
    private static final String API_LOGIN_URL = 'https://partnerapiwebauth-20c01287ca0d.herokuapp.com';
    private static final String API_BASE_URL = 'https://employee-api-jtx6w5.5sc6y6-2.usa-e2.cloudhub.io';
    private static final String API_LOGIN_ENDPOINT = '/auth/login';
    
    @AuraEnabled
    public static AuthResponse initiateApiLogin() {
        try {
            String currentUserId = UserInfo.getUserId();
            String authUrl = API_LOGIN_URL + '?userId=' + EncodingUtil.urlEncode(currentUserId, 'UTF-8');
            
            return new AuthResponse(true, 'Authentication initiated successfully', authUrl);
        } catch (Exception e) {
            System.debug('Error initiating API login: ' + e.getMessage());
            return new AuthResponse(false, 'Failed to initiate authentication: ' + e.getMessage(), null);
        }
    }
    
    @AuraEnabled
    public static ConnectionResponse checkApiConnection() {
        try {
            String currentUserId = UserInfo.getUserId();
            
            // Check if API token exists in custom setting for current user
            API_Token__c apiToken = API_Token__c.getValues(currentUserId);
            
            boolean isConnected = (apiToken != null && 
                                 String.isNotBlank(apiToken.access_token__c) && 
                                 apiToken.Is_Active__c == true);
            
            return new ConnectionResponse(isConnected, isConnected ? 'API is connected' : 'API is not connected');
        } catch (Exception e) {
            System.debug('Error checking API connection: ' + e.getMessage());
            return new ConnectionResponse(false, 'Error checking connection status');
        }
    }
    
    @AuraEnabled
    public static AuthResponse disconnectApi() {
        try {
            String currentUserId = UserInfo.getUserId();
            
            // Get existing token record
            API_Token__c apiToken = API_Token__c.getValues(currentUserId);
            
            if (apiToken != null) {
                // Mark as inactive instead of deleting
                apiToken.Is_Active__c = false;
                apiToken.Disconnected_Date__c = System.now();
                
                upsert apiToken;
            }
            
            return new AuthResponse(true, 'API disconnected successfully', null);
        } catch (Exception e) {
            System.debug('Error disconnecting API: ' + e.getMessage());
            return new AuthResponse(false, 'Failed to disconnect: ' + e.getMessage(), null);
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static AuthResponse handleAuthCallback(String token, String userId) {
        try {
            // Validate inputs
            if (String.isBlank(token) || String.isBlank(userId)) {
                return new AuthResponse(false, 'Invalid token or user ID provided', null);
            }
            
            // Verify the userId matches the current user (security check)
            if (userId != UserInfo.getUserId()) {
                return new AuthResponse(false, 'User ID mismatch - security violation', null);
            }
            
            // Create or update API token record
            API_Token__c apiToken = API_Token__c.getValues(userId);
            if (apiToken == null) {
                apiToken = new API_Token__c(Name = userId);
            }
            
            apiToken.access_token__c = token;
            apiToken.Is_Active__c = true;
            apiToken.Connected_Date__c = System.now();
            apiToken.Last_Updated__c = System.now();
            
            upsert apiToken;
            
            return new AuthResponse(true, 'Authentication completed successfully', null);
        } catch (Exception e) {
            System.debug('Error handling auth callback: ' + e.getMessage());
            return new AuthResponse(false, 'Failed to store authentication token: ' + e.getMessage(), null);
        }
    }
    
    @AuraEnabled
    public static String getApiToken() {
        try {
            String currentUserId = UserInfo.getUserId();
            API_Token__c apiToken = API_Token__c.getValues(currentUserId);
            
            if (apiToken != null && apiToken.Is_Active__c == true) {
                return apiToken.access_token__c;
            }
            
            return null;
        } catch (Exception e) {
            System.debug('Error getting API token: ' + e.getMessage());
            return null;
        }
    }
    
    // Method to poll for authentication completion
    @AuraEnabled(cacheable=false)
    public static ConnectionResponse pollAuthStatus(String sessionId) {
        try {
            String currentUserId = UserInfo.getUserId();
            API_Token__c apiToken = API_Token__c.getValues(currentUserId);
            
            // Check if a new token was recently added (within last 5 minutes)
            if (apiToken != null && 
                apiToken.Is_Active__c == true && 
                apiToken.Connected_Date__c != null &&
                apiToken.Connected_Date__c > System.now().addMinutes(-5)) {
                
                return new ConnectionResponse(true, 'Authentication completed successfully');
            }
            
            return new ConnectionResponse(false, 'Authentication still in progress');
        } catch (Exception e) {
            System.debug('Error polling auth status: ' + e.getMessage());
            return new ConnectionResponse(false, 'Error checking authentication status');
        }
    }
    
    // Web service method for external callback
    @RemoteAction
    public static String handleExternalCallback(String token, String userId) {
        try {
            AuthResponse response = handleAuthCallback(token, userId);
            return JSON.serialize(response);
        } catch (Exception e) {
            System.debug('Error in external callback: ' + e.getMessage());
            return JSON.serialize(new AuthResponse(false, 'Callback processing failed: ' + e.getMessage(), null));
        }
    }
    
    // Test method to validate API token
    @AuraEnabled
    public static AuthResponse validateApiToken() {
        try {
            String token = getApiToken();
            
            if (String.isBlank(token)) {
                return new AuthResponse(false, 'No active API token found', null);
            }
            
            // You can add actual API validation call here if needed
            // For now, we'll just check if the token exists
            
            return new AuthResponse(true, 'API token is valid', null);
        } catch (Exception e) {
            System.debug('Error validating API token: ' + e.getMessage());
            return new AuthResponse(false, 'Failed to validate token: ' + e.getMessage(), null);
        }
    }
    
    // Wrapper classes for responses
    public class AuthResponse {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String authUrl { get; set; }
        
        public AuthResponse(Boolean success, String message, String authUrl) {
            this.success = success;
            this.message = message;
            this.authUrl = authUrl;
        }
    }
    
    public class ConnectionResponse {
        @AuraEnabled public Boolean isConnected { get; set; }
        @AuraEnabled public String message { get; set; }
        
        public ConnectionResponse(Boolean isConnected, String message) {
            this.isConnected = isConnected;
            this.message = message;
        }
    }
}
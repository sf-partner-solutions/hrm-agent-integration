public with sharing class MulesoftIntegrationService {
    private static final String NAMED_CREDENTIAL = 'callout:Mulesoft_API_Endpoint';
    
    @AuraEnabled
    public static AuthResponse authenticateUser(String authData) {
        try {
            Integration_Setting__mdt settings = getIntegrationSettings();
            
            // Initial authentication request (no user token needed)
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL + '/auth/login');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(authData);
            req.setTimeout(Integer.valueOf(settings.Timeout__c));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                return processAuthResponse(res.getBody());
            } else {
                return new AuthResponse(false, 'Authentication failed: ' + res.getStatusCode(), null);
            }
        } catch (Exception e) {
            System.debug('Authentication error: ' + e.getMessage());
            return new AuthResponse(false, 'Authentication failed: ' + e.getMessage(), null);
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> initiateApiLogin() {
        try {
            String currentUserId = UserInfo.getUserId();
            String authUrl = 'https://partnerapiwebauth-20c01287ca0d.herokuapp.com?userId=' + EncodingUtil.urlEncode(currentUserId, 'UTF-8') + '&clientId=' + EncodingUtil.urlEncode(currentUserId, 'UTF-8');
            
            System.debug('Generated auth URL: ' + authUrl);
            System.debug('Current user ID: ' + currentUserId);
            
            return new Map<String, Object>{
                'success' => true,
                'message' => 'Authentication initiated successfully',
                'authUrl' => authUrl
            };
        } catch (Exception e) {
            System.debug('Error initiating API login: ' + e.getMessage());
            return new Map<String, Object>{
                'success' => false,
                'message' => 'Failed to initiate authentication: ' + e.getMessage()
            };
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> authenticateWithCredentials(String username, String password) {
        try {
            String currentUserId = UserInfo.getUserId();
            
            // Create authentication request body
            Map<String, Object> authRequest = new Map<String, Object>{
                'username' => username,
                'password' => password,
                'clientId' => currentUserId
            };
            
            System.debug('Authentication request: ' + JSON.serialize(authRequest));
            
            // Call authenticateUser with the properly formatted auth data
            String authData = JSON.serialize(authRequest);
            AuthResponse authResult = authenticateUser(authData);
            
            return new Map<String, Object>{
                'success' => authResult.success,
                'message' => authResult.message,
                'token' => authResult.token,
                'authUrl' => authResult.authUrl
            };
            
        } catch (Exception e) {
            System.debug('Error in authenticateWithCredentials: ' + e.getMessage());
            return new Map<String, Object>{
                'success' => false,
                'message' => 'Authentication failed: ' + e.getMessage()
            };
        }
    }
    
    @AuraEnabled
    public static String callApiWithUserToken(String endpoint, String payload) {
        try {
            // Get the user's stored token
            String userToken = getUserToken();
            if (String.isBlank(userToken)) {
                throw new AuraHandledException('User not authenticated. Please authenticate first.');
            }
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL + endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + userToken); // Dynamic user token
            req.setBody(payload);
            req.setTimeout(10000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                return res.getBody();
            } else if (res.getStatusCode() == 401) {
                // Token might be expired, clear it
                clearUserToken();
                throw new AuraHandledException('Authentication expired. Please authenticate again.');
            } else {
                throw new CalloutException('API call failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('API call error: ' + e.getMessage());
            throw new AuraHandledException('API call failed: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String callApiGetWithUserToken(String endpoint) {
        try {
            // Get the user's stored token
            String userToken = getUserToken();
            if (String.isBlank(userToken)) {
                throw new AuraHandledException('User not authenticated. Please authenticate first.');
            }
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL + endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + userToken); // Dynamic user token
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                return res.getBody();
            } else if (res.getStatusCode() == 401) {
                // Token might be expired, clear it
                clearUserToken();
                throw new AuraHandledException('Authentication expired. Please authenticate again.');
            } else {
                throw new CalloutException('API call failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('API call error: ' + e.getMessage());
            throw new AuraHandledException('API call failed: ' + e.getMessage());
        }
    }
    
    // User-aware version of callApiGetWithUserToken
    public static String callApiGetWithUserToken(String endpoint, Id userId) {
        try {
            String userToken = getUserToken(userId);
            if (String.isBlank(userToken)) {
                throw new AuraHandledException('User not authenticated. Please authenticate first.');
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL + endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + userToken);
            req.setTimeout(120000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                return res.getBody();
            } else if (res.getStatusCode() == 401) {
                clearUserToken(userId);
                throw new AuraHandledException('Authentication expired. Please authenticate again.');
            } else {
                throw new CalloutException('API call failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException('API call failed: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> checkApiConnection() {
        try {
            // For Hierarchy Custom Settings, use getInstance() to get user-specific values
            API_Token__c tokenSetting = API_Token__c.getInstance();
            
            boolean isConnected = false;
            if (tokenSetting != null) {
                isConnected = (String.isNotBlank(tokenSetting.access_token__c) && 
                              tokenSetting.Is_Active__c == true &&
                              (tokenSetting.expires_at__c == null || tokenSetting.expires_at__c > System.now()));
            }
            
            System.debug('checkApiConnection - Token setting found: ' + (tokenSetting != null));
            System.debug('checkApiConnection - Is connected: ' + isConnected);
            
            return new Map<String, Object>{
                'isConnected' => isConnected,
                'message' => isConnected ? 'API is connected' : 'API is not connected'
            };
        } catch (Exception e) {
            System.debug('Error checking API connection: ' + e.getMessage());
            return new Map<String, Object>{
                'isConnected' => false,
                'message' => 'Error checking connection status'
            };
        }
    }
    
    @AuraEnabled
    public static Boolean isUserAuthenticated() {
        try {
            API_Token__c tokenSetting = API_Token__c.getInstance();
            return tokenSetting != null && 
                   String.isNotBlank(tokenSetting.access_token__c) && 
                   (tokenSetting.expires_at__c == null || tokenSetting.expires_at__c > System.now()) &&
                   (tokenSetting.Is_Active__c == null || tokenSetting.Is_Active__c);
        } catch (Exception e) {
            return false;
        }
    }
    
    // User-aware version of isUserAuthenticated
    public static Boolean isUserAuthenticated(Id userId) {
        try {
            API_Token__c tokenSetting = API_Token__c.getInstance((Id)userId);
            return tokenSetting != null && 
                   String.isNotBlank(tokenSetting.access_token__c) && 
                   (tokenSetting.expires_at__c == null || tokenSetting.expires_at__c > System.now()) &&
                   (tokenSetting.Is_Active__c == null || tokenSetting.Is_Active__c);
        } catch (Exception e) {
            return false;
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> disconnectApi() {
        try {
            // For Hierarchy Custom Settings, get the user's token setting
            API_Token__c tokenSetting = API_Token__c.getInstance();
            
            if (tokenSetting != null && tokenSetting.Is_Active__c == true) {
                // First, notify the external API about the disconnection
                try {
                    notifyExternalApiDisconnect(tokenSetting.access_token__c, tokenSetting.client_id__c);
                    System.debug('Successfully notified external API about disconnection');
                } catch (Exception calloutEx) {
                    System.debug('Warning: Failed to notify external API about disconnection: ' + calloutEx.getMessage());
                    // Continue with local disconnect even if external call fails
                }
                
                // For hierarchy custom settings, we need to ensure we have the SetupOwnerId
                if (String.isBlank(tokenSetting.SetupOwnerId)) {
                    tokenSetting.SetupOwnerId = UserInfo.getUserId();
                }
                
                tokenSetting.Is_Active__c = false;
                tokenSetting.Disconnected_Date__c = System.now();
                upsert tokenSetting; // Use upsert instead of update for hierarchy custom settings
                System.debug('Disconnected user token setting');
            } else {
                System.debug('No active user token setting found to disconnect');
            }
            
            return new Map<String, Object>{
                'success' => true,
                'message' => 'API disconnected successfully'
            };
        } catch (Exception e) {
            System.debug('Error disconnecting API: ' + e.getMessage());
            return new Map<String, Object>{
                'success' => false,
                'message' => 'Failed to disconnect: ' + e.getMessage()
            };
        }
    }
    
    // Helper method to notify external API about disconnection
    private static void notifyExternalApiDisconnect(String accessToken, String clientId) {
        if (String.isBlank(accessToken)) {
            System.debug('No access token available for external API notification');
            return;
        }
        
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://employee-api-jtx6w5.5sc6y6-2.usa-e2.cloudhub.io/api/disconnect');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setTimeout(10000); // 10 second timeout
            
            // Send the access token or user info to identify which session to disconnect
            Map<String, Object> requestBody = new Map<String, Object>{
                'action' => 'disconnect',
                'access_token' => accessToken,
                'userId' => UserInfo.getUserId(),
                'clientId' => String.isNotBlank(clientId) ? clientId : 'salesforce_integration', // Use stored clientId or fallback
                'timestamp' => System.now().getTime()
            };
            req.setBody(JSON.serialize(requestBody));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                System.debug('External API disconnect notification successful: ' + res.getStatusCode());
            } else {
                System.debug('External API disconnect notification failed: ' + res.getStatusCode() + ' - ' + res.getBody());
                throw new CalloutException('External API returned error: ' + res.getStatusCode());
            }
        } catch (Exception e) {
            System.debug('Error notifying external API about disconnect: ' + e.getMessage());
            throw e; // Re-throw to be caught by calling method
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static String testNoParams() {
        System.debug('=== testNoParams called ===');
        return 'SUCCESS: Method called with no parameters';
    }

    @AuraEnabled(cacheable=false)
    public static String handleAuthCallbackSimple(String token, String userId) {
        System.debug('=== handleAuthCallbackSimple called ===');
        System.debug('Token received: ' + (String.isNotBlank(token) ? 'YES' : 'NO'));
        System.debug('UserId received: ' + userId);
        
        try {
            // Just return a simple string for now to test
            return 'SUCCESS: Token received and user validated';
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
            return 'ERROR: ' + e.getMessage();
        }
    }

    @AuraEnabled(cacheable=false)
    public static String handleAuthCallback(String token) {
        System.debug('=== handleAuthCallback called ===');
        System.debug('Token received: ' + (String.isNotBlank(token) ? 'YES' : 'NO'));
        System.debug('Current Salesforce UserId: ' + UserInfo.getUserId());
        
        try {
            // Validate token input
            if (String.isBlank(token)) {
                System.debug('ERROR: Invalid token provided');
                return 'ERROR: Invalid token provided';
            }
            
            System.debug('About to store token in custom setting...');
            // Store token in custom setting using current user context
            String currentUserId = UserInfo.getUserId();
            storeTokenInCustomSetting(token, null, 'Bearer', 3600, currentUserId, null);
            System.debug('Token stored successfully');
            
            return 'SUCCESS: Authentication completed successfully';
        } catch (Exception e) {
            System.debug('ERROR in handleAuthCallback: ' + e.getMessage());
            System.debug('ERROR Stack Trace: ' + e.getStackTraceString());
            return 'ERROR: Failed to store authentication token: ' + e.getMessage();
        }
    }

    @AuraEnabled(cacheable=false)
    public static String clearCustomSettings() {
        System.debug('=== clearCustomSettings called ===');
        
        try {
            // Delete any existing custom setting records (both user-specific and org-level)
            List<API_Token__c> existingTokens = [SELECT Id, Name FROM API_Token__c];
            if (!existingTokens.isEmpty()) {
                delete existingTokens;
                System.debug('Cleared ' + existingTokens.size() + ' existing custom setting records');
                for (API_Token__c token : existingTokens) {
                    System.debug('- Deleted: ' + token.Name + ' (ID: ' + token.Id + ')');
                }
            }
            
            return 'SUCCESS: Custom settings cleared';
        } catch (Exception e) {
            System.debug('ERROR clearing custom settings: ' + e.getMessage());
            return 'ERROR: Failed to clear custom settings: ' + e.getMessage();
        }
    }

    @AuraEnabled(cacheable=false)
    public static String clearDefaultOrganizationValues() {
        System.debug('=== clearDefaultOrganizationValues called ===');
        
        try {
            // Query for organization-level default values (these have SetupOwnerId = org ID)
            String orgId = UserInfo.getOrganizationId();
            List<API_Token__c> orgLevelTokens = [
                SELECT Id, Name, SetupOwnerId 
                FROM API_Token__c 
                WHERE SetupOwnerId = :orgId
            ];
            
            if (!orgLevelTokens.isEmpty()) {
                delete orgLevelTokens;
                System.debug('Cleared ' + orgLevelTokens.size() + ' organization-level default values');
                for (API_Token__c token : orgLevelTokens) {
                    System.debug('- Deleted org-level: ' + token.Name + ' (ID: ' + token.Id + ')');
                }
            } else {
                System.debug('No organization-level default values found');
            }
            
            return 'SUCCESS: Organization default values cleared';
        } catch (Exception e) {
            System.debug('ERROR clearing organization defaults: ' + e.getMessage());
            return 'ERROR: Failed to clear organization defaults: ' + e.getMessage();
        }
    }

    @AuraEnabled(cacheable=false)
    public static String storeAuthTokenString(String token) {
        System.debug('=== storeAuthTokenString called ===');
        System.debug('Token received: ' + (String.isNotBlank(token) ? 'YES' : 'NO'));
        System.debug('Current Salesforce UserId: ' + UserInfo.getUserId());
        
        try {
            // Validate token input
            if (String.isBlank(token)) {
                System.debug('ERROR: Invalid token provided');
                return 'ERROR: Invalid token provided';
            }
            
            // First clear any existing records to avoid conflicts
            clearCustomSettings();
            
            // Create fresh custom setting record
            API_Token__c tokenSetting = new API_Token__c();
            tokenSetting.Name = UserInfo.getUserId(); // Use current user ID as the name
            
            // Update fields directly
            tokenSetting.access_token__c = token;
            tokenSetting.token_type__c = 'Bearer';
            tokenSetting.client_id__c = UserInfo.getUserId(); // Set client ID as user ID for uniqueness
            tokenSetting.Sfdc_User_Id__c = UserInfo.getUserId();
            tokenSetting.Connected_Date__c = System.now();
            tokenSetting.Last_Updated__c = System.now();
            tokenSetting.Is_Active__c = true;
            tokenSetting.expires_at__c = System.now().addHours(1);
            
            insert tokenSetting;
            System.debug('Token stored successfully with ID: ' + tokenSetting.Id);
            
            return 'SUCCESS: Authentication completed successfully';
        } catch (Exception e) {
            System.debug('ERROR in storeAuthTokenString: ' + e.getMessage());
            System.debug('ERROR Stack Trace: ' + e.getStackTraceString());
            return 'ERROR: Failed to store authentication token: ' + e.getMessage();
        }
    }

    @AuraEnabled(cacheable=false)
    public static String simpleTokenStore(String tokenValue) {
        System.debug('=== simpleTokenStore called ===');
        System.debug('Token: ' + tokenValue);
        
        try {
            if (String.isBlank(tokenValue)) {
                return 'ERROR_NO_TOKEN';
            }
            
            // Ultra-simple approach - just create a record without any complex logic
            API_Token__c newToken = new API_Token__c();
            newToken.Name = 'Test_' + System.now().getTime();
            newToken.access_token__c = tokenValue;
            newToken.Is_Active__c = true;
            newToken.Sfdc_User_Id__c = UserInfo.getUserId();
            
            insert newToken;
            
            return 'SUCCESS_TOKEN_STORED';
        } catch (Exception ex) {
            System.debug('simpleTokenStore ERROR: ' + ex.getMessage());
            return 'ERROR_' + ex.getMessage();
        }
    }

    @AuraEnabled(cacheable=false)
    public static String ultraSimpleTest(String input) {
        System.debug('=== ultraSimpleTest called with: ' + input);
        return 'RECEIVED_' + input;
    }
    
    @AuraEnabled(cacheable=false)
    public static ConnectionResponse pollAuthStatus(String sessionId) {
        try {
            API_Token__c apiToken = API_Token__c.getInstance();
            
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
    
    private static String getUserToken() {
        try {
            API_Token__c tokenSetting = API_Token__c.getInstance();
            if (tokenSetting != null && 
                String.isNotBlank(tokenSetting.access_token__c) && 
                (tokenSetting.Is_Active__c == null || tokenSetting.Is_Active__c)) {
                
                // Check if token is not expired
                if (tokenSetting.expires_at__c == null || tokenSetting.expires_at__c > System.now()) {
                    return tokenSetting.access_token__c;
                } else {
                    // Token expired, try to refresh
                    if (String.isNotBlank(tokenSetting.refresh_token__c)) {
                        return refreshUserToken(tokenSetting.refresh_token__c);
                    } else {
                        // No refresh token, clear expired token
                        clearUserToken();
                    }
                }
            }
            
            return null;
        } catch (Exception e) {
            System.debug('Error retrieving user token: ' + e.getMessage());
            return null;
        }
    }
    
    // User-aware version of getUserToken
    private static String getUserToken(Id userId) {
        try {
            API_Token__c tokenSetting = API_Token__c.getInstance(userId);
            if (tokenSetting != null && 
                String.isNotBlank(tokenSetting.access_token__c) && 
                (tokenSetting.Is_Active__c == null || tokenSetting.Is_Active__c)) {
                
                // Check if token is not expired
                if (tokenSetting.expires_at__c == null || tokenSetting.expires_at__c > System.now()) {
                    return tokenSetting.access_token__c;
                } else {
                    // Token expired, try to refresh
                    if (String.isNotBlank(tokenSetting.refresh_token__c)) {
                        return refreshUserToken(userId, tokenSetting.refresh_token__c);
                    } else {
                        // No refresh token, clear expired token
                        clearUserToken(userId);
                    }
                }
            }
            
            return null;
        } catch (Exception e) {
            System.debug('Error retrieving user token: ' + e.getMessage());
            return null;
        }
    }
    
    private static String refreshUserToken(String refreshToken) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL + '/refresh-token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody('{"refresh_token":"' + refreshToken + '"}');
            req.setTimeout(10000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String newToken = (String) response.get('access_token');
                String newRefreshToken = (String) response.get('refresh_token');
                Integer expiresIn = (Integer) response.get('expires_in');
                
                // Update the stored token
                updateTokenInCustomSetting(newToken, newRefreshToken, expiresIn);
                return newToken;
            } else {
                // Refresh failed, clear token
                clearUserToken();
                return null;
            }
        } catch (Exception e) {
            System.debug('Token refresh failed: ' + e.getMessage());
            clearUserToken();
            return null;
        }
    }
    
    // User-aware version of refreshUserToken
    private static String refreshUserToken(Id userId, String refreshToken) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL + '/refresh-token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody('{"refresh_token":"' + refreshToken + '"}');
            req.setTimeout(10000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String newToken = (String) response.get('access_token');
                String newRefreshToken = (String) response.get('refresh_token');
                Integer expiresIn = (Integer) response.get('expires_in');
                
                // Update the stored token
                updateTokenInCustomSetting(userId, newToken, newRefreshToken, expiresIn);
                return newToken;
            } else {
                // Refresh failed, clear token
                clearUserToken(userId);
                return null;
            }
        } catch (Exception e) {
            System.debug('Token refresh failed: ' + e.getMessage());
            clearUserToken(userId);
            return null;
        }
    }
    
    private static void clearUserToken() {
        try {
            API_Token__c tokenSetting = API_Token__c.getInstance();
            if (tokenSetting != null) {
                tokenSetting.Is_Active__c = false;
                tokenSetting.Disconnected_Date__c = System.now();
                upsert tokenSetting;
            }
        } catch (Exception e) {
            System.debug('Error clearing user token: ' + e.getMessage());
        }
    }
    
    // User-aware version of clearUserToken
    private static void clearUserToken(Id userId) {
        try {
            API_Token__c tokenSetting = API_Token__c.getInstance(userId);
            if (tokenSetting != null) {
                tokenSetting.Is_Active__c = false;
                tokenSetting.Disconnected_Date__c = System.now();
                upsert tokenSetting;
            }
        } catch (Exception e) {
            System.debug('Error clearing user token: ' + e.getMessage());
        }
    }
    
    private static Integration_Setting__mdt getIntegrationSettings() {
        try {
            return [
                SELECT API_Endpoint__c, Timeout__c, Retry_Count__c, Is_Sandbox__c, Token_Expiry_Hours__c
                FROM Integration_Setting__mdt 
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
        } catch (Exception e) {
            // Return default settings if metadata not found
            Integration_Setting__mdt defaultSettings = new Integration_Setting__mdt();
            defaultSettings.Timeout__c = 10000;
            defaultSettings.Retry_Count__c = 3;
            defaultSettings.Token_Expiry_Hours__c = 1;
            return defaultSettings;
        }
    }
    
    private static AuthResponse processAuthResponse(String responseBody) {
        try {
            // Parse response and extract necessary data
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            String accessToken = (String) response.get('access_token');
            String refreshToken = (String) response.get('refresh_token');
            String tokenType = (String) response.get('token_type');
            Integer expiresIn = (Integer) response.get('expires_in');
            String userId = (String) response.get('user_id');
            String clientId = (String) response.get('client_id');
            
            // Store token synchronously in the same transaction
            storeTokenInCustomSetting(accessToken, refreshToken, tokenType, expiresIn, userId, clientId);
            
            return new AuthResponse(true, 'Authentication successful', accessToken);
        } catch (Exception e) {
            System.debug('Error processing auth response: ' + e.getMessage());
            return new AuthResponse(false, 'Failed to process authentication response', null);
        }
    }
    
    private static void storeTokenInCustomSetting(String accessToken, String refreshToken, String tokenType, Integer expiresIn, String userId, String clientId) {
        System.debug('=== storeTokenInCustomSetting called ===');
        System.debug('Access Token: ' + (String.isNotBlank(accessToken) ? 'PROVIDED' : 'NULL'));
        System.debug('User ID: ' + userId);
        System.debug('Current Salesforce User: ' + UserInfo.getUserId());
        
        try {
            API_Token__c tokenSetting = API_Token__c.getInstance();
            System.debug('Existing token setting: ' + (tokenSetting != null ? 'FOUND' : 'NOT FOUND'));
            
            if (tokenSetting == null) {
                tokenSetting = new API_Token__c();
                System.debug('Created new token setting');
            }
            
            // Update all fields
            tokenSetting.access_token__c = accessToken;
            tokenSetting.refresh_token__c = refreshToken;
            tokenSetting.token_type__c = String.isNotBlank(tokenType) ? tokenType : 'Bearer';
            tokenSetting.user_id__c = userId;
            tokenSetting.client_id__c = String.isNotBlank(clientId) ? clientId : UserInfo.getUserId(); // Default to current user ID if not provided
            tokenSetting.Sfdc_User_Id__c = UserInfo.getUserId();
            tokenSetting.created_date__c = System.now();
            tokenSetting.Connected_Date__c = System.now();
            tokenSetting.Last_Updated__c = System.now();
            tokenSetting.Is_Active__c = true;
            
            // Calculate expiration time
            Integer hours = expiresIn != null ? (expiresIn / 3600) : 1; // Convert seconds to hours
            tokenSetting.expires_at__c = System.now().addHours(hours);
            
            // Clear disconnection date
            tokenSetting.Disconnected_Date__c = null;
            
            System.debug('About to upsert token setting...');
            upsert tokenSetting;
            System.debug('Token setting upserted successfully. ID: ' + tokenSetting.Id);
            
            // Verify the token was stored
            API_Token__c verifyToken = API_Token__c.getInstance();
            System.debug('Verification - Token exists after upsert: ' + (verifyToken != null ? 'YES' : 'NO'));
            if (verifyToken != null) {
                System.debug('Verification - Access token stored: ' + (String.isNotBlank(verifyToken.access_token__c) ? 'YES' : 'NO'));
            }
        } catch (Exception e) {
            System.debug('ERROR storing token: ' + e.getMessage());
            System.debug('ERROR Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to store authentication token: ' + e.getMessage());
        }
    }
    
    private static void updateTokenInCustomSetting(String accessToken, String refreshToken, Integer expiresIn) {
        try {
            API_Token__c tokenSetting = API_Token__c.getInstance();
            if (tokenSetting != null) {
                tokenSetting.access_token__c = accessToken;
                if (String.isNotBlank(refreshToken)) {
                    tokenSetting.refresh_token__c = refreshToken;
                }
                tokenSetting.Last_Updated__c = System.now();
                
                // Calculate expiration time
                Integer hours = expiresIn != null ? (expiresIn / 3600) : 1;
                tokenSetting.expires_at__c = System.now().addHours(hours);
                
                upsert tokenSetting;
            }
        } catch (Exception e) {
            System.debug('Error updating token: ' + e.getMessage());
            throw new AuraHandledException('Failed to update authentication token');
        }
    }
    
    // User-aware version of updateTokenInCustomSetting
    private static void updateTokenInCustomSetting(Id userId, String accessToken, String refreshToken, Integer expiresIn) {
        try {
            API_Token__c tokenSetting = API_Token__c.getInstance(userId);
            if (tokenSetting == null) {
                tokenSetting = new API_Token__c();
                tokenSetting.SetupOwnerId = userId;
            }
            
            tokenSetting.access_token__c = accessToken;
            if (String.isNotBlank(refreshToken)) {
                tokenSetting.refresh_token__c = refreshToken;
            }
            tokenSetting.Last_Updated__c = System.now();
            
            // Calculate expiration time
            Integer hours = expiresIn != null ? (expiresIn / 3600) : 1;
            tokenSetting.expires_at__c = System.now().addHours(hours);
            
            upsert tokenSetting;
        } catch (Exception e) {
            System.debug('Error updating token: ' + e.getMessage());
            throw new AuraHandledException('Failed to update authentication token');
        }
    }
    
    // Response wrapper classes
    public class AuthResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String authUrl;
        @AuraEnabled public String token;
        
        public AuthResponse(Boolean success, String message, String authUrlOrToken) {
            this.success = success;
            this.message = message;
            
            // Initialize both fields to avoid null issues
            this.authUrl = '';
            this.token = '';
            
            // Determine if this is an authUrl or token based on content
            if (String.isNotBlank(authUrlOrToken)) {
                if (authUrlOrToken.startsWith('http')) {
                    this.authUrl = authUrlOrToken;
                } else {
                    this.token = authUrlOrToken;
                }
            }
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> storeTokenSimple(String accessToken, String refreshToken, String userId, String clientId) {
        try {
            System.debug('=== storeTokenSimple called ===');
            System.debug('Access token received: ' + (String.isNotBlank(accessToken) ? 'YES' : 'NO'));
            System.debug('Access token length: ' + (accessToken != null ? accessToken.length() : 0));
            System.debug('Refresh token received: ' + (String.isNotBlank(refreshToken) ? 'YES' : 'NO'));
            System.debug('Refresh token length: ' + (refreshToken != null ? refreshToken.length() : 0));
            System.debug('Refresh token value (first 50 chars): ' + (String.isNotBlank(refreshToken) ? refreshToken.substring(0, Math.min(50, refreshToken.length())) : 'EMPTY'));
            System.debug('User ID: ' + userId);
            System.debug('Client ID: ' + clientId);
            
            if (String.isBlank(accessToken)) {
                return new Map<String, Object>{
                    'success' => false,
                    'message' => 'No access token provided'
                };
            }
            
            // Use current user ID if not provided
            String currentUserId = String.isNotBlank(userId) ? userId : UserInfo.getUserId();
            
            // For Hierarchy Custom Settings, use getInstance() and upsert pattern
            API_Token__c tokenSetting = API_Token__c.getInstance();
            
            if (tokenSetting == null) {
                // Create new hierarchy custom setting record
                tokenSetting = new API_Token__c();
                tokenSetting.Name = currentUserId; // For hierarchy, name should be user ID
                tokenSetting.SetupOwnerId = currentUserId; // Set the owner for hierarchy custom setting
            }
            
            // Ensure SetupOwnerId is set for updates
            if (String.isBlank(tokenSetting.SetupOwnerId)) {
                tokenSetting.SetupOwnerId = currentUserId;
            }
            
            // Update/set the token values
            tokenSetting.access_token__c = accessToken;
            tokenSetting.refresh_token__c = refreshToken; // Store refresh token
            tokenSetting.token_type__c = 'Bearer';
            tokenSetting.client_id__c = String.isNotBlank(clientId) ? clientId : currentUserId; // Use provided clientId or fallback to user ID
            tokenSetting.Sfdc_User_Id__c = currentUserId;
            tokenSetting.Connected_Date__c = System.now();
            tokenSetting.Last_Updated__c = System.now();
            tokenSetting.Is_Active__c = true;
            tokenSetting.expires_at__c = System.now().addHours(1);
            
            // Use upsert for hierarchy custom settings
            upsert tokenSetting;
            
            System.debug('Token stored successfully with ID: ' + tokenSetting.Id);
            
            return new Map<String, Object>{
                'success' => true,
                'message' => 'Token stored successfully',
                'tokenId' => tokenSetting.Id
            };
            
        } catch (Exception e) {
            System.debug('ERROR in storeTokenSimple: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            return new Map<String, Object>{
                'success' => false,
                'message' => e.getMessage()
            };
        }
    }

    @AuraEnabled
    public static Map<String, Object> storeTokenOnlyToken(String token, String clientId) {
        try {
            System.debug('=== storeTokenOnlyToken called ===');
            System.debug('Token received: ' + (String.isNotBlank(token) ? 'YES' : 'NO'));
            System.debug('Client ID: ' + clientId);
            
            // Get current user ID from context
            String currentUserId = UserInfo.getUserId();
            System.debug('Current User ID from context: ' + currentUserId);
            
            if (String.isBlank(token)) {
                return new Map<String, Object>{
                    'success' => false,
                    'message' => 'No token provided'
                };
            }
            
            // Clear any existing tokens for this user
            List<API_Token__c> existingTokens = [
                SELECT Id FROM API_Token__c 
                WHERE Sfdc_User_Id__c = :currentUserId 
                AND Is_Active__c = true
            ];
            if (!existingTokens.isEmpty()) {
                for (API_Token__c existing : existingTokens) {
                    existing.Is_Active__c = false;
                }
                update existingTokens;
            }
            
            // Create new token record
            API_Token__c newToken = new API_Token__c();
            newToken.Name = currentUserId;
            newToken.access_token__c = token;
            newToken.token_type__c = 'Bearer';
            newToken.client_id__c = String.isNotBlank(clientId) ? clientId : currentUserId; // Use provided clientId or fallback to user ID
            newToken.Sfdc_User_Id__c = currentUserId;
            newToken.Connected_Date__c = System.now();
            newToken.Last_Updated__c = System.now();
            newToken.Is_Active__c = true;
            newToken.expires_at__c = System.now().addHours(1);
            
            insert newToken;
            
            System.debug('Token stored successfully with ID: ' + newToken.Id);
            
            return new Map<String, Object>{
                'success' => true,
                'message' => 'Token stored successfully',
                'tokenId' => newToken.Id
            };
            
        } catch (Exception e) {
            System.debug('ERROR in storeTokenOnlyToken: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            return new Map<String, Object>{
                'success' => false,
                'message' => e.getMessage()
            };
        }
    }
    
    public class ConnectionResponse {
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public String message;
        
        public ConnectionResponse(Boolean isConnected, String message) {
            this.isConnected = isConnected;
            this.message = message;
        }
    }
}
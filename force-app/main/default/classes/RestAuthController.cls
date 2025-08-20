@RestResource(urlMapping='/auth/store/*')
global without sharing class RestAuthController {
    
    @HttpPost
    global static String storeToken() {
        try {
            RestRequest req = RestContext.request;
            
            // Parse JSON body
            Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            String token = (String) requestBody.get('token');
            String userId = (String) requestBody.get('userId');
            
            System.debug('=== REST storeToken called ===');
            System.debug('Token received: ' + (String.isNotBlank(token) ? 'YES' : 'NO'));
            System.debug('User ID: ' + userId);
            
            if (String.isBlank(token)) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'No token provided'
                });
            }
            
            // Clear any existing tokens for this user
            List<API_Token__c> existingTokens = [
                SELECT Id FROM API_Token__c 
                WHERE Sfdc_User_Id__c = :userId 
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
            newToken.Name = userId;
            newToken.access_token__c = token;
            newToken.token_type__c = 'Bearer';
            newToken.Sfdc_User_Id__c = userId;
            newToken.Connected_Date__c = System.now();
            newToken.Last_Updated__c = System.now();
            newToken.Is_Active__c = true;
            newToken.expires_at__c = System.now().addHours(1);
            
            insert newToken;
            
            System.debug('Token stored successfully with ID: ' + newToken.Id);
            
            return JSON.serialize(new Map<String, Object>{
                'success' => true,
                'message' => 'Token stored successfully',
                'tokenId' => newToken.Id
            });
            
        } catch (Exception e) {
            System.debug('ERROR in REST storeToken: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Error: ' + e.getMessage()
            });
        }
    }
}
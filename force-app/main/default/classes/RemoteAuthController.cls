public with sharing class RemoteAuthController {
    
    @RemoteAction
    public static String storeToken(String token) {
        System.debug('=== RemoteAction storeToken called ===');
        System.debug('Token received: ' + (String.isNotBlank(token) ? 'YES' : 'NO'));
        
        try {
            if (String.isBlank(token)) {
                return 'ERROR: No token provided';
            }
            
            // Clear any existing tokens
            List<API_Token__c> existingTokens = [SELECT Id FROM API_Token__c];
            if (!existingTokens.isEmpty()) {
                delete existingTokens;
            }
            
            // Create new token record
            API_Token__c newToken = new API_Token__c();
            newToken.Name = UserInfo.getUserId();
            newToken.access_token__c = token;
            newToken.token_type__c = 'Bearer';
            newToken.Sfdc_User_Id__c = UserInfo.getUserId();
            newToken.Connected_Date__c = System.now();
            newToken.Last_Updated__c = System.now();
            newToken.Is_Active__c = true;
            newToken.expires_at__c = System.now().addHours(1);
            
            insert newToken;
            
            System.debug('Token stored successfully with ID: ' + newToken.Id);
            return 'SUCCESS: Token stored successfully';
            
        } catch (Exception e) {
            System.debug('ERROR in RemoteAction: ' + e.getMessage());
            return 'ERROR: ' + e.getMessage();
        }
    }
}
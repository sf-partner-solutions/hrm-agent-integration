public with sharing class TestAuthService {
    
    @AuraEnabled(cacheable=false)
    public static String simpleTest() {
        return 'SUCCESS: Simple test method works';
    }
    
    @AuraEnabled(cacheable=false)
    public static String testWithParams(String param1, String param2) {
        return 'SUCCESS: Received param1=' + param1 + ', param2=' + param2;
    }
    
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> testAuthCallback(String token, String userId) {
        System.debug('TestAuthService.testAuthCallback called');
        System.debug('Token: ' + (String.isNotBlank(token) ? 'PROVIDED' : 'NULL'));
        System.debug('UserId: ' + userId);
        
        return new Map<String, Object>{
            'success' => true,
            'message' => 'Test authentication successful',
            'tokenReceived' => String.isNotBlank(token),
            'userIdReceived' => userId
        };
    }
    
    // Alternative approach using immediate DML without LWC
    public static void storeAuthTokenDirect(String token, String userId) {
        System.debug('=== storeAuthTokenDirect called ===');
        System.debug('Token: ' + (String.isNotBlank(token) ? 'PROVIDED' : 'NULL'));
        System.debug('UserId: ' + userId);
        
        try {
            API_Token__c tokenSetting = API_Token__c.getInstance();
            if (tokenSetting == null) {
                tokenSetting = new API_Token__c();
            }
            
            tokenSetting.access_token__c = token;
            tokenSetting.user_id__c = userId;
            tokenSetting.Sfdc_User_Id__c = UserInfo.getUserId();
            tokenSetting.Connected_Date__c = System.now();
            tokenSetting.Is_Active__c = true;
            tokenSetting.token_type__c = 'Bearer';
            tokenSetting.expires_at__c = System.now().addHours(1);
            
            upsert tokenSetting;
            System.debug('Token stored successfully via direct method');
        } catch (Exception e) {
            System.debug('ERROR storing token directly: ' + e.getMessage());
        }
    }
}
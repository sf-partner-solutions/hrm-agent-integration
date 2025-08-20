public class EmployeeGoalsUtility {
    
    public static void testEmployeeGoalsAPICall() {
        System.debug('=== Testing Employee Goals API Call ===');
        
        try {
            // Get current user's External_ID__c
            User currentUser = [SELECT External_ID__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            String employeeId = currentUser.External_ID__c;
            System.debug('Testing with employeeId: ' + employeeId);
            
            // Check token status
            API_Token__c tokenSetting = API_Token__c.getInstance();
            System.debug('Token active: ' + (tokenSetting != null ? String.valueOf(tokenSetting.Is_Active__c) : 'No token found'));
            
            if (tokenSetting != null && tokenSetting.Is_Active__c) {
                // Test the actual EmployeeGoalsService
                System.debug('=== Calling EmployeeGoalsService.getEmployeeGoals ===');
                List<String> employeeIds = new List<String>{ employeeId };
                List<String> results = EmployeeGoalsService.getEmployeeGoals(employeeIds);
                
                System.debug('=== API Response Results ===');
                for (Integer i = 0; i < results.size(); i++) {
                    System.debug('Result ' + i + ': ' + results[i]);
                }
            } else {
                System.debug('ERROR: No active token found. Please authenticate first.');
            }
            
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        System.debug('=== API Test Complete ===');
    }
}
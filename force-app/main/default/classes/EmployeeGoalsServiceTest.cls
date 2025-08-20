@isTest
private class EmployeeGoalsServiceTest {
    
    @isTest
    static void testGetEmployeeGoalsSuccess() {
        // Setup test data - create API token
        String currentUserId = UserInfo.getUserId();
        API_Token__c apiToken = new API_Token__c(
            Name = currentUserId,
            access_token__c = 'test-token-123',
            Is_Active__c = true
        );
        insert apiToken;
        
        // Mock successful API response
        Test.setMock(HttpCalloutMock.class, new EmployeeGoalsMockSuccess());
        
        Test.startTest();
        List<String> results = EmployeeGoalsService.getEmployeeGoals(new List<String>{'EMP001'});
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return one result');
        System.assert(results[0].contains('Employee Goals for ID EMP001'), 'Should contain employee ID in response');
        System.assert(results[0].contains('Complete Q1 project'), 'Should contain goal from mock response');
    }
    
    @isTest
    static void testGetEmployeeGoalsNoToken() {
        // No token setup - should fail gracefully
        
        Test.startTest();
        List<String> results = EmployeeGoalsService.getEmployeeGoals(new List<String>{'EMP001'});
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return one result');
        System.assert(results[0].contains('No active API token found'), 'Should indicate missing token');
    }
    
    @isTest
    static void testGetEmployeeGoalsInactiveToken() {
        // Setup inactive token
        String currentUserId = UserInfo.getUserId();
        API_Token__c apiToken = new API_Token__c(
            Name = currentUserId,
            access_token__c = 'test-token-123',
            Is_Active__c = false
        );
        insert apiToken;
        
        Test.startTest();
        List<String> results = EmployeeGoalsService.getEmployeeGoals(new List<String>{'EMP001'});
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return one result');
        System.assert(results[0].contains('No active API token found'), 'Should indicate no active token');
    }
    
    @isTest
    static void testGetEmployeeGoalsApiError() {
        // Setup test data
        String currentUserId = UserInfo.getUserId();
        API_Token__c apiToken = new API_Token__c(
            Name = currentUserId,
            access_token__c = 'test-token-123',
            Is_Active__c = true
        );
        insert apiToken;
        
        // Mock API error response
        Test.setMock(HttpCalloutMock.class, new EmployeeGoalsMockError());
        
        Test.startTest();
        List<String> results = EmployeeGoalsService.getEmployeeGoals(new List<String>{'EMP001'});
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return one result');
        System.assert(results[0].contains('Error:'), 'Should contain error message');
    }
    
    @isTest
    static void testGetEmployeeGoalsEmptyEmployeeId() {
        Test.startTest();
        List<String> results = EmployeeGoalsService.getEmployeeGoals(new List<String>{''});
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return one result');
        System.assert(results[0].contains('Employee ID is required'), 'Should indicate missing employee ID');
    }
    
    @isTest
    static void testGetEmployeeGoalsNotFound() {
        // Setup test data
        String currentUserId = UserInfo.getUserId();
        API_Token__c apiToken = new API_Token__c(
            Name = currentUserId,
            access_token__c = 'test-token-123',
            Is_Active__c = true
        );
        insert apiToken;
        
        // Mock 404 response
        Test.setMock(HttpCalloutMock.class, new EmployeeGoalsMockNotFound());
        
        Test.startTest();
        List<String> results = EmployeeGoalsService.getEmployeeGoals(new List<String>{'INVALID'});
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return one result');
        System.assert(results[0].contains('Employee not found'), 'Should indicate employee not found');
    }
    
    // Mock classes for testing
    public class EmployeeGoalsMockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            response.setBody('["Complete Q1 project", "Improve team collaboration", "Attend training workshop"]');
            return response;
        }
    }
    
    public class EmployeeGoalsMockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(500);
            response.setBody('{"error": "Internal server error"}');
            return response;
        }
    }
    
    public class EmployeeGoalsMockNotFound implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(404);
            response.setBody('{"error": "Employee not found"}');
            return response;
        }
    }
}
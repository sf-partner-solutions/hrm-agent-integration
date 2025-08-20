public with sharing class SimpleTestController {
    
    @AuraEnabled
    public static String getSimpleMessage() {
        return 'Hello from Apex!';
    }
    
    @AuraEnabled
    public static Integer getNumber() {
        return 42;
    }
    
    @AuraEnabled
    public static List<String> getStringList() {
        return new List<String>{'Test1', 'Test2', 'Test3'};
    }
}
public with sharing class AgentResponse3 {
    @InvocableMethod(label='ISV Agent Response 3' description='Invokes the ISV Agent Response 3')
    public static List<String> agentResponse3(List<Id> recordId){
	List<Agent_Response__c> lstAgentResponse = new List<Agent_Response__c>([SELECT Agent_Response_Number__c,CreatedById,Id,Response__c FROM Agent_Response__c where Agent_Response_Number__c = 3 AND CreatedById =: UserInfo.getUserId() ]);
    String strResponse = lstAgentResponse[0].Response__c;
    
    // Remove HTML markup from the response
    if (String.isNotBlank(strResponse)) {
        strResponse = strResponse.replaceAll('<[^>]*>', '');
    }
    
    return new List<String>{ strResponse};
}
}
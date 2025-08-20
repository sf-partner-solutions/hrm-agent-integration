public with sharing class AgentResponse1 {
    @InvocableMethod(label='ISV Agent Response 1' description='Invokes the ISV Agent Response 1')
    public static List<String> agentResponse2(List<Id> recordId){
	List<Agent_Response__c> lstAgentResponse = new List<Agent_Response__c>([SELECT Agent_Response_Number__c,CreatedById,Id,Response__c FROM Agent_Response__c where Agent_Response_Number__c = 1 AND CreatedById =: UserInfo.getUserId() ]);
    String strResponse = lstAgentResponse[0].Response__c;
    return new List<String>{ strResponse};
}
}
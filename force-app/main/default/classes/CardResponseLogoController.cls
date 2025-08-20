public with sharing class CardResponseLogoController {
    @InvocableMethod(label='Get PTO Balance' description='Get PTO Balance for the logged-in user')
    public static List<AgentResponse> getResponse(List<String> input) {
        List<AgentResponse> responses = new List<AgentResponse>();
        
        List<Agent_Response__c> lstAgentResponse = new List<Agent_Response__c>([SELECT Agent_Response_Number__c,CreatedById,Id,Response__c FROM Agent_Response__c where Agent_Response_Number__c = 1 AND CreatedById =: UserInfo.getUserId() ]);
        String strResponse = lstAgentResponse[0].Response__c;
        
        //AvailableResponse availableResp = new AvailableResponse();
        //availableResp.theResponse = strResponse;
        
        AgentResponse ar = new AgentResponse();
       ar.responseList = new ResponseList();
       ar.responseList.responses = new List<Response>();
       ar.responseList.responses.add(new Response(strResponse));
       
       responses.add(ar);
         
          return responses;
    }
    
    public class AgentResponse {
        @InvocableVariable
        public ResponseList responseList;
    }
    public class ResponseList {
        @InvocableVariable
        public List<Response> responses;  
    }

    public class Response {
        @InvocableVariable
        public String responseText;

        public Response(String response)
        {
            this.responseText = response;
        }
    }
}
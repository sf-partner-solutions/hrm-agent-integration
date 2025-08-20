public with sharing class HTMLAgentResponse {
    @InvocableMethod(label='HTML ISV Agent Response 16' description='Invokes the ISV Agent Response 16 with HTML Rendering')
    public static List<String> agentResponse16(List<Id> recordId){
        
        
        String strResponse = '<div style="display: flex; justify-content: space-around; align-items: center; border: 1px solid #ccc; padding: 10px; border-radius: 5px; width: 378px; height: 100px; font-size: 0.8125rem;"> <img src="https://img.icons8.com/fluent/512/workday.png" alt="Workday logo" style="height: 30px;"> <a href="https://www.workday.com/" style="margin: 0 10px;">#12345</a> <span style="margin: 0 10px;">Your PTO request for 1 day using Sick Time Balance has been scheduled.</span> </div>'; 
        //String strResponse = '<div style="display: flex; flex-direction: column; border: 1px solid #ccc; padding: 10px; border-radius: 5px; width: 378px; height: 100px; font-size: 0.8125rem;"> <div style="display: flex; justify-content: center; align-items: center;"> <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/c/c2/Workday_logo.svg/512px-Workday_logo.svg.png" alt="Workday logo" style="height: 30px;"> </div> <div style="display: flex; justify-content: space-around; align-items: center; margin-top: 10px;"> <a href="https://www.workday.com/" style="margin: 0 10px;">Request #12345</a> <span style="margin: 0 10px;">Your PTO request for 1 day using Sick Time Balance has been scheduled.</span> <span style="margin: 0 10px;">Pending</span> </div> </div>'; 
        return new List<String>{ strResponse};
        
    }
}
// SECURITY WARNING: This controller exposes sensitive OAuth credentials through public properties
// DO NOT USE in production. Replace with Named Credentials.
// TODO: Refactor to use Named Credential 'Pardot_Integration' instead of public properties
public class SDO_Pardot_ImportDataFromCSVController {
public Blob csvFileBody{get;set;}
public string csvAsString{get;set;}
public String[] csvFileLines{get;set;}
public String businessUnitId { get; set; }
// WARNING: These properties should NEVER be public - security risk
// Use Private Named Credentials instead
private String username { get; set; }
private String password { get; set; }
private String key { get; set; }
private String secret { get; set; } 
public List<account> acclist{get;set;}
  public SDO_Pardot_ImportDataFromCSVController(){
    csvFileLines = new String[]{};
  }
   public PageReference insertExternalActivities() {
        pagereference ref = new pagereference('/apex/SDO_Pardot_InsertExternalActivities');
        ref.setredirect(true);
        System.debug('****Starting Oauth2 call****');
        HttpResponse response = makeOauthCall();
        Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        String accessToken = (String)results.get('access_token');
        System.debug('*****Calling Pardot API*****');
        callPardotAPI(accessToken);
        return ref;
    }
    private HttpResponse makeOauthCall() {
        String body = 'grant_type=password&client_id='+key+'&client_secret='+secret+'&username='+username+'&password='+password;
        System.debug('Oauth call Body: ' + body);
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(Url.getOrgDomainUrl().toExternalForm() + '/services/oauth2/token');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setBody(body);
        HttpResponse response = http.send(request);

        if(response.getStatusCode() != 200) {
            System.debug('The status code returned was not expected: ' +
                response.getStatusCode() + ' ' + response.getStatus());
        } else {
            System.debug('****Oauth2 call successful****');
            System.debug(response.getBody());
        }
        return response;
    }
  
    public void callPardotAPI(String accessToken){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint('https://pi.demo.pardot.com/api/v5/external-activities');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Pardot-Business-Unit-Id', businessUnitId);
        try{
           csvAsString = csvFileBody.toString();
           csvFileLines = csvAsString.split('\n'); 
           for(Integer i=1;i<csvFileLines.size();i++){
                string[] csvRecordData = csvFileLines[i].split(',');
                String body = '{"extension": "' + csvRecordData[0] + '","type": "' + csvRecordData[1] + '","email": "' + csvRecordData[2] + '","value": "' + csvRecordData[3] + '"}';
                System.debug('External Activities Request Body: ' + body);
                request.setBody(body);
                HttpResponse response = http.send(request);
                
                if(response.getStatusCode() != 202) {
                System.debug('The status code returned was not expected: ' +
                    response.getStatusCode() + ' ' + response.getStatus());
                    System.debug('********Here is the error********: ' + response.getBody());
                } else {
                    System.debug('****External Activity inserted****');
                    System.debug(response.getBody());
                }  
               }
        }
        catch (Exception e)
        {
            ApexPages.Message errorMessage = new ApexPages.Message(ApexPages.severity.ERROR,'An error has occured while importing external activities. Please make sure input csv file is correct');
            ApexPages.addMessage(errorMessage);
        }  
  }
}
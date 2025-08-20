@RestResource(urlMapping='/api/auth/callback/*')
global with sharing class ApiAuthCallbackService {
    
    @HttpPost
    global static String handleAuthCallback() {
        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            
            // Set CORS headers
            res.addHeader('Access-Control-Allow-Origin', 'https://partnerapiwebauth-20c01287ca0d.herokuapp.com');
            res.addHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
            res.addHeader('Access-Control-Allow-Headers', 'Content-Type');
            
            // Parse request body
            String requestBody = req.requestBody.toString();
            Map<String, Object> requestData = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            
            String token = (String) requestData.get('token');
            String userId = (String) requestData.get('userId');
            
            // Validate inputs
            if (String.isBlank(token) || String.isBlank(userId)) {
                res.statusCode = 400;
                return JSON.serialize(new ApiLoginController.AuthResponse(false, 'Missing token or userId', null));
            }
            
            // Store the token
            ApiLoginController.AuthResponse result = ApiLoginController.handleAuthCallback(token, userId);
            
            if (result.success) {
                res.statusCode = 200;
                return JSON.serialize(result);
            } else {
                res.statusCode = 500;
                return JSON.serialize(result);
            }
            
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            System.debug('Error in auth callback service: ' + e.getMessage());
            return JSON.serialize(new ApiLoginController.AuthResponse(false, 'Internal server error: ' + e.getMessage(), null));
        }
    }
    
}
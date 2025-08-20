public without sharing class EmployeeGoalsService {

    private static final String GOALS_ENDPOINT = '/api/employee/{employeeId}/goals';

    // ===== Request/Response used by Agentforce Action =====
    public class EmployeeGoalsRequest {
        @InvocableVariable(label='User Id' description='Optional. If blank, defaults to the running user.')
        public String userId;
    }

    public class EmployeeGoalsResponse {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Employee Id (External_ID__c)')
        public String employeeId;
        @InvocableVariable(label='Goals (as strings)')
        public List<String> goals;
    }

    @InvocableMethod(label='Get User Career Goals' description='Fetches employee goals from the API using the User External_ID__c and the stored access token.')
    public static List<EmployeeGoalsResponse> getEmployeeGoals(List<EmployeeGoalsRequest> requests) {
        // Normalize/bulk-prepare
        if (requests == null || requests.isEmpty()) {
            requests = new List<EmployeeGoalsRequest>{ new EmployeeGoalsRequest() };
        }

        // Resolve effective userIds (fallback to running user)
        Set<Id> targetUserIds = new Set<Id>();
        List<Id> effectiveUserIds = new List<Id>();
        for (EmployeeGoalsRequest req : requests) {
            Id eff = (String.isBlank(req.userId)) ? UserInfo.getUserId() : (Id) req.userId;
            effectiveUserIds.add(eff);
            targetUserIds.add(eff);
        }

        // Single SOQL for all targets
        Map<Id, User> usersById = new Map<Id, User>(
            [SELECT Id, Name, Username, External_ID__c
             FROM User
             WHERE Id IN :targetUserIds]
        );

        List<EmployeeGoalsResponse> out = new List<EmployeeGoalsResponse>();

        for (Id effUserId : effectiveUserIds) {
            EmployeeGoalsResponse res = new EmployeeGoalsResponse();
            res.success = false;
            res.goals   = new List<String>();

            User u = usersById.get(effUserId);
            if (u == null) {
                res.message = 'Error: User not found with Id ' + effUserId;
                out.add(res);
                continue;
            }

            String employeeId = u.External_ID__c;
            if (String.isBlank(employeeId)) {
                res.message = 'Error: External_ID__c not set for user ' + u.Name + ' (' + u.Id + ').';
                out.add(res);
                continue;
            }

            // Use the target user's token (not the running user's token)
            // This fixes the Agent Execution User issue
            if (!MulesoftIntegrationService.isUserAuthenticated(effUserId)) {
                res.message = 'Error: No active API token for user ' + u.Name + '. Please authenticate first.';
                out.add(res);
                continue;
            }

            try {
                List<String> goals = fetchEmployeeGoals(employeeId, effUserId);
                res.employeeId = employeeId;

                if (goals.size() > 0) {
                    res.success = true;
                    res.goals   = goals;
                    res.message = 'OK';
                } else {
                    res.message = 'No goals found for employeeId ' + employeeId + '.';
                }
                System.debug('Fetched goals for employeeId ' + employeeId + ': ' + goals);
            } catch (Exception e) {
                // Friendly mapping of common error patterns
                String m = e.getMessage();
                if (m != null && m.contains('Authentication expired')) {
                    res.message = 'Error: Authentication expired. Please re-authenticate.';
                } else if (m != null && m.contains('401')) {
                    res.message = 'Error: Authentication failed (401). Please re-authenticate.';
                } else if (m != null && m.contains('404')) {
                    res.message = 'Error: Employee not found with employeeId ' + employeeId + '.';
                } else {
                    res.message = 'Error: ' + m;
                }
            }

            out.add(res);
        }

        return out;
    }

    // ===== Helpers =====

    // Calls MuleSoft GET and parses a JSON response into list of strings
    private static List<String> fetchEmployeeGoals(String employeeId, Id tokenOwnerUserId) {
        String endpoint = GOALS_ENDPOINT.replace('{employeeId}', employeeId);
        String body = MulesoftIntegrationService.callApiGetWithUserToken(endpoint, tokenOwnerUserId);

        List<String> out = new List<String>();

        try {
            // Try as JSON array first: ["a","b"]
            List<Object> arr = (List<Object>) JSON.deserializeUntyped(body);
            if (arr != null) {
                for (Object g : arr) out.add(String.valueOf(g));
                return out;
            }
        } catch (Exception ignore) {}

        try {
            // Try as JSON object: { "goals": [...] } or { "message": "..." }
            Map<String, Object> obj = (Map<String, Object>) JSON.deserializeUntyped(body);
            if (obj != null) {
                if (obj.containsKey('goals')) {
                    for (Object g : (List<Object>) obj.get('goals')) out.add(String.valueOf(g));
                    return out;
                }
                if (obj.containsKey('message')) {
                    out.add(String.valueOf(obj.get('message')));
                    return out;
                }
            }
        } catch (Exception ignore) {}

        // Fallback: accept raw text (non-JSON) as a single "goal" line so UI shows something
        out.add('Raw response: ' + body);
        return out;
    }

    // Helper method to validate employee ID format if needed
    private static Boolean isValidEmployeeId(String employeeId) {
        // Add any validation logic for employee ID format
        return String.isNotBlank(employeeId) && employeeId.length() > 0;
    }
}
public without sharing class UserGoalsService {

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

            // NOTE: MulesoftIntegrationService.isUserAuthenticated() and token storage
            // are based on hierarchy custom settings (current/running user).
            // This uses the *running user's* token to call for the target employeeId.
            if (!MulesoftIntegrationService.isUserAuthenticated()) {
                res.message = 'Error: No active API token for the running user. Please authenticate first.';
                out.add(res);
                continue;
            }

            try {
                List<String> goals = fetchEmployeeGoals(employeeId);
                res.employeeId = employeeId;

                if (!goals.isEmpty()) {
                    res.success = true;
                    res.goals   = goals;
                    res.message = 'OK';
                } else {
                    res.message = 'No goals found for employeeId ' + employeeId + '.';
                }
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

    // Calls MuleSoft GET and parses a JSON array response into list of strings
    private static List<String> fetchEmployeeGoals(String employeeId) {
        // Build endpoint like /api/employee/{employeeId}/goals
        String endpoint = GOALS_ENDPOINT.replace('{employeeId}', employeeId);

        String responseBody = MulesoftIntegrationService.callApiGetWithUserToken(endpoint);

        List<String> goalsOut = new List<String>();
        List<Object> goalsArray = (List<Object>) JSON.deserializeUntyped(responseBody);

        if (goalsArray != null) {
            for (Object g : goalsArray) {
                // If API returns objects, stringify each element
                goalsOut.add(String.valueOf(g));
            }
        }
        return goalsOut;
    }

    // Helper method to validate employee ID format if needed
    private static Boolean isValidEmployeeId(String employeeId) {
        // Add any validation logic for employee ID format
        return String.isNotBlank(employeeId) && employeeId.length() > 0;
    }
}
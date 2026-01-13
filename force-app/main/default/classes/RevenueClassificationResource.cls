/**
 * @description Grounding class for Einstein Prompt Templates
 * Winter '25 compatible version using 'Prompt' naming convention
 */
global with sharing class RevenueClassificationResource {

    /**
     * @description Input class Einstein uses to pass the "Context Record"
     */
    global class PromptRequest {
        @InvocableVariable(required=false label='Input Record')
        global SObject targetEntity;
    }

    /**
     * @description Output class with 'Prompt' variable for discovery
     */
    global class PromptResponse {
        @InvocableVariable(label='Revenue Classifications')
        global String Prompt; // CRITICAL: Named 'Prompt' for UI discovery
    }

    @InvocableMethod(
        label='Get Active Revenue Classifications'
        description='Returns active revenue classifications for Einstein Prompt Templates'
        // capabilityType removed for Winter '25 compatibility
    )
    global static List<PromptResponse> getActiveRevenueClassifications(List<PromptRequest> requests) {
        List<PromptResponse> results = new List<PromptResponse>();

        try {
            List<String> classificationList = new List<String>();

            // Query active revenue classifications
            List<RevenueClassification__c> records = [
                SELECT Name
                FROM RevenueClassification__c
                WHERE IsActive__c = true
                    AND IsRootClassification__c = false
                ORDER BY Name
                LIMIT 100
            ];

            for (RevenueClassification__c rc : records) {
                classificationList.add('"' + rc.Name + '"');
            }

            // Fallback to defaults if no records found
            if (classificationList.isEmpty()) {
                classificationList.addAll(new List<String>{
                    '"Food"', '"Beverage"', '"Labor"', '"Equipment"', '"Other"'
                });
            }

            PromptResponse res = new PromptResponse();
            res.Prompt = String.join(classificationList, ', ');
            results.add(res);

        } catch (Exception e) {
            System.debug('Error fetching revenue classifications: ' + e.getMessage());
            // Return defaults on error
            PromptResponse errorRes = new PromptResponse();
            errorRes.Prompt = '"Food", "Beverage", "Labor", "Equipment", "Other"';
            results.add(errorRes);
        }

        return results;
    }
}
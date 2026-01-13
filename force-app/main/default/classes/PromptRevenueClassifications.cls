/**
 * @description Prompt Template Resource for Revenue Classifications
 * Uses the exact structure that Prompt Builder expects
 */
global with sharing class PromptRevenueClassifications {

    /**
     * @description Request wrapper for Prompt Builder
     */
    global class Request {
        @InvocableVariable(label='Context Record')
        global SObject record;
    }

    /**
     * @description Response wrapper for Prompt Builder
     */
    global class Response {
        @InvocableVariable(label='Revenue Classifications')
        global String classifications;
    }

    /**
     * @description Returns revenue classifications for use in Prompt Templates
     * @param requests List of Request objects
     * @return List of Response objects with classifications
     */
    @InvocableMethod(
        label='Revenue Classifications for Prompts'
        description='Returns comma-separated list of active revenue classifications'
    )
    global static List<Response> execute(List<Request> requests) {
        List<Response> responses = new List<Response>();
        Response response = new Response();

        try {
            // Query active revenue classifications
            List<String> classificationNames = new List<String>();

            for (RevenueClassification__c rc : [
                SELECT Name
                FROM RevenueClassification__c
                WHERE IsActive__c = true
                    AND IsRootClassification__c = false
                ORDER BY Name
                LIMIT 100
            ]) {
                classificationNames.add('"' + rc.Name + '"');
            }

            // Use defaults if no classifications found
            if (classificationNames.isEmpty()) {
                classificationNames = new List<String>{
                    '"Food"', '"Beverage"', '"Labor"', '"Equipment"', '"Other"'
                };
            }

            response.classifications = String.join(classificationNames, ', ');

        } catch (Exception e) {
            System.debug('Error retrieving revenue classifications: ' + e.getMessage());
            // Return defaults on error
            response.classifications = '"Food", "Beverage", "Labor", "Equipment", "Other"';
        }

        responses.add(response);
        return responses;
    }
}
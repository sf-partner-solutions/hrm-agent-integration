/**
 * @description Grounding class for Einstein Prompt Templates - Revenue Classifications
 * Provides dynamic revenue classification data as a resource
 */
public with sharing class RevenueClassificationGrounding {

    /**
     * @description Simple method that returns revenue classifications as a string
     * This follows the pattern for Prompt Builder flex template resources
     * @return Comma-separated list of revenue classifications
     */
    @InvocableMethod(
        label='Get Revenue Classifications for Prompts'
        description='Returns available revenue classifications'
    )
    public static List<String> getClassifications() {
        List<String> output = new List<String>();

        try {
            List<String> classifications = new List<String>();

            // Query active revenue classifications
            List<RevenueClassification__c> records = [
                SELECT Name
                FROM RevenueClassification__c
                WHERE IsActive__c = true
                    AND IsRootClassification__c = false
                ORDER BY Name
                LIMIT 100
            ];

            // Build the list
            for (RevenueClassification__c rc : records) {
                classifications.add('"' + rc.Name + '"');
            }

            // Use defaults if empty
            if (classifications.isEmpty()) {
                classifications.add('"Food"');
                classifications.add('"Beverage"');
                classifications.add('"Labor"');
                classifications.add('"Equipment"');
                classifications.add('"Other"');
            }

            // Return as a single comma-separated string
            output.add(String.join(classifications, ', '));

        } catch (Exception e) {
            System.debug('Error in RevenueClassificationGrounding: ' + e.getMessage());
            // Return defaults on error
            output.add('"Food", "Beverage", "Labor", "Equipment", "Other"');
        }

        return output;
    }
}
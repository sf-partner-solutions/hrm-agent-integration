/**
 * @description Einstein Prompt Template Resource for Revenue Classifications
 * Implements the simplest possible invocable method for Prompt Builder
 */
public class EinsteinRevenueClassifications {

    /**
     * @description Returns revenue classifications for Einstein Prompt Templates
     * Uses the simplest possible signature: void input, String output
     */
    @InvocableMethod(label='Einstein Revenue Classifications')
    public static List<String> execute() {
        // Query and return classifications
        String result = '';

        try {
            List<RevenueClassification__c> classifications = [
                SELECT Name
                FROM RevenueClassification__c
                WHERE IsActive__c = true
                AND IsRootClassification__c = false
                ORDER BY Name
            ];

            if (!classifications.isEmpty()) {
                List<String> names = new List<String>();
                for (RevenueClassification__c rc : classifications) {
                    names.add('"' + rc.Name + '"');
                }
                result = String.join(names, ', ');
            } else {
                result = '"Food", "Beverage", "Labor", "Equipment", "Other"';
            }
        } catch (Exception e) {
            result = '"Food", "Beverage", "Labor", "Equipment", "Other"';
        }

        return new List<String>{ result };
    }
}
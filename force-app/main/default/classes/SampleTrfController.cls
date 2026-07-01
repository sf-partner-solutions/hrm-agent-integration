/**
 * Controller for the Sample Import flow.
 * - createSample: inserts a single Sample__c record from the preview form.
 * - getRecentSamples: powers the home banner list.
 */
public with sharing class SampleTrfController {

    public class CreateResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String recordName;
        @AuraEnabled public String errorMessage;
    }

    @AuraEnabled
    public static CreateResult createSample(Map<String, Object> data) {
        CreateResult result = new CreateResult();
        try {
            Sample__c rec = SampleTrfParser.toSampleRecord(data);
            insert rec;

            // Re-query for the auto-numbered Name
            Sample__c saved = [SELECT Id, Name FROM Sample__c WHERE Id = :rec.Id LIMIT 1];
            result.success = true;
            result.recordId = saved.Id;
            result.recordName = saved.Name;
            return result;
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
            return result;
        }
    }

    /**
     * Returns the ContentVersion Id (latest) for a given ContentDocument Id.
     * Used by the side-by-side review LWC to render the uploaded PDF
     * via `/sfc/servlet.shepherd/version/download/{contentVersionId}`.
     */
    @AuraEnabled(cacheable=true)
    public static String getContentVersionId(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) return null;
        List<ContentVersion> versions = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
            LIMIT 1
        ];
        return versions.isEmpty() ? contentDocumentId : versions[0].Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<Sample__c> getRecentSamples() {
        return [
            SELECT Id, Name, Sample_ID__c, Customer_Sample_Name__c, Sample_Type__c,
                   Date_of_Collection__c, Box_ID__c, Status__c
            FROM Sample__c
            ORDER BY CreatedDate DESC
            LIMIT 15
        ];
    }
}

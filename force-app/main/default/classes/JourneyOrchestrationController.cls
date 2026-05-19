public with sharing class JourneyOrchestrationController {

    @AuraEnabled(cacheable=true)
    public static List<JourneyDTO> getJourneys() {
        List<JourneyDTO> result = new List<JourneyDTO>();
        for (FlowDefinitionView f : [
            SELECT DurableId, ApiName, Label, Description, IsActive, ProcessType,
                   LastModifiedDate, LatestVersionId, ActiveVersionId
            FROM FlowDefinitionView
            WHERE ApiName LIKE 'JO_%'
              AND (NOT ApiName LIKE 'JOT_%')
            ORDER BY Label
        ]) {
            result.add(new JourneyDTO(f));
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<JourneyDTO> getTemplates() {
        List<JourneyDTO> result = new List<JourneyDTO>();
        for (FlowDefinitionView f : [
            SELECT DurableId, ApiName, Label, Description, IsActive, ProcessType,
                   LastModifiedDate, LatestVersionId, ActiveVersionId
            FROM FlowDefinitionView
            WHERE ApiName LIKE 'JOT_%'
            ORDER BY Label
        ]) {
            result.add(new JourneyDTO(f));
        }
        return result;
    }

    public class JourneyDTO {
        @AuraEnabled public String durableId;
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String processType;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public String latestVersionId;
        @AuraEnabled public String activeVersionId;
        @AuraEnabled public String category;

        public JourneyDTO(FlowDefinitionView f) {
            this.durableId = f.DurableId;
            this.apiName = f.ApiName;
            this.label = f.Label;
            this.description = f.Description;
            this.isActive = f.IsActive;
            this.processType = f.ProcessType;
            this.lastModifiedDate = f.LastModifiedDate;
            this.latestVersionId = f.LatestVersionId;
            this.activeVersionId = f.ActiveVersionId;
            this.category = deriveCategory(f.ApiName, f.Description);
        }

        private String deriveCategory(String apiName, String descr) {
            if (String.isNotBlank(descr)) {
                Matcher m = Pattern.compile('\\[category:([A-Z_]+)\\]').matcher(descr);
                if (m.find()) {
                    return m.group(1);
                }
            }
            return 'CUSTOM';
        }
    }
}

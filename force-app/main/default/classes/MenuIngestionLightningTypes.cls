/**
 * @description Lightning Type wrapper classes for Menu Ingestion components
 */
public with sharing class MenuIngestionLightningTypes {

    /**
     * @description Wrapper for menu upload handler response
     */
    public class MenuUploadResponse {
        @AuraEnabled public String message;
        @AuraEnabled public String recordId;
    }

    /**
     * @description Wrapper for menu items preview response
     */
    public class MenuPreviewResponse {
        @AuraEnabled public BanquetMenuParser.MenuExtractionResponse data;
    }

    /**
     * @description Wrapper for menu ingestion success response
     */
    public class MenuSuccessResponse {
        @AuraEnabled public Integer successCount;
        @AuraEnabled public List<String> createdItemIds;
        @AuraEnabled public String message;
    }

    /**
     * @description Wrapper for menu items editor response
     */
    public class MenuEditorResponse {
        @AuraEnabled public List<BanquetMenuParser.MenuItem> items;
    }
}
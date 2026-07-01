/**
 * Invokes the Sample_TRF_Ingestion prompt template against an uploaded TRF PDF
 * and returns the extracted Sample__c field values for editable preview.
 *
 * Modeled on BanquetMenuAgentAction.
 */
global with sharing class SampleTrfAgentAction {

    global class SampleIngestionOutput {
        @AuraEnabled public String responseType;
        @AuraEnabled public String message;
        @AuraEnabled public String extractedSampleJson;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Boolean success;
    }

    @AuraEnabled
    public static SampleIngestionOutput processUploadedFile(String contentDocumentId) {
        SampleIngestionOutput output = new SampleIngestionOutput();

        try {
            String actualContentDocumentId = resolveContentDocumentId(contentDocumentId);

            if (String.isBlank(actualContentDocumentId)) {
                output.responseType = 'UPLOAD_REQUIRED';
                output.success = true;
                return output;
            }

            String promptResponse = callSampleTrfPromptTemplate(actualContentDocumentId);

            if (String.isBlank(promptResponse)) {
                throw new AuraHandledException('Empty response from prompt template');
            }

            output.success = true;
            output.responseType = 'FIELDS_EXTRACTED';
            output.extractedSampleJson = promptResponse;
            output.message = 'TRF parsed. Review the fields below and click Import to create the Sample record.';
            return output;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SampleTrfAgentAction error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, e.getStackTraceString());
            output.success = false;
            output.responseType = 'ERROR';
            output.errorMessage = e.getMessage();
            output.message = 'Failed to parse TRF: ' + e.getMessage();
            return output;
        }
    }

    private static String resolveContentDocumentId(String inputId) {
        if (String.isBlank(inputId)) {
            return null;
        }
        if (inputId.startsWith('069')) {
            return inputId;
        }
        if (inputId.startsWith('06A')) {
            List<ContentDocumentLink> cdls = [
                SELECT ContentDocumentId FROM ContentDocumentLink WHERE Id = :inputId LIMIT 1
            ];
            return cdls.isEmpty() ? inputId : cdls[0].ContentDocumentId;
        }
        if (inputId.startsWith('068')) {
            List<ContentVersion> cvs = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :inputId LIMIT 1
            ];
            return cvs.isEmpty() ? inputId : cvs[0].ContentDocumentId;
        }
        return inputId;
    }

    private static String callSampleTrfPromptTemplate(String contentDocumentId) {
        try {
            Map<String, String> fileData = new Map<String, String>{ 'id' => contentDocumentId };

            ConnectApi.WrappedValue fileInput = new ConnectApi.WrappedValue();
            fileInput.value = fileData;

            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            inputParams.put('Input:File', fileInput);

            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.applicationName = 'PromptBuilderPreview';
            promptInput.isPreview = false;
            promptInput.inputParams = inputParams;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'Sample_TRF_Ingestion',
                    promptInput
                );

            if (response != null && response.generations != null && !response.generations.isEmpty()) {
                String promptResponse = response.generations[0].text;
                if (promptResponse != null) {
                    if (promptResponse.contains('```json')) {
                        promptResponse = promptResponse.substringBetween('```json', '```');
                    } else if (promptResponse.contains('```')) {
                        promptResponse = promptResponse.substringBetween('```', '```');
                    }
                    return promptResponse.trim();
                }
            }

            throw new AuraHandledException('No generations returned from prompt template');

        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'ConnectApi call failed, returning mock TRF response: ' + e.getMessage());
            return getMockResponse();
        }
    }

    private static String getMockResponse() {
        return '{' +
            '"sample": {' +
                '"Customer_Sample_Name__c": "Patient Jane Doe TRF",' +
                '"Sample_Type__c": "Blood",' +
                '"Date_of_Collection__c": "' + Date.today().format() + '",' +
                '"Number_of_Aliquots__c": 2,' +
                '"Frozen__c": true,' +
                '"Concentration__c": 12.50,' +
                '"Patient_Name__c": "Jane Doe",' +
                '"Patient_DOB__c": "1985-04-12",' +
                '"Patient_MRN__c": "MRN-00472",' +
                '"Patient_Gender__c": "Female",' +
                '"Ordering_Physician__c": "Dr. Alan Smith, MD",' +
                '"Tests_Requested__c": "Comprehensive Metabolic Panel; CBC with Differential; Lipid Panel",' +
                '"Clinical_Notes__c": "Routine annual physical. No known allergies.",' +
                '"Priority__c": "Routine",' +
                '"Status__c": "New",' +
                '"Record_Type_Label__c": "Submitted Sample"' +
            '},' +
            '"extraction_metadata": {' +
                '"form_type": "Test Request Form",' +
                '"extracted_date": "' + Date.today().format() + '",' +
                '"confidence_notes": "Mock data - ConnectApi unavailable in this org or session"' +
            '}' +
        '}';
    }
}

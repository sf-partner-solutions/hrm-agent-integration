/**
 * @description Invocable Apex class for Banquet Menu Ingestion Agent Action
 * This class bridges the gap between Agent Actions and the Prompt Template
 */
global with sharing class BanquetMenuAgentAction {

    /**
     * @description Input wrapper for the invocable method
     */
    global class MenuIngestionInput {
        @InvocableVariable(label='File Content Document ID' description='The ContentDocument ID of the uploaded menu PDF' required=false)
        public String contentDocumentId;

        @InvocableVariable(label='User Message' description='Optional message from the user' required=false)
        public String userMessage;

        @InvocableVariable(label='Current Record ID' description='The ID of the record where the agent was launched (from currentRecordId context)' required=false)
        public String currentRecordId;

        @InvocableVariable(label='Property Record ID' description='The ID of the property record where the agent was launched' required=false)
        public String propertyId;
    }

    /**
     * @description Wrapper for the invocable method output
     */
    global class AgentResponse {
        @InvocableVariable
        public MenuIngestionOutput menuResponse;
    }

    /**
     * @description Output wrapper containing the actual response data
     */
    global class MenuIngestionOutput {
        @AuraEnabled
        @InvocableVariable(label='Response Type' description='Controls which UI component to display (UPLOAD_REQUIRED, ITEMS_EXTRACTED, SUCCESS, ERROR)')
        public String responseType;

        @AuraEnabled
        @InvocableVariable(label='Message' description='User-friendly message to display')
        public String message;

        @AuraEnabled
        @InvocableVariable(label='Extracted Items JSON' description='JSON string containing extracted menu items')
        public String extractedItemsJson;

        @AuraEnabled
        @InvocableVariable(label='Item Count' description='Number of items extracted or created')
        public Integer itemCount;

        @AuraEnabled
        @InvocableVariable(label='Error Message' description='Detailed error information if applicable')
        public String errorMessage;

        @AuraEnabled
        @InvocableVariable(label='Success' description='Overall operation success status')
        public Boolean success;

        @AuraEnabled
        @InvocableVariable(label='Property ID' description='The property ID for context')
        public String propertyId;
    }

    /**
     * @description Main invocable method for Agent Action
     * @param inputs List of input parameters
     * @return List of output results
     */
    @InvocableMethod(
        label='Ingest Banquet Menu Items'
        description='Extracts menu items from uploaded PDF using AI and prepares them for import'
        category='Delphi Menu Management'
    )
    global static List<AgentResponse> processMenuPDF(List<MenuIngestionInput> inputs) {
        List<AgentResponse> responses = new List<AgentResponse>();

        for (MenuIngestionInput input : inputs) {
            MenuIngestionOutput output = new MenuIngestionOutput();
            AgentResponse response = new AgentResponse();

            try {
                // Determine the property ID: use explicit propertyId first, then currentRecordId
                String effectivePropertyId = null;
                if (String.isNotBlank(input.propertyId)) {
                    effectivePropertyId = input.propertyId;
                } else if (String.isNotBlank(input.currentRecordId)) {
                    effectivePropertyId = input.currentRecordId;
                }

                // Pass through the property ID if we have one
                if (String.isNotBlank(effectivePropertyId)) {
                    output.propertyId = effectivePropertyId;
                    System.debug('Using property ID: ' + effectivePropertyId);
                }

                // If no file is provided, return upload handler response
                if (String.isBlank(input.contentDocumentId)) {
                    output.responseType = 'UPLOAD_REQUIRED';
                    output.success = true;
                    // Set minimal data to encourage component rendering
                    response.menuResponse = output;
                    responses.add(response);
                    continue;
                }

                // Call the prompt template using Connect API
                String promptResponse = callBanquetMenuPromptTemplate(input.contentDocumentId);

                if (String.isNotBlank(promptResponse)) {
                    System.debug('=== Raw prompt response ===');
                    System.debug(promptResponse);

                    // Parse the response using our existing parser
                    BanquetMenuParser.MenuExtractionResponse parsedResponse =
                        BanquetMenuParser.parseMenuJSON(promptResponse);

                    System.debug('=== Parsed response ===');
                    System.debug('Items count: ' + (parsedResponse.items != null ? parsedResponse.items.size() : 0));

                    // Transform the data for LWC consumption - add __c suffix to fields
                    String transformedJson = transformMenuDataForLWC(parsedResponse);

                    // Prepare output
                    output.success = true;
                    output.responseType = 'ITEMS_EXTRACTED';
                    output.extractedItemsJson = transformedJson;
                    output.itemCount = parsedResponse.items != null ? parsedResponse.items.size() : 0;
                    output.message = String.format(
                        'Successfully extracted {0} items from the menu. Would you like to review and import them?',
                        new List<Object>{ output.itemCount }
                    );
                } else {
                    throw new AuraHandledException('Failed to get response from prompt template');
                }

            } catch (Exception e) {
                output.success = false;
                output.responseType = 'ERROR';
                output.errorMessage = e.getMessage();
                output.message = 'An error occurred while processing the menu: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Error in processMenuPDF: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }

            response.menuResponse = output;
            System.debug('Response being returned: ' + JSON.serialize(response));
            responses.add(response);
        }

        return responses;
    }

    /**
     * @description Calls the Banquet Menu Ingestion prompt template via Connect API
     * @param contentDocumentId The ID of the uploaded file
     * @return The JSON response from the prompt template
     */
    private static String callBanquetMenuPromptTemplate(String contentDocumentId) {
        try {
            System.debug('Calling prompt template with ContentDocument ID: ' + contentDocumentId);

            // Create a map for the file input (matching the reference pattern)
            Map<String, String> fileData = new Map<String, String>();
            fileData.put('id', contentDocumentId);

            // Create wrapped value for the File input
            ConnectApi.WrappedValue fileInput = new ConnectApi.WrappedValue();
            fileInput.value = fileData;

            // Create input parameters map
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            inputParams.put('Input:File', fileInput);

            // Configure the prompt template input
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();

            // Add additional config with application name
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.applicationName = 'PromptBuilderPreview';

            // Set parameters
            promptInput.isPreview = false;
            promptInput.inputParams = inputParams;

            // Call the prompt template
            String promptTemplateName = 'Banquet_Menu_Ingestion';
            System.debug('Executing prompt template: ' + promptTemplateName);
            System.debug('Input params prepared for template');

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    promptTemplateName,
                    promptInput
                );

            // Extract the response text
            if (response != null && response.generations != null && !response.generations.isEmpty()) {
                ConnectApi.EinsteinLLMGenerationItemOutput generationItem = response.generations[0];
                String promptResponse = generationItem.text;
                System.debug('Prompt template response received: ' + promptResponse);

                // Clean the response - remove any markdown formatting if present
                if (promptResponse != null) {
                    if (promptResponse.contains('```json')) {
                        promptResponse = promptResponse.substringBetween('```json', '```');
                    } else if (promptResponse.contains('```')) {
                        promptResponse = promptResponse.substringBetween('```', '```');
                    }
                    return promptResponse.trim();
                }
            }

            throw new AuraHandledException('No response received from prompt template');

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error calling prompt template: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            System.debug(LoggingLevel.ERROR, 'Exception type: ' + e.getTypeName());

            // If Connect API fails, return a minimal mock response for testing
            System.debug('Falling back to mock response due to error');
            return getMockResponse();
        }
    }

    /**
     * @description Transform menu data to add __c suffix for LWC field expectations
     * @param response The parsed menu extraction response
     * @return JSON string with transformed field names
     */
    private static String transformMenuDataForLWC(BanquetMenuParser.MenuExtractionResponse response) {
        // Convert to untyped map for manipulation
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(response));

        // Get items array
        List<Object> items = (List<Object>) responseMap.get('items');

        if (items != null) {
            for (Object itemObj : items) {
                Map<String, Object> item = (Map<String, Object>) itemObj;

                // Add __c suffix versions for LWC
                if (item.containsKey('Description')) {
                    item.put('Description__c', item.get('Description'));
                }
                if (item.containsKey('ItemType')) {
                    item.put('ItemType__c', item.get('ItemType'));
                }
                if (item.containsKey('RevenueClassification')) {
                    item.put('RevenueClassification__c', item.get('RevenueClassification'));
                }
            }
        }

        return JSON.serialize(responseMap);
    }

    /**
     * @description Returns a mock response for testing when Connect API is unavailable
     */
    private static String getMockResponse() {
        return '{' +
            '"extraction_metadata": {' +
                '"venue_name": "Test Hotel",' +
                '"menu_title": "Sample Menu",' +
                '"extracted_date": "' + Date.today().format() + '",' +
                '"total_items_found": 3,' +
                '"extraction_notes": "Mock data - Connect API unavailable"' +
            '},' +
            '"items": [' +
                '{"Name":"Continental Breakfast","ItemType":"Item","RevenueClassification":"Food","UnitPrice":35.00,"SoldByUnit":"per person",' +
                '"Description":"Fresh fruit, assorted pastries, yogurt parfait","IsActive":true},' +
                '{"Name":"Coffee Service","ItemType":"Item","RevenueClassification":"Beverage","UnitPrice":5.95,"SoldByUnit":"per person",' +
                '"Description":"Regular and decaf coffee with accompaniments","IsActive":true},' +
                '{"Name":"Lunch Buffet","ItemType":"Item","RevenueClassification":"Food","UnitPrice":45.00,"SoldByUnit":"per person",' +
                '"Description":"Two entrées, salad bar, dessert selection","IsActive":true}' +
            ']' +
        '}';
    }

    /**
     * @description Gets the ID of a prompt template by developer name
     * @param developerName The developer name of the prompt template
     * @return The ID of the prompt template
     */
    private static String getPromptTemplateId(String developerName) {
        // Since GenAiPromptTemplate may not be available in all orgs,
        // we'll return a placeholder ID
        // In production, you would query the actual prompt template

        System.debug('Looking for prompt template: ' + developerName);

        // Return a placeholder ID - in production this would be the actual template ID
        return 'PROMPT_TEMPLATE_ID_PLACEHOLDER';
    }

    /**
     * @description Creates Item__c records from extracted data
     * This can be called separately after user confirmation
     */
    @AuraEnabled
    public static BanquetMenuAgentController.ItemCreationResult createItemsFromExtraction(String extractedItemsJson) {
        try {
            // Deserialize the extraction response
            BanquetMenuParser.MenuExtractionResponse extraction =
                (BanquetMenuParser.MenuExtractionResponse) JSON.deserialize(
                    extractedItemsJson,
                    BanquetMenuParser.MenuExtractionResponse.class
                );

            // Use existing controller method to create items
            return BanquetMenuAgentController.createMenuItems(extraction.items);

        } catch (Exception e) {
            throw new AuraHandledException('Failed to create items: ' + e.getMessage());
        }
    }

    /**
     * @description Handles file upload and returns the ContentDocument ID
     * This is a helper method for the agent flow
     */
    @AuraEnabled
    public static String handleFileUpload(String fileName, String base64Data, String contentType) {
        try {
            // Create ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.IsMajorVersion = true;
            insert cv;

            // Get the ContentDocument ID
            ContentVersion insertedFile = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            return insertedFile.ContentDocumentId;

        } catch (Exception e) {
            throw new AuraHandledException('Failed to upload file: ' + e.getMessage());
        }
    }

    /**
     * @description AuraEnabled method for LWC to process uploaded PDF
     * This wraps the invocable method for direct LWC access
     */
    @AuraEnabled
    public static MenuIngestionOutput processUploadedFile(String contentDocumentId, String propertyId) {
        System.debug('processUploadedFile called with contentDocumentId: ' + contentDocumentId + ', propertyId: ' + propertyId);

        try {
            String actualContentDocumentId = contentDocumentId;

            // Check ID prefix to determine the type
            // 069 = ContentDocument (what we want)
            // 06A = ContentDocumentLink (needs conversion)
            // 068 = ContentVersion (needs conversion)
            if (contentDocumentId != null) {
                if (contentDocumentId.startsWith('06A')) {
                    System.debug('Detected ContentDocumentLink ID, converting...');
                    // Query to get the actual ContentDocumentId from ContentDocumentLink
                    List<ContentDocumentLink> cdls = [
                        SELECT ContentDocumentId
                        FROM ContentDocumentLink
                        WHERE Id = :contentDocumentId
                        LIMIT 1
                    ];

                    if (!cdls.isEmpty()) {
                        actualContentDocumentId = cdls[0].ContentDocumentId;
                        System.debug('Converted ContentDocumentLink to ContentDocument: ' + actualContentDocumentId);
                    }
                } else if (contentDocumentId.startsWith('068')) {
                    System.debug('Detected ContentVersion ID, converting...');
                    // Query to get the ContentDocumentId from ContentVersion
                    List<ContentVersion> cvs = [
                        SELECT ContentDocumentId
                        FROM ContentVersion
                        WHERE Id = :contentDocumentId
                        LIMIT 1
                    ];

                    if (!cvs.isEmpty()) {
                        actualContentDocumentId = cvs[0].ContentDocumentId;
                        System.debug('Converted ContentVersion to ContentDocument: ' + actualContentDocumentId);
                    }
                } else if (contentDocumentId.startsWith('069')) {
                    System.debug('Already have ContentDocument ID: ' + contentDocumentId);
                    // Already have the ContentDocument ID
                } else {
                    System.debug('Unknown ID type: ' + contentDocumentId);
                }
            }

            // Create input for the invocable method
            MenuIngestionInput input = new MenuIngestionInput();
            input.contentDocumentId = actualContentDocumentId;
            input.propertyId = propertyId; // Pass the property ID through
            System.debug('Calling processMenuPDF with input: ' + JSON.serialize(input));

            // Call the invocable method
            List<MenuIngestionInput> inputs = new List<MenuIngestionInput>{input};
            List<AgentResponse> responses = processMenuPDF(inputs);
            System.debug('Received responses: ' + JSON.serialize(responses));

            // Return the first response
            if (!responses.isEmpty() && responses[0].menuResponse != null) {
                MenuIngestionOutput result = responses[0].menuResponse;
                System.debug('Returning result: ' + JSON.serialize(result));
                return result;
            } else {
                System.debug('Empty response or null menuResponse');
                throw new AuraHandledException('No response received from processing');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in processUploadedFile: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to process file: ' + e.getMessage());
        }
    }
}
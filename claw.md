# Salesforce Lightning Types and Agent Actions Pattern

## Critical Pattern for Custom Lightning Types in Agent Actions

### The Working Pattern (IMPORTANT)

When creating custom Lightning Types for Salesforce Agent Actions with custom LWC rendering, you MUST follow this specific wrapper pattern:

#### 1. Apex Class Structure

```apex
global with sharing class YourAgentAction {

    // Input wrapper class
    global class YourInput {
        @InvocableVariable(label='Input Field' required=false)
        public String inputField;
    }

    // CRITICAL: Wrapper class for the invocable method output
    global class AgentResponse {
        @InvocableVariable
        public YourActualOutput outputField;  // Single field pointing to actual output
    }

    // The actual output class with all your data
    global class YourActualOutput {
        @InvocableVariable(label='Field 1')
        public String field1;

        @InvocableVariable(label='Field 2')
        public Integer field2;

        // ... all your actual output fields
    }

    @InvocableMethod(label='Your Action Label')
    global static List<AgentResponse> yourMethod(List<YourInput> inputs) {
        List<AgentResponse> responses = new List<AgentResponse>();

        for (YourInput input : inputs) {
            YourActualOutput output = new YourActualOutput();
            AgentResponse response = new AgentResponse();

            // ... your logic to populate output ...

            response.outputField = output;  // Wrap the output
            responses.add(response);
        }

        return responses;  // Return the wrapper list
    }
}
```

#### 2. Lightning Type Configuration

**Directory Structure:**
```
lightningTypes/
  yourResponseType/
    schema.json
    yourResponseType.lightningType-meta.xml
    lightningDesktopGenAi/
      renderer.json
```

**schema.json:**
```json
{
  "title": "Your Response Type",
  "lightning:type": "@apexClassType/YourAgentAction$YourActualOutput"
}
```
Note: Reference the ACTUAL OUTPUT class, NOT the wrapper AgentResponse class!

**renderer.json (in lightningDesktopGenAi/):**
```json
{
  "renderer": {
    "componentOverrides": {
      "$": {
        "definition": "c/yourLwcComponent"
      }
    }
  }
}
```

**yourResponseType.lightningType-meta.xml:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningType xmlns="http://soap.sforce.com/2006/04/metadata">
    <masterLabel>Your Response Type</masterLabel>
    <description>Description of your Lightning Type</description>
</LightningType>
```

#### 3. LWC Configuration - CRITICAL VALUE PATTERN

**⚠️ MOST IMPORTANT: The LWC MUST use a `value` property with getter/setter pattern!**

**yourLwcComponent.js:**
```javascript
import { LightningElement, api } from 'lwc';

export default class YourLwcComponent extends LightningElement {
    _value;

    // Individual properties for template use
    responseType;
    message;
    // ... other properties

    @api
    get value() {
        return this._value;
    }

    set value(value) {
        this._value = value;
        console.log('Component received value:', JSON.stringify(value));

        // CRITICAL: Extract properties from the value object
        if (value) {
            this.responseType = value.responseType;
            this.message = value.message;
            // ... map all properties from value object
        }
    }

    connectedCallback() {
        console.log('Component connected with value:', this._value);
    }

    // Your component logic here
}
```

**yourLwcComponent.js-meta.xml:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>64.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__AgentforceOutput</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__AgentforceOutput">
            <sourceType name="c__yourResponseType" />
        </targetConfig>
    </targetConfigs>
    <masterLabel>Your LWC Component</masterLabel>
</LightningComponentBundle>
```

#### 4. Key Requirements

1. **Apex Class MUST be `global`** - Both the main class and all inner classes
2. **Use Wrapper Pattern** - The @InvocableMethod returns List<WrapperClass> where WrapperClass has a single @InvocableVariable pointing to the actual output class
3. **Lightning Type References Actual Output** - The schema.json references YourActualOutput, not the wrapper
4. **Renderer in Subdirectory** - renderer.json must be in lightningDesktopGenAi/ subdirectory
5. **Forward Slash in Definition** - Use c/componentName not c:componentName
6. **targetConfig in LWC** - Must have sourceType pointing to c__yourLightningType
7. **⚠️ LWC MUST use `value` property** - Agentforce passes data through a single `value` property, NOT individual @api properties

### Common Pitfalls to Avoid

1. **DON'T** return the output class directly from @InvocableMethod
2. **DON'T** reference the wrapper class in Lightning Type schema.json
3. **DON'T** put renderer.json at the root level
4. **DON'T** add property mappings in targetConfig (keep it simple)
5. **DON'T** forget to make classes global
6. **⚠️ DON'T use individual @api properties** - Must use `value` property with getter/setter
7. **DON'T** expect data without the value pattern - Component will load but receive no data

### Working Example from this Project

- **Apex Class**: BanquetMenuAgentAction
  - Wrapper: AgentResponse (with single field `menuResponse`)
  - Actual Output: MenuIngestionOutput
- **Lightning Type**: banquetMenuResponse
  - References: BanquetMenuAgentAction$MenuIngestionOutput
- **LWC**: banquetMenuRouter
  - Routes to different child components based on responseType

### Agent Action Configuration

When creating the Agent Action:
1. Select your Apex class
2. You'll see ONE output field (the wrapper field, e.g., `menuResponse`)
3. Select your custom Lightning Type in "Output Rendering" dropdown
4. The Lightning Type should appear if everything is configured correctly

### Troubleshooting

If Lightning Type doesn't appear in dropdown:
1. Verify Apex class and inner classes are `global`
2. Check Lightning Type references the correct inner class
3. Ensure renderer.json is in lightningDesktopGenAi/ subdirectory
4. Confirm LWC has proper targetConfig with sourceType
5. Deploy all components successfully

If Lightning Component doesn't render (but action executes):
1. **⚠️ MOST LIKELY CAUSE: LWC is missing the `value` property pattern**
2. Check browser console for errors
3. Verify "Show in conversation" is checked in Agent Action config
4. Ensure Output Rendering is set to your Lightning Type
5. Test with a simple div to confirm component loads

### The Critical Discovery

After extensive troubleshooting, the key finding was that **Agentforce passes data to LWCs through a single `value` property**, not through individual @api properties. This pattern is:
- Not documented in most Salesforce documentation
- Essential for the component to receive any data
- The difference between a working and non-working implementation

Without this pattern, your component will load but will receive no data, appearing as if it's not rendering at all.

---

## Connect API Pattern for Calling Prompt Templates

### Successfully Working Pattern for Einstein Prompt Template Execution

#### Prerequisites
1. **Einstein Generative AI** must be enabled in the org
2. **Prompt Template** must be in "Published" status (not Draft)
3. **User Permissions** required:
   - System Permission: "Run Prompt Templates"
   - Object Permission: "AI Prompt Template Generated Events" (Read)
   - API Enabled

#### Apex Implementation Pattern

```apex
/**
 * Successful pattern for calling Einstein Prompt Templates via Connect API
 * This pattern has been tested and verified working
 */
private static String callPromptTemplate(String contentDocumentId) {
    try {
        // STEP 1: Create input data structure as a Map
        // IMPORTANT: Must use Map structure, not simple string
        Map<String, String> fileData = new Map<String, String>();
        fileData.put('id', contentDocumentId);  // 'id' is the key expected by most templates

        // STEP 2: Wrap the input in ConnectApi.WrappedValue
        ConnectApi.WrappedValue fileInput = new ConnectApi.WrappedValue();
        fileInput.value = fileData;  // Assign the Map to value property

        // STEP 3: Create the input parameters map
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
        inputParams.put('Input:File', fileInput);  // Key must match prompt template input name

        // STEP 4: Configure the prompt template input
        ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();

        // STEP 5: Add additional config with application name (REQUIRED)
        promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        promptInput.additionalConfig.applicationName = 'PromptBuilderPreview';

        // STEP 6: Set parameters
        promptInput.isPreview = false;  // Set to true for testing without consuming credits
        promptInput.inputParams = inputParams;

        // STEP 7: Call the prompt template
        String promptTemplateName = 'Your_Prompt_Template_DeveloperName';

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                promptTemplateName,
                promptInput
            );

        // STEP 8: Extract the response
        if (response != null && response.generations != null && !response.generations.isEmpty()) {
            ConnectApi.EinsteinLLMGenerationItemOutput generationItem = response.generations[0];
            String promptResponse = generationItem.text;

            // Clean markdown formatting if present
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
        System.debug(LoggingLevel.ERROR, 'Error: ' + e.getMessage());
        throw new AuraHandledException('Failed to call prompt template: ' + e.getMessage());
    }
}
```

#### Key Points for Success

1. **Input Structure**:
   - Must use Map<String, String> for input data
   - The Map must have an 'id' key (or whatever key your template expects)
   - DO NOT pass simple string values directly

2. **Application Name**:
   - MUST set `additionalConfig.applicationName = 'PromptBuilderPreview'`
   - This is required for the API to work correctly

3. **Input Parameter Key**:
   - Must match the input name defined in your prompt template
   - Format: `'Input:YourInputName'` (e.g., 'Input:File')

4. **Error Handling**:
   - Common error: "Only output types from ConnectApi support serialization"
   - This happens if you try to serialize ConnectApi objects with JSON.serialize()
   - Solution: Remove any JSON.serialize() calls on ConnectApi objects

5. **Response Processing**:
   - Response comes in `response.generations[0].text`
   - May contain markdown formatting that needs to be stripped
   - Always check for null/empty responses

#### Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "sObject type 'GenAiPromptTemplate' is not supported" | Einstein features not enabled | Contact Salesforce to enable Einstein Generative AI |
| "Failed to generate Einstein LLM generations response" | Missing permissions or credits | Check user permissions and Einstein credit availability |
| "Only output types from ConnectApi support serialization" | Trying to serialize ConnectApi objects | Remove JSON.serialize() on ConnectApi objects |
| No data returned but no error | Input structure incorrect | Ensure using Map structure with correct keys |

#### Working Example from This Project

```apex
// From BanquetMenuAgentAction.cls
private static String callBanquetMenuPromptTemplate(String contentDocumentId) {
    // Create input as Map
    Map<String, String> fileData = new Map<String, String>();
    fileData.put('id', contentDocumentId);

    // Wrap in ConnectApi.WrappedValue
    ConnectApi.WrappedValue fileInput = new ConnectApi.WrappedValue();
    fileInput.value = fileData;

    // Add to parameters
    Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
    inputParams.put('Input:File', fileInput);

    // Configure prompt input
    ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput =
        new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
    promptInput.additionalConfig.applicationName = 'PromptBuilderPreview';
    promptInput.isPreview = false;
    promptInput.inputParams = inputParams;

    // Call template
    ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
        ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
            'Banquet_Menu_Ingestion',
            promptInput
        );

    // Process response...
}
```

#### Prompt Template Configuration

Ensure your prompt template (GenAiPromptTemplate metadata) has:
- Status: Published (not Draft)
- Input defined with appropriate name and type
- Visibility: Global (if calling from different contexts)

---

## Apex Resources for Prompt Builder (Winter '25)

### Critical Requirements for Apex Classes to Appear in Prompt Builder

After extensive troubleshooting, here are the EXACT requirements for creating Apex resources that will be discoverable by Einstein Prompt Builder:

#### The Working Pattern

```apex
/**
 * MUST be global class (not public)
 */
global with sharing class YourPromptResource {

    /**
     * Input class - REQUIRED even if not used
     * Must follow this exact structure
     */
    global class PromptRequest {
        @InvocableVariable(required=false label='Input Record')
        global SObject targetEntity;
    }

    /**
     * Output class - CRITICAL: Variable MUST be named 'Prompt'
     * This is the magic that makes it discoverable in Winter '25
     */
    global class PromptResponse {
        @InvocableVariable(label='Your Label Here')
        global String Prompt;  // MUST be named 'Prompt' with capital P
    }

    /**
     * The invocable method
     * DO NOT include capabilityType attribute (removed in Winter '25)
     */
    @InvocableMethod(
        label='Your Resource Label'
        description='Description for Prompt Builder'
        // NO capabilityType - causes deployment errors in Winter '25
    )
    global static List<PromptResponse> execute(List<PromptRequest> requests) {
        List<PromptResponse> responses = new List<PromptResponse>();
        PromptResponse response = new PromptResponse();

        try {
            // Your logic here to generate the prompt data
            String data = 'Your dynamic data';

            // MUST set the 'Prompt' field
            response.Prompt = data;

        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            response.Prompt = 'Default fallback value';
        }

        responses.add(response);
        return responses;
    }
}
```

#### Key Requirements (Winter '25)

1. **Class Visibility**: MUST be `global`, not `public`

2. **Request/Response Pattern**:
   - Must have inner classes for Request and Response
   - Request class must have an SObject field (even if unused)
   - Response class must have a String field named exactly `Prompt`

3. **The 'Prompt' Variable**:
   - ⚠️ **MOST CRITICAL**: The output variable MUST be named `Prompt` (capital P)
   - This is an undocumented requirement for Winter '25
   - Without this exact naming, the resource won't appear in Prompt Builder

4. **No capabilityType**:
   - DO NOT include `capabilityType='PromptTemplateType__Prompt'`
   - This was required in earlier versions but causes errors in Winter '25
   - Error: "Annotation property, the format of capabilityType on InvocableMethod is invalid"

5. **Method Signature**:
   - Must take `List<PromptRequest>` as input
   - Must return `List<PromptResponse>` as output
   - Even if you don't use the input, the parameter must exist

#### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "Apex (None Available)" | Output variable not named 'Prompt' | Rename output variable to exactly 'Prompt' |
| "Apex loading..." then "None Available" | Wrong class structure | Follow exact Request/Response pattern above |
| Deployment error about capabilityType | Using old pattern | Remove capabilityType attribute |
| Resource not appearing after deployment | Browser cache | Clear cache, use incognito, refresh Prompt Builder |

#### Working Example from This Project

```apex
global with sharing class RevenueClassificationResource {

    global class PromptRequest {
        @InvocableVariable(required=false label='Input Record')
        global SObject targetEntity;
    }

    global class PromptResponse {
        @InvocableVariable(label='Revenue Classifications')
        global String Prompt;  // The magic variable name!
    }

    @InvocableMethod(
        label='Get Active Revenue Classifications'
        description='Returns active revenue classifications for Einstein Prompt Templates'
    )
    global static List<PromptResponse> getActiveRevenueClassifications(List<PromptRequest> requests) {
        List<PromptResponse> results = new List<PromptResponse>();

        try {
            // Query revenue classifications
            List<String> classifications = new List<String>();
            for (RevenueClassification__c rc : [
                SELECT Name FROM RevenueClassification__c
                WHERE IsActive__c = true
            ]) {
                classifications.add('"' + rc.Name + '"');
            }

            // Create response with 'Prompt' field
            PromptResponse res = new PromptResponse();
            res.Prompt = String.join(classifications, ', ');
            results.add(res);

        } catch (Exception e) {
            PromptResponse errorRes = new PromptResponse();
            errorRes.Prompt = '"Food", "Beverage", "Labor", "Equipment", "Other"';
            results.add(errorRes);
        }

        return results;
    }
}
```

#### Using the Resource in Prompt Builder

1. **Add Resource**:
   - In Prompt Builder, click "Add Resource" → "Apex"
   - Select your resource from the list
   - Give it a reference name (e.g., `Classifications`)

2. **Reference in Template**:
   ```
   Available Classifications: {!$Resource:Classifications.Prompt}
   ```

3. **The output will be the value of the 'Prompt' field**

#### Troubleshooting Tips

1. **After deployment, always**:
   - Clear browser cache
   - Close all Salesforce tabs
   - Open Prompt Builder in incognito/private window

2. **If still not appearing**:
   - Verify the output variable is named exactly `Prompt`
   - Check that all classes and variables are `global`
   - Ensure no capabilityType attribute is present
   - Try with a minimal example first

3. **Permissions**:
   - User needs "Author Apex" permission
   - Einstein features must be enabled in the org

---

## Salesforce Deployments (SKILL)

### Overview

**IMPORTANT**: When the user asks to deploy Salesforce metadata (Apex classes, Flows, LWC, etc.), use the Salesforce CLI commands below. Always deploy to the `fdesdo` org unless specified otherwise.

### Default Org Configuration

- **Org Alias**: `fdesdo`
- **Project Directory**: `/Users/rreboucas/Documents/SFDX Projects/fdesdo/Fdesdo`

### Quick Deploy Commands

#### Deploy Specific Files (Most Common)

```bash
# Deploy Apex class(es) and Flow
sf project deploy start -o fdesdo -d force-app/main/default/classes/ClassName.cls -d force-app/main/default/classes/ClassName.cls-meta.xml -d force-app/main/default/flows/FlowName.flow-meta.xml

# Deploy just an Apex class (include both .cls and .cls-meta.xml)
sf project deploy start -o fdesdo -d force-app/main/default/classes/ClassName.cls -d force-app/main/default/classes/ClassName.cls-meta.xml

# Deploy a Flow
sf project deploy start -o fdesdo -d force-app/main/default/flows/FlowName.flow-meta.xml

# Deploy an LWC component (entire folder)
sf project deploy start -o fdesdo -d force-app/main/default/lwc/componentName
```

#### Deploy by Directory

```bash
# Deploy all classes
sf project deploy start -o fdesdo -d force-app/main/default/classes

# Deploy all LWC components
sf project deploy start -o fdesdo -d force-app/main/default/lwc

# Deploy all flows
sf project deploy start -o fdesdo -d force-app/main/default/flows

# Deploy everything
sf project deploy start -o fdesdo -d force-app
```

#### Deploy with Manifest

```bash
sf project deploy start -o fdesdo -x manifest/package.xml
```

### Metadata Type Reference

| Type | Location | Deploy Pattern |
|------|----------|----------------|
| Apex Class | `classes/Name.cls` + `classes/Name.cls-meta.xml` | Deploy both files together |
| Apex Trigger | `triggers/Name.trigger` + `triggers/Name.trigger-meta.xml` | Deploy both files together |
| Flow | `flows/Name.flow-meta.xml` | Single file |
| LWC | `lwc/componentName/` (folder) | Deploy entire folder |
| Aura | `aura/componentName/` (folder) | Deploy entire folder |
| Lightning Type | `lightningTypes/typeName/` (folder) | Deploy entire folder |
| Prompt Template | `genAiPromptTemplates/Name.genAiPromptTemplate-meta.xml` | Single file |
| GenAI Function | `genAiFunctions/Name.genAiFunction-meta.xml` | Single file |
| Custom Object | `objects/Name__c/` (folder) | Deploy entire folder |
| Permission Set | `permissionsets/Name.permissionset-meta.xml` | Single file |

### Common Deployment Scenarios

| Scenario | Command |
|----------|---------|
| Single Apex class | `sf project deploy start -o fdesdo -d force-app/main/default/classes/ClassName.cls -d force-app/main/default/classes/ClassName.cls-meta.xml` |
| Multiple Apex classes | Use multiple `-d` flags for each .cls and .cls-meta.xml file |
| LWC component | `sf project deploy start -o fdesdo -d force-app/main/default/lwc/componentName` |
| Flow | `sf project deploy start -o fdesdo -d force-app/main/default/flows/FlowName.flow-meta.xml` |
| Validation only (no deploy) | Add `--dry-run` flag |
| Deploy with tests | Add `--test-level RunLocalTests` flag |
| Skip tests (dev only) | Add `--test-level NoTestRun` flag |

### Checking & Managing Deployments

```bash
# Check deployment status
sf project deploy report --job-id <deploymentId>

# Resume failed/interrupted deployment
sf project deploy resume --job-id <deploymentId>

# Cancel a running deployment
sf project deploy cancel --job-id <deploymentId>
```

### Retrieve from Org

```bash
# Retrieve specific metadata
sf project retrieve start -o fdesdo -d force-app/main/default/classes/ClassName.cls

# Retrieve using manifest
sf project retrieve start -o fdesdo -x manifest/package.xml

# Retrieve all metadata
sf project retrieve start -o fdesdo -d force-app
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| "Not authorized" error | Run `sf org login web --alias fdesdo` to re-authenticate |
| Deployment timeout | Add `--wait 60` flag to wait longer |
| Test failures blocking deploy | Use `--test-level NoTestRun` for non-production orgs |
| Partial deployment needed | Use `--ignore-errors` to continue past failures |
| "INVALID_TYPE" error | Check if metadata type is enabled in org (e.g., Einstein features) |
| "Cannot modify managed object" | You're trying to modify a managed package component |

### Best Practices

1. **Always deploy meta.xml files with Apex**: When deploying `.cls` files, always include the corresponding `.cls-meta.xml`
2. **Use -d for multiple files**: Combine multiple `-d` flags rather than separate commands
3. **Validate first for large changes**: Use `--dry-run` to validate before deploying
4. **Check deployment ID**: Save the Deploy ID from output to check status if needed
5. **Run from project root**: Always run sf commands from the Salesforce project directory

---

---

## Salesforce CLI SOQL Queries

### Running SOQL Queries from Command Line

Use the Salesforce CLI to run SOQL queries directly against the connected org.

#### Basic Query Syntax

```bash
sf data query --query "SELECT Id, Name FROM Account LIMIT 10" -o fdesdo
```

#### Common Query Patterns

| Scenario | Command |
|----------|---------|
| Simple query | `sf data query --query "SELECT Id, Name FROM Account LIMIT 10" -o fdesdo` |
| Query with filter | `sf data query --query "SELECT Id, Name FROM Contact WHERE Email != null" -o fdesdo` |
| Query with relationship | `sf data query --query "SELECT Id, Account.Name FROM Contact LIMIT 5" -o fdesdo` |
| JSON output (for parsing) | `sf data query --query "SELECT Id, Name FROM Account" -o fdesdo --json` |
| Query specific record | `sf data query --query "SELECT Id, Name FROM Account WHERE Id = 'xxxxx'" -o fdesdo` |

#### Useful Queries for This Project

```bash
# Check Email Processing Logs
sf data query --query "SELECT Id, Thread_Id__c, Email_Intent__c, Processing_Status__c, Subject__c, CreatedDate FROM Email_Processing_Log__c ORDER BY CreatedDate DESC LIMIT 10" -o fdesdo

# Check Booking records
sf data query --query "SELECT Id, Name, BookingStatus__c, ArrivalDate__c, DepartureDate__c, Property__c FROM Booking__c ORDER BY CreatedDate DESC LIMIT 10" -o fdesdo

# Check GuestroomTypeDay inventory
sf data query --query "SELECT Id, EffectiveDate__c, BlockedDefinite__c, GuestroomType__r.Name, Location__r.Name FROM GuestroomTypeDay__c WHERE Location__r.Name LIKE '%Ashworth%' AND EffectiveDate__c >= TODAY ORDER BY EffectiveDate__c LIMIT 20" -o fdesdo

# Check Gmail Connection State
sf data query --query "SELECT Id, Name, Connection_Developer_Name__c, Last_Poll_Timestamp__c, Last_Error_Message__c FROM Gmail_Connection_State__c" -o fdesdo
```

#### Tips

- Always use `-o fdesdo` to specify the target org (or your org alias)
- Use `--json` flag for machine-parseable output
- Escape special characters in queries if needed
- Use single quotes for string values in WHERE clauses

---

Last Updated: 2026-01-21
Pattern Verified Working: Yes
Critical Value Pattern Added: Yes
Connect API Pattern Added: Yes
Apex Resource Pattern Added: Yes (Winter '25)
Salesforce Deployments Skill Added: Yes
Salesforce CLI Queries Added: Yes
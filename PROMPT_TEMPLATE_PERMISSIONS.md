# Required Permissions for Einstein Prompt Templates

Add these permissions to your custom permission set to enable Connect API calls to prompt templates:

## System Permissions (Required)

In your custom permission set, navigate to **System Permissions** and enable:

### Core Permissions:
- [x] **API Enabled** - Required for any API calls
- [x] **View Setup and Configuration** - Required to access setup objects
- [x] **Customize Application** - Required for metadata access
- [x] **Author Apex** - You likely already have this

### Einstein-Specific System Permissions:
Look for and enable these permissions (exact names may vary by org version):

- [x] **Run Prompt Templates** - Critical for executing prompt templates
- [x] **View Prompt Templates** - Required to access prompt templates
- [x] **Create and Customize Prompt Templates** - For template management
- [x] **Use Einstein Features** - General Einstein access
- [x] **Einstein GPT** - Access to generative AI features
- [x] **Access Einstein Platform Services** - Platform-level access

## App Permissions

Navigate to **App Permissions** and enable:

- [x] **Einstein Platform** - If available
- [x] **Prompt Builder** - Access to prompt builder app
- [x] **Einstein Generative AI** - Core generative AI access

## Object Permissions

Navigate to **Object Settings** and grant access to these objects:

### GenAiPromptTemplate Object:
- [x] **Read** - Required
- [x] **View All** - Recommended

### ContentDocument Object:
- [x] **Read** - Required (for file access)
- [x] **Create** - If creating files
- [x] **Edit** - If modifying files
- [x] **View All** - Recommended

### ContentVersion Object:
- [x] **Read** - Required
- [x] **Create** - Required for file uploads

## Field Permissions

For the **GenAiPromptTemplate** object, ensure Read access to:
- All standard fields
- Any custom fields used in your templates

## Apex Class Access

Navigate to **Apex Class Access** and add:

### Required Classes:
- [x] **BanquetMenuAgentAction** - Your custom class
- [x] **BanquetMenuAgentController** - Your controller class
- [x] **BanquetMenuParser** - Your parser class

### System Classes (if listed):
- [x] Any ConnectApi classes
- [x] Any Einstein-related classes

## Custom Permissions (if available)

Look for and enable any custom permissions related to:
- Einstein
- AI
- GPT
- Prompt Templates
- Generative AI

## Tab Settings

Ensure visibility for:
- **Prompt Builder** tab (if available)
- **Einstein Studio** tab (if available)

## Connected App Access (if applicable)

If there are Einstein-related connected apps, ensure:
- Your permission set has access to any Einstein or AI connected apps

---

## How to Add These Permissions:

1. **Go to Setup** → **Permission Sets**
2. **Click on your custom permission set**
3. **For System Permissions:**
   - Click **System Permissions** → **Edit**
   - Search for and check each permission listed above
   - Click **Save**

4. **For App Permissions:**
   - Click **App Permissions** → **Edit**
   - Enable Einstein and Prompt Builder apps
   - Click **Save**

5. **For Object Permissions:**
   - Click **Object Settings**
   - Search for **GenAiPromptTemplate**
   - Click on it and enable Read and View All
   - Repeat for ContentDocument and ContentVersion
   - Save each change

6. **For Apex Class Access:**
   - Click **Apex Class Access** → **Edit**
   - Add your custom classes
   - Click **Save**

---

## Minimum Required Permissions

If you want just the bare minimum to make it work, these are absolutely critical:

### Must Have:
1. **System Permission: Run Prompt Templates**
2. **System Permission: API Enabled**
3. **Object Permission: GenAiPromptTemplate - Read**
4. **Object Permission: ContentDocument - Read**

### Should Have:
1. **System Permission: View Prompt Templates**
2. **System Permission: Use Einstein Features**
3. **App Permission: Prompt Builder**

---

## Testing After Setup

After adding these permissions, test with this simple Apex code in Developer Console:

```apex
// Test 1: Check if prompt template object is accessible
try {
    List<GenAiPromptTemplate> templates = [
        SELECT Id, DeveloperName, MasterLabel
        FROM GenAiPromptTemplate
        LIMIT 1
    ];
    System.debug('✓ Can query prompt templates: ' + templates.size());
} catch (Exception e) {
    System.debug('✗ Cannot query prompt templates: ' + e.getMessage());
}

// Test 2: Check if Connect API classes are available
try {
    ConnectApi.EinsteinPromptTemplateGenerationsInput test =
        new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    System.debug('✓ Connect API Einstein classes available');
} catch (Exception e) {
    System.debug('✗ Connect API classes not available: ' + e.getMessage());
}

// Test 3: Try to call a prompt template (will fail without credits but shows access)
try {
    ConnectApi.EinsteinPromptTemplateGenerationsInput input =
        new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    input.isPreview = true;

    // This will likely fail but the error message will tell us what's wrong
    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
        'Banquet_Menu_Ingestion',
        input
    );
    System.debug('✓ Can call prompt templates');
} catch (Exception e) {
    System.debug('! Connect API call result: ' + e.getMessage());
    // If error is about credits or input, permissions are OK
    // If error is about access/permissions, more setup needed
}
```

## Common Issues After Adding Permissions:

1. **Still getting "Failed to generate Einstein LLM generations response"**
   - Check if Einstein credits are available in your org
   - Verify the prompt template is Published (not Draft)
   - Ensure AI features are enabled for the org

2. **"Insufficient Privileges" error**
   - Double-check "Run Prompt Templates" permission is enabled
   - Verify the permission set is assigned to your user
   - Log out and log back in to refresh permissions

3. **Connect API classes not found**
   - Ensure your org is on API version 59.0 or higher
   - Check if Einstein features are enabled for your org type
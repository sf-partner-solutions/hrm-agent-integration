# Einstein GPT and Connect API Permission Checklist

## Quick Permission Check Commands

Run these SOQL queries in Developer Console or Workbench to check permissions:

### 1. Check if Einstein Features are enabled
```sql
SELECT Id, DeveloperName, MasterLabel, State
FROM AiApplication
WHERE State = 'Enabled'
```

### 2. Check User Permissions
```sql
SELECT Id, Name, PermissionsViewSetup, PermissionsModifyAllData, PermissionsAuthorApex
FROM Profile
WHERE Id IN (SELECT ProfileId FROM User WHERE Id = '005Ka000001pgh7IAA')
```

### 3. Check Permission Sets with Einstein Access
```sql
SELECT Id, Name, Label
FROM PermissionSet
WHERE Name LIKE '%Einstein%' OR Name LIKE '%AI%' OR Name LIKE '%GPT%'
```

### 4. Check if User has Einstein Permission Sets
```sql
SELECT PermissionSet.Name, PermissionSet.Label
FROM PermissionSetAssignment
WHERE AssigneeId = '005Ka000001pgh7IAA'
AND (PermissionSet.Name LIKE '%Einstein%' OR PermissionSet.Name LIKE '%AI%')
```

## Manual Setup Steps

### Step 1: Enable Einstein Generative AI
1. Navigate to **Setup** → **Einstein Setup** → **Generative AI**
2. Toggle **Turn on Einstein** if not already enabled
3. Accept Terms and Conditions if prompted

### Step 2: Create/Assign Permission Set
1. **Setup** → **Permission Sets** → **New**
2. Create a new Permission Set called "Einstein GPT Access"
3. Add these System Permissions:
   - API Enabled
   - View Setup and Configuration
   - Customize Application
   - Author Apex

4. Look for App Permissions:
   - Einstein GPT
   - Prompt Builder
   - Run Prompt Templates

### Step 3: Assign Permission Set to User
1. In the Permission Set, click **Manage Assignments**
2. Click **Add Assignment**
3. Select your user
4. Save

### Step 4: Check Prompt Template Access
1. **Setup** → **Prompt Builder** (or search for "Prompt")
2. Ensure you can see and edit the "Banquet_Menu_Ingestion" template
3. Check the template status is "Published" or "Active"

### Step 5: Verify Connected App Access (if needed)
1. **Setup** → **App Manager**
2. Look for any Einstein or AI-related connected apps
3. Ensure your profile/permission set has access

## Troubleshooting Connect API Errors

### Common Issues and Solutions:

1. **"Failed to generate Einstein LLM generations response"**
   - Solution: Einstein GPT not enabled or no credits available
   - Check: Setup → Einstein Generative AI → Check status and credits

2. **"Invalid type: ConnectApi.EinsteinPromptTemplateGenerationsInput"**
   - Solution: API version mismatch or feature not available
   - Check: Ensure org is on API v59.0 or higher

3. **"Insufficient Privileges"**
   - Solution: Missing permissions
   - Check: Add "Run Prompt Templates" permission

4. **No response from prompt template**
   - Solution: Template not published or accessible
   - Check: Template status and sharing settings

## Testing Connect API Access

Create this simple Apex test in Developer Console:

```apex
// Test if Connect API is available
try {
    ConnectApi.EinsteinPromptTemplateGenerationsInput test =
        new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    System.debug('✓ Connect API Einstein classes are available');
} catch (Exception e) {
    System.debug('✗ Connect API Einstein classes NOT available: ' + e.getMessage());
}

// Test if you can query prompt templates
List<GenAiPromptTemplate> templates = [
    SELECT Id, DeveloperName, MasterLabel
    FROM GenAiPromptTemplate
    WHERE DeveloperName = 'Banquet_Menu_Ingestion'
];
System.debug('Found templates: ' + templates);
```

## Required Features by Salesforce Edition

- **Enterprise Edition**: May require additional Einstein license
- **Unlimited Edition**: Usually includes Einstein features
- **Developer Edition**: Limited Einstein credits (usually 50/month)
- **Scratch Orgs**: Need to enable Einstein features in scratch org definition

## Next Steps if Permissions are Correct but Still Not Working

1. **Check Einstein Credits**:
   - Setup → Einstein Generative AI → Usage
   - Ensure you have credits remaining

2. **Check Org Limits**:
   - Some orgs have monthly limits on AI calls
   - Developer orgs typically have 50 calls/month

3. **Verify Prompt Template Input**:
   - Ensure ContentDocument ID is valid
   - Check that the PDF is readable

4. **Enable Debug Logs**:
   - Setup → Debug Logs → New
   - Set Callout = FINEST
   - Re-run and check for detailed error messages
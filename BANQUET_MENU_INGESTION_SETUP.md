# Banquet Menu Ingestion - Implementation Guide

## Overview
This implementation provides an Agentforce Agent Action for automating the manual entry of banquet menu items from PDF files into Salesforce's Item__c object.

## Components Deployed

### 1. Prompt Template
- **Name**: Banquet_Menu_Ingestion
- **Type**: Flex template
- **Input**: ContentDocument (PDF file)
- **Output**: JSON with Item__c-ready records

### 2. Apex Classes
- **BanquetMenuParser.cls**: Parses JSON output and converts to Item__c records
- **BanquetMenuAgentController.cls**: Orchestrates the flow and handles record creation

### 3. Lightning Web Components
- **menuUploadHandler**: File upload interface with Amadeus logo
- **menuItemsPreview**: Data table showing extracted items with action buttons
- **menuItemsEditor**: Modal for bulk editing items before creation
- **menuIngestionSuccess**: Success confirmation screen

## Agentforce Configuration Required

### Step 1: Create Lightning Types
In Setup → Lightning Types:

1. **Menu Upload Type**
   - Name: `MenuUploadHandler`
   - Component: `menuUploadHandler`
   - Description: "PDF menu upload interface"

2. **Menu Preview Type**
   - Name: `MenuItemsPreview`
   - Component: `menuItemsPreview`
   - Description: "Preview extracted menu items"

3. **Menu Success Type**
   - Name: `MenuIngestionSuccess`
   - Component: `menuIngestionSuccess`
   - Description: "Success confirmation"

### Step 2: Create Agent Action
In Setup → Agent Actions:

1. Create New Agent Action:
   - **Name**: "Upload Banquet Menu"
   - **Type**: Prompt Template
   - **Template**: Banquet_Menu_Ingestion
   - **Input**: File (ContentDocument)

2. Add Response Handlers:
   - **Initial Response**: MenuUploadHandler Lightning Type
   - **After Extraction**: MenuItemsPreview Lightning Type
   - **After Success**: MenuIngestionSuccess Lightning Type

### Step 3: Configure Agent
In Setup → Agents:

1. Add the "Upload Banquet Menu" action to your agent
2. Configure triggers:
   - Keywords: "upload menu", "insert items", "add menu items"
   - Context: When viewing Item__c list view

### Step 4: Add to Lightning Page
In Lightning App Builder:

1. Edit the Item__c list view page
2. Add the Agent component
3. Configure to show the agent panel

## Usage Flow

1. **User**: "Help me insert new items"
2. **Agent**: Shows menuUploadHandler LWC with file upload
3. **User**: Uploads PDF menu
4. **Agent**: Calls prompt template, extracts items
5. **Agent**: Shows menuItemsPreview with extracted items
6. **User**: Clicks "Insert Items" or "Make Changes"
7. **Agent**: Creates Item__c records
8. **Agent**: Shows menuIngestionSuccess confirmation

## Field Mappings

| PDF Extract | Item__c Field | Notes |
|------------|---------------|-------|
| Name | Name | Max 80 chars, required |
| ItemType | ItemType__c | Item/Detailed Menu/Simple Menu |
| UnitPrice | UnitPrice__c | Currency field |
| SoldByUnit | SoldByUnit__c | per person/each/etc |
| ItemCategory | ItemCategoryName__c | Picklist field |
| RevenueClassification | RevenueClassification__c | Lookup to RevClass object |
| RichDescription | RichDescription__c | HTML formatted |
| IsActive | IsActive__c | Default: true |

## Testing

1. Upload a sample banquet menu PDF
2. Verify items are extracted correctly
3. Test editing functionality in modal
4. Confirm Item__c records are created
5. Check field mappings are correct

## Troubleshooting

### Issue: Fields not showing on Item form
**Solution**: Deploy Item__c object metadata with all fields

### Issue: Prompt template fails
**Solution**: Ensure PDF is readable text (not scanned image)

### Issue: LWCs not appearing
**Solution**: Check Lightning Type configuration and agent action setup

## Future Enhancements

1. Add support for multiple file formats (Excel, CSV)
2. Implement duplicate detection
3. Add bulk update for existing items
4. Create approval workflow for new items
5. Add multi-language support for international menus

## Support
For issues or questions, contact the Salesforce admin team.
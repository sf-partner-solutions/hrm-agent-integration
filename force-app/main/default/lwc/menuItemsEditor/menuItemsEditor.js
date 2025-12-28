import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { publish, MessageContext } from 'lightning/messageService';
import MENU_INGESTION_CHANNEL from '@salesforce/messageChannel/MenuIngestionStatus__c';
import AMADEUS_LOGO from '@salesforce/resourceUrl/AmadeusLogo';
import createMenuItems from '@salesforce/apex/BanquetMenuAgentController.createMenuItems';
import createMenuItemsFromJson from '@salesforce/apex/BanquetMenuAgentController.createMenuItemsFromJson';
import getContentVersionId from '@salesforce/apex/BanquetMenuAgentController.getContentVersionId';
import getRevenueClassifications from '@salesforce/apex/BanquetMenuAgentController.getRevenueClassifications';
import getItemTypePicklistValues from '@salesforce/apex/BanquetMenuAgentController.getItemTypePicklistValues';
import getItemRecordTypes from '@salesforce/apex/BanquetMenuAgentController.getItemRecordTypes';

export default class MenuItemsEditor extends NavigationMixin(LightningElement) {
    @track editableItems = [];
    @track draftValues = [];
    @track contentDocumentId;
    @track contentVersionId; // Store the ContentVersion ID for PDF display
    @track menuItems = [];
    @track propertyId;
    @track propertyName;
    @track selectedRows = []; // Track selected rows

    pageReference; // Store page reference for navigation context

    amadeusLogoUrl = AMADEUS_LOGO;
    isLoading = false;

    // Picklist options - will be populated dynamically
    revenueClassOptions = [];
    itemTypeOptions = [];
    recordTypeOptions = [];

    // Wire the MessageContext for Lightning Message Service
    @wire(MessageContext)
    messageContext;

    // Get state parameters from navigation
    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        // Store the page reference for later use
        this.pageReference = pageRef;

        if (pageRef && pageRef.state) {
            console.log('=== menuItemsEditor: Received state ===');
            console.log('Full state:', JSON.stringify(pageRef.state, null, 2));

            // Get the passed state
            const state = pageRef.state;

            if (state.c__menuItems) {
                try {
                    this.menuItems = JSON.parse(state.c__menuItems);
                    console.log('Parsed menu items count:', this.menuItems.length);

                    // Log first item to check field values
                    if (this.menuItems.length > 0) {
                        console.log('First item in editor:', JSON.stringify(this.menuItems[0], null, 2));
                        console.log('Field values check:');
                        console.log('- Description__c:', this.menuItems[0].Description__c);
                        console.log('- Description:', this.menuItems[0].Description);
                        console.log('- RevenueClassification__c:', this.menuItems[0].RevenueClassification__c);
                        console.log('- RevenueClassification:', this.menuItems[0].RevenueClassification);
                        console.log('- ItemType__c:', this.menuItems[0].ItemType__c);
                        console.log('- ItemType:', this.menuItems[0].ItemType);
                    }

                    this.prepareEditableItems();
                } catch (e) {
                    console.error('Error parsing menu items:', e);
                }
            }

            if (state.c__contentDocumentId) {
                this.contentDocumentId = state.c__contentDocumentId;
                console.log('Received contentDocumentId:', this.contentDocumentId);
                // Fetch the ContentVersion ID for PDF display
                this.fetchContentVersionId();
            }

            if (state.c__propertyId) {
                this.propertyId = state.c__propertyId;
            }

            if (state.c__propertyName) {
                this.propertyName = state.c__propertyName;
            }
        }
    }

    // All columns including hidden fields
    allColumns = [
        {
            label: 'Name',
            fieldName: 'Name',
            type: 'text',
            editable: true,
            wrapText: false,
            initialWidth: 180,
            cellAttributes: {
                class: { fieldName: 'nameClass' }
            }
        },
        {
            label: 'Description',
            fieldName: 'Description__c',
            type: 'text',
            editable: true,
            wrapText: true,
            initialWidth: 220
        },
        {
            label: 'Unit Price',
            fieldName: 'UnitPrice',
            type: 'currency',
            editable: true,
            typeAttributes: {
                currencyCode: 'USD',
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            },
            initialWidth: 100
        },
        {
            label: 'Revenue Classification',
            fieldName: 'RevenueClassification__c',
            type: 'picklistColumn',
            editable: true,
            wrapText: false,
            initialWidth: 150,
            cellAttributes: { alignment: 'left' },
            typeAttributes: {
                placeholder: 'Select Revenue',
                options: { fieldName: 'pickListOptions_Revenue' },
                value: { fieldName: 'RevenueClassification__c' },
                context: { fieldName: 'id' }
            }
        },
        {
            label: 'Item Type',
            fieldName: 'ItemType__c',
            type: 'picklistColumn',
            editable: true,
            wrapText: false,
            initialWidth: 130,
            cellAttributes: { alignment: 'left' },
            typeAttributes: {
                placeholder: 'Select Type',
                options: { fieldName: 'pickListOptions_ItemType' },
                value: { fieldName: 'ItemType__c' },
                context: { fieldName: 'id' }
            }
        },
        {
            label: 'Record Type',
            fieldName: 'RecordType',
            type: 'picklistColumn',
            editable: true,
            wrapText: false,
            initialWidth: 150,
            cellAttributes: { alignment: 'left' },
            typeAttributes: {
                placeholder: 'Select Record Type',
                options: { fieldName: 'pickListOptions_RecordType' },
                value: { fieldName: 'RecordType' },
                context: { fieldName: 'id' }
            }
        },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Clone', name: 'clone' },
                    { label: 'Delete', name: 'delete' }
                ]
            },
            initialWidth: 80
        }
    ];

    async connectedCallback() {
        await this.fetchAllPicklistValues();
        this.prepareEditableItems();
    }

    async fetchAllPicklistValues() {
        // Fetch all picklist values in parallel
        const promises = [
            this.fetchRevenueClassifications(),
            this.fetchItemTypeValues(),
            this.fetchRecordTypeValues()
        ];

        await Promise.all(promises);
    }

    async fetchRevenueClassifications() {
        try {
            const classifications = await getRevenueClassifications();
            this.revenueClassOptions = classifications.map(name => ({
                label: name,
                value: name
            }));
        } catch (error) {
            console.error('Error fetching revenue classifications:', error);
            // Fallback to default options
            this.revenueClassOptions = [
                { label: 'Food', value: 'Food' },
                { label: 'Beverage', value: 'Beverage' },
                { label: 'Labor', value: 'Labor' },
                { label: 'Equipment', value: 'Equipment' },
                { label: 'Other', value: 'Other' }
            ];
        }
    }

    async fetchItemTypeValues() {
        try {
            const itemTypes = await getItemTypePicklistValues();
            this.itemTypeOptions = itemTypes.map(item => ({
                label: item.label,
                value: item.value
            }));
        } catch (error) {
            console.error('Error fetching item type values:', error);
            // Fallback to default options
            this.itemTypeOptions = [
                { label: 'Item', value: 'Item' },
                { label: 'Simple Menu', value: 'Simple Menu' },
                { label: 'Detailed Menu', value: 'Detailed Menu' }
            ];
        }
    }

    async fetchRecordTypeValues() {
        try {
            const recordTypes = await getItemRecordTypes();
            this.recordTypeOptions = recordTypes.map(rt => ({
                label: rt.label,
                value: rt.value
            }));
        } catch (error) {
            console.error('Error fetching record types:', error);
            // Fallback to default options
            this.recordTypeOptions = [
                { label: 'Corporate Item', value: 'Corporate_Item' },
                { label: 'Property Item', value: 'Property_Item' },
                { label: 'Property Simple Menu', value: 'Property_Simple_Menu' },
                { label: 'Property Detailed Menu', value: 'Property_Detailed_Menu' }
            ];
        }
    }

    async fetchContentVersionId() {
        if (!this.contentDocumentId) return;

        try {
            const versionId = await getContentVersionId({ contentDocumentId: this.contentDocumentId });
            this.contentVersionId = versionId;
            console.log('Got ContentVersion ID:', this.contentVersionId);
        } catch (error) {
            console.error('Error fetching ContentVersion ID:', error);
            // Fallback to using ContentDocument ID
            this.contentVersionId = this.contentDocumentId;
        }
    }

    prepareEditableItems() {
        if (!this.menuItems || this.menuItems.length === 0) return;

        console.log('=== Preparing Editable Items ===');
        console.log('Revenue Class Options:', this.revenueClassOptions);

        // Create editable copy with row IDs and picklist options
        this.editableItems = this.menuItems.map((item, index) => {
            // Check for field name variations
            const itemType = item.ItemType__c || item.ItemType;
            const revenueClass = item.RevenueClassification__c || item.RevenueClassification;
            const description = item.Description__c || item.Description;

            console.log(`Item ${index} field mapping:`, {
                itemType,
                revenueClass,
                description,
                recordType: item.RecordType
            });

            // Create unique options for each row to avoid duplicate key issues
            const uniqueRowId = `row-${index}`;

            return {
                ...item,
                id: uniqueRowId,
                // Ensure fields have the correct API names
                ItemType__c: itemType,
                RevenueClassification__c: revenueClass,
                Description__c: description,
                RecordType: item.RecordType || 'Corporate_Item', // Use existing or default with underscore
                nameClass: (itemType === 'Detailed Menu' || itemType === 'Simple Menu')
                    ? 'slds-text-color_success slds-text-title_bold' : '',
                // Use different field names for picklist options as per the new approach
                pickListOptions_Revenue: this.revenueClassOptions,
                pickListOptions_ItemType: this.itemTypeOptions,
                pickListOptions_RecordType: this.recordTypeOptions
            };
        });

        console.log('Prepared editable items:', JSON.stringify(this.editableItems, null, 2));
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'delete') {
            this.deleteRow(row.id);
        } else if (actionName === 'clone') {
            this.cloneRow(row);
        }
    }

    deleteRow(rowId) {
        this.editableItems = this.editableItems.filter(item => item.id !== rowId);
        // Clear selection if deleted row was selected
        this.selectedRows = this.selectedRows.filter(id => id !== rowId);
        this.updateMenuItems();
    }

    cloneRow(row) {
        // Find the index of the row to clone
        const rowIndex = this.editableItems.findIndex(item => item.id === row.id);

        if (rowIndex !== -1) {
            // Create a new unique ID for the cloned row
            const newId = `row-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

            // Create a clone of the row with a new ID
            const clonedRow = {
                ...row,
                id: newId,
                Name: row.Name + ' (Copy)' // Add (Copy) suffix to the name
            };

            // Insert the cloned row right after the original row
            const newItems = [...this.editableItems];
            newItems.splice(rowIndex + 1, 0, clonedRow);

            this.editableItems = newItems;
            // Clear selection to avoid issues
            this.selectedRows = [];
            this.updateMenuItems();

            // Show success message
            this.showToast('Success', 'Row cloned successfully', 'success');
        }
    }

    addNewRow() {
        // Create a new unique ID for the new row
        const newId = `row-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

        // Create a new empty row with default values
        const newRow = {
            id: newId,
            Name: 'New Item',
            Description__c: '',
            UnitPrice: 0,
            RevenueClassification__c: 'Food', // Default to Food
            ItemType__c: 'Item', // Default to Item
            RecordType: 'Corporate_Item', // Default record type
            nameClass: '',
            // Include picklist options
            pickListOptions_Revenue: this.revenueClassOptions,
            pickListOptions_ItemType: this.itemTypeOptions,
            pickListOptions_RecordType: this.recordTypeOptions
        };

        // Add the new row at the beginning
        this.editableItems = [newRow, ...this.editableItems];
        // Clear selection to avoid issues
        this.selectedRows = [];
        this.updateMenuItems();

        // Show success message
        this.showToast('Success', 'New row added. Please edit the fields as needed.', 'success');
    }

    handleCellSave(event) {
        const draftValues = event.detail.draftValues;

        // Apply draft values to items
        const updatedItems = [...this.editableItems];

        draftValues.forEach(draft => {
            const index = updatedItems.findIndex(item => item.id === draft.id);
            if (index !== -1) {
                updatedItems[index] = { ...updatedItems[index], ...draft };
                // Update name class if type changed
                if (draft.ItemType__c) {
                    updatedItems[index].nameClass = (draft.ItemType__c === 'Detailed Menu' ||
                                                    draft.ItemType__c === 'Simple Menu')
                        ? 'slds-text-color_success slds-text-title_bold' : '';
                }
            }
        });

        this.editableItems = updatedItems;
        this.draftValues = [];
        this.updateMenuItems();
    }

    updateMenuItems() {
        // Update menuItems for creation (remove UI-specific fields)
        this.menuItems = this.editableItems.map(item => {
            const {
                id,
                nameClass,
                pickListOptions_Revenue,
                pickListOptions_ItemType,
                pickListOptions_RecordType,
                ...menuItem
            } = item;
            // Add back RecordType as it's needed for creation
            return {
                ...menuItem,
                RecordType: item.RecordType
            };
        });
    }

    handleCancel() {
        // Navigate back to the property Items related list if we have the ID
        if (this.propertyId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordRelationshipPage',
                attributes: {
                    recordId: this.propertyId,
                    objectApiName: 'Location__c',
                    relationshipApiName: 'ItemLocation__r',
                    actionName: 'view'
                }
            });
        } else {
            // Fallback: Navigate to items home
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Item__c',
                    actionName: 'home'
                }
            });
        }
    }

    async handleSaveAndCreate() {
        if (!this.menuItems || this.menuItems.length === 0) {
            this.showToast('Warning', 'No items to create', 'warning');
            return;
        }

        this.isLoading = true;

        try {
            // Map items to match Apex MenuItem class structure exactly
            const apexMenuItems = this.menuItems.map(item => ({
                // Core fields that match Apex MenuItem class
                Name: item.Name,
                RecordType: item.RecordType,
                ItemType: item.ItemType || item.ItemType__c,
                UnitPrice: item.UnitPrice,
                SoldByUnit: item.SoldByUnit,
                ServingUnit: item.ServingUnit,
                RichDescription: item.RichDescription,
                Description: item.Description || item.Description__c,
                ItemCategory: item.ItemCategory,
                RevenueClassification: item.RevenueClassification || item.RevenueClassification__c,
                IsActive: item.IsActive,
                IsInclusive: item.IsInclusive,
                QuantityCalculation: item.QuantityCalculation,
                Property: item.Property,
                MasterSource: item.MasterSource,
                Abbreviation: item.Abbreviation,
                LocationId: this.propertyId  // Add property association
            }));

            console.log('Cleaned items for Apex:', JSON.stringify(apexMenuItems));

            // Use the new JSON-based method for better control over serialization
            const result = await createMenuItemsFromJson({ menuItemsJson: JSON.stringify(apexMenuItems) });

            if (result.success) {
                // Show success toast with item count
                const itemCount = result.successCount || this.menuItems.length;
                const propertyText = this.propertyName ? ` for ${this.propertyName}` : '';
                this.showToast(
                    'Success',
                    `Successfully created ${itemCount} menu item${itemCount !== 1 ? 's' : ''}${propertyText}`,
                    'success'
                );

                // Publish success message via Lightning Message Service
                const message = {
                    status: 'SUCCESS',
                    message: `Successfully created ${itemCount} menu item${itemCount !== 1 ? 's' : ''}${propertyText}`,
                    itemCount: itemCount,
                    propertyId: this.propertyId,
                    propertyName: this.propertyName
                };

                // Publish the message to any listening components
                publish(this.messageContext, MENU_INGESTION_CHANNEL, message);
                console.log('Published success message via LMS:', message);

                // Navigate to the Items related list on the property page
                if (this.propertyId) {
                    // Small delay to ensure toast is visible
                    setTimeout(() => {
                        this[NavigationMixin.Navigate]({
                            type: 'standard__recordRelationshipPage',
                            attributes: {
                                recordId: this.propertyId,
                                objectApiName: 'Location__c',
                                relationshipApiName: 'ItemLocation__r', // API name of the Items relationship
                                actionName: 'view'
                            }
                        });
                    }, 1500);
                } else if (result.createdItemIds && result.createdItemIds.length > 0) {
                        // Fallback: Navigate to the first created item
                        this[NavigationMixin.Navigate]({
                            type: 'standard__recordPage',
                            attributes: {
                                recordId: result.createdItemIds[0],
                                objectApiName: 'Item__c',
                                actionName: 'view'
                            }
                        });
                    } else {
                        // Fallback: Navigate to items list
                        this[NavigationMixin.Navigate]({
                            type: 'standard__objectPage',
                            attributes: {
                                objectApiName: 'Item__c',
                                actionName: 'list'
                            }
                        });
                    }
            } else if (result.hasErrors) {
                this.showErrors(result.errors);
            }
        } catch (error) {
            console.error('Error creating items:', error);
            this.showToast('Error',
                'Failed to create items: ' + (error.body?.message || error.message),
                'error');
        } finally {
            this.isLoading = false;
        }
    }

    showErrors(errors) {
        if (errors && errors.length > 0) {
            const message = errors.slice(0, 3).join('\n') +
                (errors.length > 3 ? '\n...and ' + (errors.length - 3) + ' more' : '');
            this.showToast('Error', message, 'error');
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    // Getters
    get hasItems() {
        return this.editableItems && this.editableItems.length > 0;
    }

    get itemCountText() {
        const count = this.editableItems ? this.editableItems.length : 0;
        return `${count} item${count !== 1 ? 's' : ''} extracted from menu`;
    }

    get hasPropertyInfo() {
        // Always return true to show the property section for debugging
        return true;
    }

    get propertyDisplayText() {
        // Show property name if available, otherwise show ID, or "No Property" if neither
        if (this.propertyName) {
            return this.propertyName;
        } else if (this.propertyId) {
            return `Property ID: ${this.propertyId}`;
        } else {
            return 'No Property';
        }
    }

    get hasSelectedRows() {
        return this.selectedRows && this.selectedRows.length > 0;
    }

    get deleteSelectedButtonLabel() {
        const count = this.selectedRows ? this.selectedRows.length : 0;
        return count > 1 ? `Delete Selected (${count})` : 'Delete Selected';
    }

    handleRowSelection(event) {
        // Extract just the IDs from the selected rows
        const selectedRowObjects = event.detail.selectedRows;
        this.selectedRows = selectedRowObjects.map(row => row.id);
        console.log('Selected row IDs:', this.selectedRows);
        console.log('Number of selected rows:', this.selectedRows.length);
    }

    deleteSelectedRows() {
        if (!this.selectedRows || this.selectedRows.length === 0) {
            return;
        }

        // Store count before clearing
        const count = this.selectedRows.length;

        // Filter out the selected rows using the IDs
        this.editableItems = this.editableItems.filter(item => !this.selectedRows.includes(item.id));

        // Clear the selection
        this.selectedRows = [];

        // Update menu items
        this.updateMenuItems();

        // Show success message
        this.showToast('Success', `${count} item${count !== 1 ? 's' : ''} deleted successfully`, 'success');
    }

    navigateToProperty() {
        if (this.propertyId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.propertyId,
                    objectApiName: 'Location__c',
                    actionName: 'view'
                }
            });
        }
    }

    get pdfUrl() {
        // We need the ContentVersion ID for this to work
        if (!this.contentVersionId) return '';

        // Use the version download URL which works in Lightning Experience
        // This pattern avoids CORS issues
        return `/sfc/servlet.shepherd/version/download/${this.contentVersionId}`;
    }
}
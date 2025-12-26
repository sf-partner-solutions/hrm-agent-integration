import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import AMADEUS_LOGO from '@salesforce/resourceUrl/AmadeusLogo';
import createMenuItems from '@salesforce/apex/BanquetMenuAgentController.createMenuItems';
import getItemCategories from '@salesforce/apex/BanquetMenuAgentController.getItemCategories';
import getRevenueClassifications from '@salesforce/apex/BanquetMenuAgentController.getRevenueClassifications';

export default class MenuItemsEditor extends LightningElement {
    @api menuItems = [];
    @track editableItems = [];
    @track draftValues = [];
    amadeusLogoUrl = AMADEUS_LOGO;
    isLoading = false;
    categories = [];
    revenueClasses = [];

    columns = [
        {
            label: 'Item Name',
            fieldName: 'Name',
            type: 'text',
            editable: true,
            cellAttributes: { class: { fieldName: 'nameClass' } }
        },
        {
            label: 'Type',
            fieldName: 'ItemType__c',
            type: 'picklist',
            editable: true,
            typeAttributes: {
                placeholder: 'Choose Type',
                options: [
                    { label: 'Item', value: 'Item' },
                    { label: 'Detailed Menu', value: 'Detailed Menu' },
                    { label: 'Simple Menu', value: 'Simple Menu' }
                ]
            },
            initialWidth: 140
        },
        {
            label: 'Price',
            fieldName: 'UnitPrice__c',
            type: 'currency',
            editable: true,
            typeAttributes: { currencyCode: 'USD' },
            initialWidth: 100
        },
        {
            label: 'Unit',
            fieldName: 'SoldByUnit__c',
            type: 'text',
            editable: true,
            initialWidth: 120
        },
        {
            label: 'Category',
            fieldName: 'ItemCategory__c',
            type: 'text',
            editable: true,
            initialWidth: 150
        },
        {
            label: 'Revenue Class',
            fieldName: 'RevenueClassification__c',
            type: 'text',
            editable: true,
            initialWidth: 130
        },
        {
            label: 'Active',
            fieldName: 'IsActive__c',
            type: 'boolean',
            editable: true,
            initialWidth: 70
        },
        {
            type: 'action',
            typeAttributes: { rowActions: this.getRowActions }
        }
    ];

    getRowActions = [
        { label: 'Delete', name: 'delete' }
    ];

    connectedCallback() {
        this.loadPicklistValues();
        this.prepareEditableItems();
    }

    @api
    openModal(items) {
        this.menuItems = items || [];
        this.prepareEditableItems();
        // Modal will be opened by parent
    }

    async loadPicklistValues() {
        try {
            const [categoriesResult, revenueResult] = await Promise.all([
                getItemCategories(),
                getRevenueClassifications()
            ]);
            this.categories = categoriesResult;
            this.revenueClasses = revenueResult;
        } catch (error) {
            console.error('Error loading picklist values:', error);
        }
    }

    prepareEditableItems() {
        // Create editable copy with row IDs
        this.editableItems = this.menuItems.map((item, index) => ({
            ...item,
            id: index.toString(),
            nameClass: item.ItemType__c === 'Detailed Menu' || item.ItemType__c === 'Simple Menu'
                ? 'slds-text-color_success slds-text-title_bold' : ''
        }));
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'delete') {
            this.deleteRow(row.id);
        }
    }

    deleteRow(rowId) {
        this.editableItems = this.editableItems.filter(item => item.id !== rowId);
        // Also update menuItems
        this.menuItems = this.editableItems.map(item => {
            const { id, nameClass, ...menuItem } = item;
            return menuItem;
        });
    }

    handleCellChange(event) {
        this.draftValues = event.detail.draftValues;
    }

    handleSave() {
        // Apply draft values to items
        const updatedItems = [...this.editableItems];

        this.draftValues.forEach(draft => {
            const index = updatedItems.findIndex(item => item.id === draft.id);
            if (index !== -1) {
                updatedItems[index] = { ...updatedItems[index], ...draft };
            }
        });

        this.editableItems = updatedItems;

        // Update menuItems for creation
        this.menuItems = updatedItems.map(item => {
            const { id, nameClass, ...menuItem } = item;
            return menuItem;
        });

        // Clear draft values
        this.draftValues = [];

        // Create items
        this.createItems();
    }

    handleCancel() {
        // Clear draft values
        this.draftValues = [];
        // Dispatch cancel event
        const cancelEvent = new CustomEvent('editcancel');
        this.dispatchEvent(cancelEvent);
    }

    async createItems() {
        this.isLoading = true;

        try {
            const result = await createMenuItems({ menuItems: this.menuItems });

            if (result.success) {
                this.showToast('Success', result.message, 'success');

                // Dispatch success event
                const successEvent = new CustomEvent('itemscreated', {
                    detail: {
                        createdCount: result.successCount,
                        createdItemIds: result.createdItemIds
                    }
                });
                this.dispatchEvent(successEvent);
            } else if (result.hasErrors) {
                this.showErrors(result.errors);
            }
        } catch (error) {
            this.showToast('Error', 'Failed to create items: ' + error.body?.message || error.message, 'error');
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

    get hasItems() {
        return this.editableItems && this.editableItems.length > 0;
    }

    get itemCountText() {
        const count = this.editableItems.length;
        return `Editing ${count} item${count !== 1 ? 's' : ''}`;
    }
}
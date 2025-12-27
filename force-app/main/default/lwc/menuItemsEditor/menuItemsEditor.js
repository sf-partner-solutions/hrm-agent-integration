import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import AMADEUS_LOGO from '@salesforce/resourceUrl/AmadeusLogo';
import createMenuItems from '@salesforce/apex/BanquetMenuAgentController.createMenuItems';
import getContentVersionId from '@salesforce/apex/BanquetMenuAgentController.getContentVersionId';

export default class MenuItemsEditor extends NavigationMixin(LightningElement) {
    @track editableItems = [];
    @track draftValues = [];
    @track contentDocumentId;
    @track contentVersionId; // Store the ContentVersion ID for PDF display
    @track menuItems = [];
    @track propertyId;
    @track propertyName;

    amadeusLogoUrl = AMADEUS_LOGO;
    isLoading = false;

    // Get state parameters from navigation
    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef && pageRef.state) {
            // Get the passed state
            const state = pageRef.state;

            if (state.c__menuItems) {
                try {
                    this.menuItems = JSON.parse(state.c__menuItems);
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
            label: 'Item Name',
            fieldName: 'Name',
            type: 'text',
            editable: true,
            wrapText: true,
            cellAttributes: {
                class: { fieldName: 'nameClass' }
            }
        },
        {
            label: 'Type',
            fieldName: 'ItemType__c',
            type: 'text',
            editable: true,
            initialWidth: 120
        },
        {
            label: 'Price',
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
            label: 'Description',
            fieldName: 'Description__c',
            type: 'text',
            editable: true,
            wrapText: true,
            initialWidth: 200
        },
        {
            label: 'Unit',
            fieldName: 'SoldByUnit__c',
            type: 'text',
            editable: true,
            initialWidth: 100
        },
        {
            label: 'Serving Unit',
            fieldName: 'ServingUnit__c',
            type: 'text',
            editable: true,
            initialWidth: 100
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
            initialWidth: 150
        },
        {
            label: 'Quantity Calc',
            fieldName: 'QuantityCalculation__c',
            type: 'text',
            editable: true,
            initialWidth: 120
        },
        {
            label: 'Service Factor',
            fieldName: 'Service_Factor__c',
            type: 'number',
            editable: true,
            initialWidth: 120
        },
        {
            label: 'Gratuity',
            fieldName: 'Gratuity__c',
            type: 'percent',
            editable: true,
            typeAttributes: {
                minimumFractionDigits: 0,
                maximumFractionDigits: 2
            },
            initialWidth: 100
        },
        {
            label: 'Admin Charge',
            fieldName: 'AdminCharge__c',
            type: 'percent',
            editable: true,
            typeAttributes: {
                minimumFractionDigits: 0,
                maximumFractionDigits: 2
            },
            initialWidth: 120
        },
        {
            label: 'Active',
            fieldName: 'IsActive__c',
            type: 'boolean',
            editable: true,
            initialWidth: 70
        },
        {
            label: 'Inclusive',
            fieldName: 'IsInclusive__c',
            type: 'boolean',
            editable: true,
            initialWidth: 80
        },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Delete', name: 'delete' }
                ]
            }
        }
    ];

    connectedCallback() {
        this.prepareEditableItems();
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

        // Create editable copy with row IDs
        this.editableItems = this.menuItems.map((item, index) => ({
            ...item,
            id: `row-${index}`,
            nameClass: (item.ItemType__c === 'Detailed Menu' || item.ItemType__c === 'Simple Menu')
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
        this.updateMenuItems();
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
            const { id, nameClass, ...menuItem } = item;
            return menuItem;
        });
    }

    handleCancel() {
        // Navigate back to the property page if we have the ID
        if (this.propertyId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.propertyId,
                    objectApiName: 'Location__c',
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
            // Add property ID to all menu items if available
            if (this.propertyId) {
                this.menuItems = this.menuItems.map(item => ({
                    ...item,
                    Location__c: this.propertyId
                }));
            }

            const result = await createMenuItems({ menuItems: this.menuItems });

            if (result.success) {
                // Show success toast with item count
                const itemCount = result.successCount || this.menuItems.length;
                const propertyText = this.propertyName ? ` for ${this.propertyName}` : '';
                this.showToast(
                    'Success',
                    `Successfully created ${itemCount} menu item${itemCount !== 1 ? 's' : ''}${propertyText}`,
                    'success'
                );

                // Navigate back to the property page if we have the ID
                if (this.propertyId) {
                    // Small delay to ensure toast is visible
                    setTimeout(() => {
                        this[NavigationMixin.Navigate]({
                            type: 'standard__recordPage',
                            attributes: {
                                recordId: this.propertyId,
                                objectApiName: 'Location__c',
                                actionName: 'view'
                            },
                            state: {
                                // Try to select the related list tab
                                selectedTab: 'related'
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

    get pdfUrl() {
        // We need the ContentVersion ID for this to work
        if (!this.contentVersionId) return '';

        // Use the version download URL which works in Lightning Experience
        // This pattern avoids CORS issues
        return `/sfc/servlet.shepherd/version/download/${this.contentVersionId}`;
    }
}
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import AMADEUS_LOGO from '@salesforce/resourceUrl/AmadeusLogo';
import createMenuItems from '@salesforce/apex/BanquetMenuAgentController.createMenuItems';
import validateMenuItems from '@salesforce/apex/BanquetMenuAgentController.validateMenuItems';

const columns = [
    { label: 'Item Name', fieldName: 'Name', type: 'text', editable: false,
      cellAttributes: { class: { fieldName: 'nameClass' } }
    },
    { label: 'Type', fieldName: 'ItemType__c', type: 'text', editable: false,
      initialWidth: 120
    },
    { label: 'Price', fieldName: 'UnitPrice', type: 'currency', editable: false,
      typeAttributes: { currencyCode: 'USD' }, initialWidth: 100
    }
];

export default class MenuItemsPreview extends NavigationMixin(LightningElement) {
    @api menuItems = [];
    @api extractionMetadata = {};
    @api contentDocumentId;
    @api propertyId;
    @api propertyName;
    @track displayItems = [];
    columns = columns;
    amadeusLogoUrl = AMADEUS_LOGO;
    isLoading = false;
    selectedRows = [];
    isUsingMockData = false;

    connectedCallback() {
        this.prepareDisplayItems();
        this.checkIfMockData();
    }

    @api
    setMenuData(data) {
        if (data) {
            this.menuItems = data.items || [];
            this.extractionMetadata = data.extraction_metadata || {};
            this.prepareDisplayItems();
            this.checkIfMockData();
        }
    }

    checkIfMockData() {
        // Check if extraction notes indicate mock data
        if (this.extractionMetadata && this.extractionMetadata.extraction_notes) {
            this.isUsingMockData = this.extractionMetadata.extraction_notes.includes('Mock data') ||
                                   this.extractionMetadata.extraction_notes.includes('Connect API unavailable');
        }
    }

    prepareDisplayItems() {
        // Add display properties to items
        this.displayItems = this.menuItems.map(item => ({
            ...item,
            nameClass: item.ItemType__c === 'Detailed Menu' || item.ItemType__c === 'Simple Menu'
                ? 'slds-text-color_success slds-text-title_bold' : ''
        }));
    }

    handleInsertItems() {
        // Validate items first
        this.validateAndInsertItems();
    }

    async validateAndInsertItems() {
        this.isLoading = true;

        try {
            // Get selected items or all items
            let itemsToInsert = this.selectedRows.length > 0
                ? this.menuItems.filter(item =>
                    this.selectedRows.includes(this.menuItems.indexOf(item).toString())
                  )
                : this.menuItems;

            // Add property ID to all items if available
            if (this.propertyId) {
                itemsToInsert = itemsToInsert.map(item => ({
                    ...item,
                    Location__c: this.propertyId
                }));
            }

            // Validate items
            const validationErrors = await validateMenuItems({ menuItems: itemsToInsert });

            if (validationErrors && validationErrors.length > 0) {
                this.showValidationErrors(validationErrors);
                this.isLoading = false;
                return;
            }

            // Create items
            const result = await createMenuItems({ menuItems: itemsToInsert });

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

    handleMakeChanges() {
        // Navigate to the editor page with menu items and content document ID
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: {
                componentName: 'c__menuItemsEditor'
            },
            state: {
                c__menuItems: JSON.stringify(this.menuItems),
                c__contentDocumentId: this.contentDocumentId,
                c__propertyId: this.propertyId,
                c__propertyName: this.propertyName
            }
        });
    }

    handleCancel() {
        // Dispatch cancel event
        const cancelEvent = new CustomEvent('cancel');
        this.dispatchEvent(cancelEvent);
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedRows = selectedRows.map(row =>
            this.menuItems.indexOf(row).toString()
        );
    }

    showValidationErrors(errors) {
        const message = errors.join('\n');
        this.showToast('Validation Error', message, 'error');
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

    get totalItemsText() {
        return `Found ${this.menuItems.length} items to import`;
    }

    get hasItems() {
        return this.menuItems && this.menuItems.length > 0;
    }

    get insertButtonLabel() {
        return this.selectedRows.length > 0
            ? `Insert ${this.selectedRows.length} Items`
            : `Insert All ${this.menuItems.length}`;
    }

    get showVenueName() {
        return this.extractionMetadata?.venue_name;
    }

    get showMenuTitle() {
        return this.extractionMetadata?.menu_title;
    }

    get extractionNotes() {
        return this.extractionMetadata?.extraction_notes;
    }
}
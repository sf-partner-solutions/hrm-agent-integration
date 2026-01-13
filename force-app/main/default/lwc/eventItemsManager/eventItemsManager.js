import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getEventItems from '@salesforce/apex/EventItemsController.getEventItems';
import getBookingEventDetails from '@salesforce/apex/EventItemsController.getBookingEventDetails';
import getCatalogueItems from '@salesforce/apex/EventItemsController.getCatalogueItems';
import createEventItems from '@salesforce/apex/EventItemsController.createEventItems';
import deleteEventItems from '@salesforce/apex/EventItemsController.deleteEventItems';
import updateEventItems from '@salesforce/apex/EventItemsController.updateEventItems';

// Import fields for wire adapter
import PROPERTY_FIELD from '@salesforce/schema/BookingEvent__c.Property__c';
import BOOKING_FIELD from '@salesforce/schema/BookingEvent__c.Booking__c';

export default class EventItemsManager extends LightningElement {
    @api recordId; // BookingEvent__c record ID

    @track eventItems = [];
    @track catalogueItems = [];
    @track selectedCatalogueItems = [];
    @track isLoading = false;
    @track showAddItemsModal = false;
    @track searchTerm = '';
    @track selectedRows = [];

    // Wire results for refresh
    wiredEventItemsResult;
    wiredBookingEventResult;

    // Booking Event details
    propertyName;
    bookingId;

    // Columns for the main event items data table
    eventItemColumns = [
        {
            label: 'Name',
            fieldName: 'Name',
            type: 'text',
            sortable: true,
            initialWidth: 200
        },
        {
            label: 'Type',
            fieldName: 'ItemType__c',
            type: 'text',
            sortable: true,
            initialWidth: 100
        },
        {
            label: 'Qty Calc',
            fieldName: 'QuantityCalculation__c',
            type: 'text',
            initialWidth: 110
        },
        {
            label: 'Booked Qty',
            fieldName: 'BookedQuantity__c',
            type: 'number',
            editable: true,
            initialWidth: 100,
            cellAttributes: { alignment: 'right' }
        },
        {
            label: 'Actual Qty',
            fieldName: 'ActualQuantity__c',
            type: 'number',
            editable: true,
            initialWidth: 100,
            cellAttributes: { alignment: 'right' }
        },
        {
            label: 'Unit Price',
            fieldName: 'UnitPrice__c',
            type: 'currency',
            editable: true,
            initialWidth: 100,
            typeAttributes: { currencyCode: 'USD' }
        },
        {
            label: 'Sold By',
            fieldName: 'SoldByUnit__c',
            type: 'text',
            initialWidth: 100
        },
        {
            label: 'Description',
            fieldName: 'Description__c',
            type: 'text',
            wrapText: true,
            initialWidth: 200
        }
    ];

    // Columns for the catalogue items modal
    catalogueColumns = [
        {
            label: 'Name',
            fieldName: 'Name',
            type: 'text',
            sortable: true,
            initialWidth: 200
        },
        {
            label: 'Type',
            fieldName: 'ItemType__c',
            type: 'text',
            sortable: true,
            initialWidth: 100
        },
        {
            label: 'Revenue Class',
            fieldName: 'RevenueClassification__c',
            type: 'text',
            initialWidth: 120
        },
        {
            label: 'Category',
            fieldName: 'ItemCategory__c',
            type: 'text',
            initialWidth: 120
        },
        {
            label: 'Unit Price',
            fieldName: 'UnitPrice__c',
            type: 'currency',
            initialWidth: 100,
            typeAttributes: { currencyCode: 'USD' }
        },
        {
            label: 'Description',
            fieldName: 'Description__c',
            type: 'text',
            wrapText: true,
            initialWidth: 250
        }
    ];

    // Wire to get BookingEvent details
    @wire(getRecord, { recordId: '$recordId', fields: [PROPERTY_FIELD, BOOKING_FIELD] })
    wiredBookingEvent(result) {
        this.wiredBookingEventResult = result;
        if (result.data) {
            this.propertyName = getFieldValue(result.data, PROPERTY_FIELD);
            this.bookingId = getFieldValue(result.data, BOOKING_FIELD);
        } else if (result.error) {
            console.error('Error loading booking event:', result.error);
        }
    }

    // Wire to get existing event items
    @wire(getEventItems, { bookingEventId: '$recordId' })
    wiredEventItems(result) {
        this.wiredEventItemsResult = result;
        if (result.data) {
            this.eventItems = result.data;
        } else if (result.error) {
            console.error('Error loading event items:', result.error);
            this.showToast('Error', 'Failed to load event items', 'error');
        }
    }

    // Getters
    get hasEventItems() {
        return this.eventItems && this.eventItems.length > 0;
    }

    get eventItemCount() {
        return this.eventItems ? this.eventItems.length : 0;
    }

    get cardTitle() {
        return `Menu Items (${this.eventItemCount})`;
    }

    get hasSelectedRows() {
        return this.selectedRows && this.selectedRows.length > 0;
    }

    get deleteButtonLabel() {
        const count = this.selectedRows ? this.selectedRows.length : 0;
        return count > 1 ? `Delete Selected (${count})` : 'Delete Selected';
    }

    get filteredCatalogueItems() {
        if (!this.searchTerm) {
            return this.catalogueItems;
        }
        const term = this.searchTerm.toLowerCase();
        return this.catalogueItems.filter(item =>
            (item.Name && item.Name.toLowerCase().includes(term)) ||
            (item.Description__c && item.Description__c.toLowerCase().includes(term)) ||
            (item.ItemCategory__c && item.ItemCategory__c.toLowerCase().includes(term)) ||
            (item.RevenueClassification__c && item.RevenueClassification__c.toLowerCase().includes(term))
        );
    }

    get catalogueItemCount() {
        return this.filteredCatalogueItems ? this.filteredCatalogueItems.length : 0;
    }

    get selectedCatalogueCount() {
        return this.selectedCatalogueItems ? this.selectedCatalogueItems.length : 0;
    }

    get hasSelectedCatalogueItems() {
        return this.selectedCatalogueCount > 0;
    }

    get isDeleteDisabled() {
        return !this.hasSelectedRows;
    }

    get isAddDisabled() {
        return !this.hasSelectedCatalogueItems;
    }

    get addButtonLabel() {
        return this.selectedCatalogueCount > 0
            ? `Add ${this.selectedCatalogueCount} Item${this.selectedCatalogueCount > 1 ? 's' : ''}`
            : 'Add Items';
    }

    get modalTitle() {
        return `Select Items from Catalogue${this.propertyName ? ' - ' + this.propertyName : ''}`;
    }

    // Event Handlers
    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows.map(row => row.Id);
    }

    handleCatalogueRowSelection(event) {
        this.selectedCatalogueItems = event.detail.selectedRows.map(row => row.Id);
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    async handleCellChange(event) {
        const draftValues = event.detail.draftValues;

        if (draftValues && draftValues.length > 0) {
            this.isLoading = true;
            try {
                const result = await updateEventItems({
                    eventItemsJson: JSON.stringify(draftValues)
                });

                if (result.success) {
                    this.showToast('Success', result.message, 'success');
                    await refreshApex(this.wiredEventItemsResult);
                } else if (result.hasErrors) {
                    this.showToast('Error', result.errors.join(', '), 'error');
                }
            } catch (error) {
                console.error('Error updating items:', error);
                this.showToast('Error', 'Failed to update items: ' + error.body?.message, 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    async handleAddItemsClick() {
        this.showAddItemsModal = true;
        this.selectedCatalogueItems = [];
        this.searchTerm = '';
        await this.loadCatalogueItems();
    }

    handleCloseModal() {
        this.showAddItemsModal = false;
        this.selectedCatalogueItems = [];
        this.searchTerm = '';
    }

    async loadCatalogueItems() {
        this.isLoading = true;
        try {
            this.catalogueItems = await getCatalogueItems({
                propertyName: this.propertyName
            });
        } catch (error) {
            console.error('Error loading catalogue items:', error);
            this.showToast('Error', 'Failed to load catalogue items', 'error');
            this.catalogueItems = [];
        } finally {
            this.isLoading = false;
        }
    }

    async handleAddSelectedItems() {
        if (this.selectedCatalogueItems.length === 0) {
            this.showToast('Warning', 'Please select at least one item', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            const result = await createEventItems({
                bookingEventId: this.recordId,
                bookingId: this.bookingId,
                selectedItemIds: this.selectedCatalogueItems
            });

            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.handleCloseModal();
                await refreshApex(this.wiredEventItemsResult);
            } else if (result.hasErrors) {
                this.showToast('Error', result.errors.join(', '), 'error');
            }
        } catch (error) {
            console.error('Error creating event items:', error);
            this.showToast('Error', 'Failed to add items: ' + error.body?.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteSelected() {
        if (this.selectedRows.length === 0) {
            return;
        }

        this.isLoading = true;
        try {
            const result = await deleteEventItems({
                eventItemIds: this.selectedRows
            });

            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.selectedRows = [];
                await refreshApex(this.wiredEventItemsResult);
            } else if (result.hasErrors) {
                this.showToast('Error', result.errors.join(', '), 'error');
            }
        } catch (error) {
            console.error('Error deleting items:', error);
            this.showToast('Error', 'Failed to delete items: ' + error.body?.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredEventItemsResult);
            this.showToast('Success', 'Data refreshed', 'success');
        } catch (error) {
            console.error('Error refreshing:', error);
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        }));
    }
}

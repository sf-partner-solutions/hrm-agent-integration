import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import AMADEUS_LOGO from '@salesforce/resourceUrl/AmadeusLogo';
import updateEventItemPrices from '@salesforce/apex/UpdateBookingMenuItemsAction.updateEventItemPrices';

const columns = [
    {
        label: 'Booking',
        fieldName: 'bookingUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'bookingName' },
            target: '_blank'
        },
        initialWidth: 180
    },
    {
        label: 'Event',
        fieldName: 'eventName',
        type: 'text',
        initialWidth: 180
    },
    {
        label: 'Menu Item',
        fieldName: 'itemName',
        type: 'text',
        cellAttributes: { class: 'slds-text-title_bold' },
        initialWidth: 150
    },
    {
        label: 'Price',
        fieldName: 'unitPrice',
        type: 'currency',
        typeAttributes: { currencyCode: 'USD' },
        editable: true,
        initialWidth: 120,
        cellAttributes: {
            iconName: 'utility:edit',
            iconPosition: 'right',
            iconAlternativeText: 'Edit price'
        }
    }
];

export default class BookingMenuItemsResults extends NavigationMixin(LightningElement) {
    // Value property for Agentforce - CRITICAL for receiving data
    _value;

    @track displayItems = [];
    @track draftValues = [];
    @track originalItems = [];

    columns = columns;
    isLoading = false;
    amadeusLogoUrl = AMADEUS_LOGO;

    // Data from the Apex output
    bookingIds = '';
    eventItemIds = '';
    itemNameSearched = '';
    searchCriteriaUsed = '';
    resultsSummary = '';
    propertyId = '';

    @api
    get value() {
        return this._value;
    }

    set value(val) {
        console.log('=== bookingMenuItemsResults: Received value ===');
        console.log('Value:', JSON.stringify(val, null, 2));

        this._value = val;

        if (val) {
            // Extract data from the value object (Agentforce passes data this way)
            this.bookingIds = val.bookingIds || '';
            this.eventItemIds = val.eventItemIds || '';
            this.itemNameSearched = val.itemNameSearched || '';
            this.searchCriteriaUsed = val.searchCriteriaUsed || '';
            this.resultsSummary = val.resultsSummary || '';
            this.propertyId = val.propertyId || '';

            // Process the results
            this.processResults();
        }
    }

    connectedCallback() {
        console.log('bookingMenuItemsResults connected');
        // If value was set before connectedCallback, process it
        if (this._value) {
            this.processResults();
        }
    }

    /**
     * Process results from the search action output
     */
    processResults() {
        // Clear existing items
        this.displayItems = [];
        this.originalItems = [];
        this.draftValues = [];

        // Parse the resultsSummary if available (markdown format from FindBookingsByMenuItemAction)
        if (this.resultsSummary) {
            this.parseResultsSummary();
        }
    }

    /**
     * Parse the markdown summary into structured data
     */
    parseResultsSummary() {
        if (!this.resultsSummary) {
            return;
        }

        const lines = this.resultsSummary.split('\n');
        const items = [];
        let index = 0;

        // Get the ID lists for mapping
        const bookingIdList = this.bookingIds ? this.bookingIds.split(',').map(id => id.trim()) : [];
        const eventItemIdList = this.eventItemIds ? this.eventItemIds.split(',').map(id => id.trim()) : [];

        for (const line of lines) {
            // Parse lines like: - **BK-00123** (Lunch Event) on Jan 15, 2025: Coffee ($10.00) x50
            const match = line.match(/^\s*-\s*\*\*(.+?)\*\*\s*\((.+?)\)(?:\s*on\s*(.+?))?:\s*(.+)$/);

            if (match) {
                const bookingName = match[1];
                const eventName = match[2];
                const eventDateStr = match[3];
                const itemsStr = match[4];

                // Parse individual items from the line
                const itemMatches = itemsStr.split(',');

                for (const itemStr of itemMatches) {
                    // Match pattern like: Coffee ($10.00) x50
                    const itemMatch = itemStr.trim().match(/^(.+?)\s*(?:\(\$?([\d.]+)\))?\s*(?:x(\d+))?$/);

                    if (itemMatch) {
                        const eventItemId = eventItemIdList[index] || `item-${index}`;
                        const bookingId = bookingIdList.length > 0 ? bookingIdList[Math.min(index, bookingIdList.length - 1)] : null;
                        const unitPrice = itemMatch[2] ? parseFloat(itemMatch[2]) : null;

                        items.push({
                            id: eventItemId,
                            eventItemId: eventItemId,
                            bookingId: bookingId,
                            bookingName: bookingName,
                            bookingUrl: bookingId ? `/lightning/r/Booking__c/${bookingId}/view` : null,
                            eventName: eventName,
                            eventDate: eventDateStr ? this.parseEventDate(eventDateStr) : null,
                            itemName: itemMatch[1].trim(),
                            unitPrice: unitPrice,
                            originalPrice: unitPrice,
                            bookedQuantity: itemMatch[3] ? parseInt(itemMatch[3], 10) : null
                        });
                        index++;
                    }
                }
            }
        }

        this.displayItems = items;
        // Keep a deep copy of original items for cancel functionality
        this.originalItems = JSON.parse(JSON.stringify(items));

        console.log('Parsed display items:', JSON.stringify(this.displayItems, null, 2));
    }

    /**
     * Parse date string to Date object
     */
    parseEventDate(dateStr) {
        if (!dateStr) return null;
        try {
            return new Date(dateStr);
        } catch (e) {
            return null;
        }
    }

    /**
     * Handle cell changes in the data table (for editable price)
     */
    handleCellChange(event) {
        this.draftValues = event.detail.draftValues;
        console.log('Draft values:', JSON.stringify(this.draftValues));
    }

    /**
     * Handle Save (Update) button click
     */
    async handleSave() {
        if (!this.draftValues || this.draftValues.length === 0) {
            return;
        }

        this.isLoading = true;

        try {
            // Build the updates array for Apex
            const updates = this.draftValues.map(draft => ({
                eventItemId: draft.id,
                newPrice: draft.unitPrice
            }));

            console.log('Sending updates to Apex:', JSON.stringify(updates));

            // Call Apex method
            const result = await updateEventItemPrices({ updates: updates });

            console.log('Update result:', JSON.stringify(result));

            if (result.success) {
                // Update the local data with new prices
                const draftMap = new Map();
                this.draftValues.forEach(draft => {
                    draftMap.set(draft.id, draft.unitPrice);
                });

                this.displayItems = this.displayItems.map(item => {
                    if (draftMap.has(item.id)) {
                        return {
                            ...item,
                            unitPrice: draftMap.get(item.id),
                            originalPrice: draftMap.get(item.id)
                        };
                    }
                    return item;
                });

                // Update originalItems for future cancel operations
                this.originalItems = JSON.parse(JSON.stringify(this.displayItems));

                // Clear draft values
                this.draftValues = [];

                // Show success toast
                this.showToast(
                    'Success',
                    `Updated ${result.itemsUpdated} menu item(s) across ${result.bookingsAffected} booking(s).`,
                    'success'
                );
            } else {
                this.showToast('Error', result.message || 'Failed to update prices.', 'error');
            }
        } catch (error) {
            console.error('Error saving prices:', error);
            this.showToast('Error', error.body?.message || 'An error occurred while saving.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Handle Cancel button click
     */
    handleCancel() {
        // Reset display items to original values
        this.displayItems = JSON.parse(JSON.stringify(this.originalItems));
        // Clear draft values
        this.draftValues = [];

        this.showToast('Cancelled', 'Price changes have been discarded.', 'info');
    }

    /**
     * Navigate to a booking record
     */
    handleViewBooking(event) {
        const bookingId = event.currentTarget.dataset.id;
        if (bookingId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: bookingId,
                    objectApiName: 'Booking__c',
                    actionName: 'view'
                }
            });
        }
    }

    /**
     * Show toast notification
     */
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    /**
     * Getters for template
     */
    get hasResults() {
        return this.displayItems && this.displayItems.length > 0;
    }

    get totalItemsText() {
        const itemCount = this.displayItems.length;
        const bookingCount = this.uniqueBookingCount;
        return `Found ${itemCount} menu item${itemCount !== 1 ? 's' : ''} across ${bookingCount} booking${bookingCount !== 1 ? 's' : ''}`;
    }

    get uniqueBookingCount() {
        if (!this.displayItems || this.displayItems.length === 0) {
            return 0;
        }
        const uniqueBookings = new Set(this.displayItems.map(item => item.bookingName));
        return uniqueBookings.size;
    }

    get searchedItemName() {
        return this.itemNameSearched || 'items';
    }

    get hasChanges() {
        return this.draftValues && this.draftValues.length > 0;
    }

    get changesCount() {
        return this.draftValues ? this.draftValues.length : 0;
    }

    get showSearchCriteria() {
        return this.searchCriteriaUsed && this.searchCriteriaUsed.length > 0;
    }
}

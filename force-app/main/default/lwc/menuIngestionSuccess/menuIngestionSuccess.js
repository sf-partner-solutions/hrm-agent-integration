import { LightningElement, api } from 'lwc';
import AMADEUS_LOGO from '@salesforce/resourceUrl/AmadeusLogo';

export default class MenuIngestionSuccess extends LightningElement {
    @api itemCount = 0;  // Primary property to use for count
    @api successCount = 0;  // Fallback for backward compatibility
    @api message = '';  // Optional custom message
    @api createdItemIds = [];
    amadeusLogoUrl = AMADEUS_LOGO;

    handleUploadMore() {
        // Dispatch event to reset and allow new upload
        const uploadMoreEvent = new CustomEvent('uploadmore');
        this.dispatchEvent(uploadMoreEvent);
    }

    handleViewItems() {
        // Navigate to Items list view
        const viewEvent = new CustomEvent('viewitems', {
            detail: {
                itemIds: this.createdItemIds
            }
        });
        this.dispatchEvent(viewEvent);
    }

    get successMessage() {
        // Use custom message if provided, otherwise generate from count
        if (this.message) {
            return this.message;
        }
        // Use itemCount if available, otherwise fall back to successCount
        const count = this.itemCount || this.successCount || 0;
        const itemText = count === 1 ? 'item' : 'items';
        return `Successfully created ${count} ${itemText} in Delphi`;
    }

    get showViewButton() {
        return this.createdItemIds && this.createdItemIds.length > 0;
    }
}
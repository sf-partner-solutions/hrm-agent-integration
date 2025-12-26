import { LightningElement, api } from 'lwc';
import AMADEUS_LOGO from '@salesforce/resourceUrl/AmadeusLogo';

export default class MenuIngestionSuccess extends LightningElement {
    @api successCount = 0;
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
        const itemText = this.successCount === 1 ? 'item' : 'items';
        return `Successfully created ${this.successCount} ${itemText} in Delphi`;
    }

    get showViewButton() {
        return this.createdItemIds && this.createdItemIds.length > 0;
    }
}
import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class SampleImportSuccess extends NavigationMixin(LightningElement) {
    @api recordId;
    @api recordName;

    handleOpen() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Sample__c',
                actionName: 'view'
            }
        });
    }

    handleImportAnother() {
        this.dispatchEvent(new CustomEvent('reset'));
    }
}

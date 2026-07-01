import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getRecentSamples from '@salesforce/apex/SampleTrfController.getRecentSamples';

const COLUMNS = [
    {
        label: 'Sample ID',
        fieldName: 'recordUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'Sample_ID__c' }, target: '_self' }
    },
    { label: 'Sample Name',        fieldName: 'Customer_Sample_Name__c' },
    { label: 'Sample Type',        fieldName: 'Sample_Type__c' },
    { label: 'Date of Collection', fieldName: 'Date_of_Collection__c', type: 'date-local' },
    { label: 'Box ID',             fieldName: 'Box_ID__c' },
    { label: 'Status',             fieldName: 'Status__c' }
];

export default class SampleHomeBanner extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    samples = [];
    error;

    @wire(getRecentSamples)
    wired({ data, error }) {
        if (data) {
            this.samples = data.map((s) => ({
                ...s,
                recordUrl: `/lightning/r/Sample__c/${s.Id}/view`,
                Sample_ID__c: s.Sample_ID__c || s.Name
            }));
        } else if (error) {
            this.error = error;
        }
    }

    get sampleCount() {
        return this.samples ? this.samples.length : 0;
    }

    handleImport() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Sample_Import' }
        });
    }

    handleNew() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Sample__c', actionName: 'new' }
        });
    }

    handleNoop(event) {
        const action = event.target.label || 'Action';
        // eslint-disable-next-line no-console
        console.log(`${action} clicked (demo placeholder)`);
    }
}

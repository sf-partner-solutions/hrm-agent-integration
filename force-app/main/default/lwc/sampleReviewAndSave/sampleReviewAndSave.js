import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getContentVersionId from '@salesforce/apex/SampleTrfController.getContentVersionId';
import createSample from '@salesforce/apex/SampleTrfController.createSample';

const SAMPLE_TYPE_OPTIONS = [
    'Tissue', 'Blood', 'Saliva', 'Urine', 'Cells', 'Cell Pellet',
    'DNA', 'RNA', 'Plasma', 'Serum', 'Other'
].map((v) => ({ label: v, value: v }));

const GENDER_OPTIONS = ['Male', 'Female', 'Other', 'Unknown'].map((v) => ({ label: v, value: v }));
const PRIORITY_OPTIONS = ['STAT', 'ASAP', 'Routine'].map((v) => ({ label: v, value: v }));
const STATUS_OPTIONS = ['New', 'In Progress', 'Testing Completed', 'Complete'].map((v) => ({ label: v, value: v }));

// Ordered field display for the side-by-side table.
const FIELDS = [
    { group: 'Patient & TRF', label: 'Patient Name',         api: 'Patient_Name__c',         type: 'text' },
    { group: 'Patient & TRF', label: 'Patient DOB',          api: 'Patient_DOB__c',          type: 'date' },
    { group: 'Patient & TRF', label: 'Patient MRN',          api: 'Patient_MRN__c',          type: 'text' },
    { group: 'Patient & TRF', label: 'Patient Gender',       api: 'Patient_Gender__c',       type: 'picklist', options: GENDER_OPTIONS },
    { group: 'Patient & TRF', label: 'Ordering Physician',   api: 'Ordering_Physician__c',   type: 'text' },
    { group: 'Patient & TRF', label: 'Priority',             api: 'Priority__c',             type: 'picklist', options: PRIORITY_OPTIONS },
    { group: 'Patient & TRF', label: 'Status',               api: 'Status__c',               type: 'picklist', options: STATUS_OPTIONS },
    { group: 'Sample',        label: 'Customer Sample Name', api: 'Customer_Sample_Name__c', type: 'text' },
    { group: 'Sample',        label: 'Sample Type',          api: 'Sample_Type__c',          type: 'picklist', options: SAMPLE_TYPE_OPTIONS },
    { group: 'Sample',        label: 'Date of Collection',   api: 'Date_of_Collection__c',   type: 'date' },
    { group: 'Sample',        label: 'Number of Aliquots',   api: 'Number_of_Aliquots__c',   type: 'number' },
    { group: 'Sample',        label: 'Concentration (ng/uL)', api: 'Concentration__c',       type: 'number' },
    { group: 'Sample',        label: 'Frozen',               api: 'Frozen__c',               type: 'checkbox' },
    { group: 'Sample',        label: 'Quality Control Check', api: 'Quality_Control_Check__c', type: 'checkbox' },
    { group: 'Storage',       label: 'Freezer/Refrigerator', api: 'Freezer_Refrigerator__c', type: 'text' },
    { group: 'Storage',       label: 'Drawer',               api: 'Drawer__c',               type: 'text' },
    { group: 'Storage',       label: 'Box ID',               api: 'Box_ID__c',               type: 'text' },
    { group: 'Storage',       label: 'Rack',                 api: 'Rack__c',                 type: 'text' },
    { group: 'Storage',       label: 'Box Position',         api: 'Box_Position__c',         type: 'text' },
    { group: 'Tests',         label: 'Tests Requested',      api: 'Tests_Requested__c',      type: 'textarea' },
    { group: 'Tests',         label: 'Clinical Notes',       api: 'Clinical_Notes__c',       type: 'textarea' }
];

export default class SampleReviewAndSave extends NavigationMixin(LightningElement) {
    @track sample = {};
    @track metadata = {};
    @track contentDocumentId;
    @track contentVersionId;
    @track fileName;
    @track isSaving = false;

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (!pageRef || !pageRef.state) return;
        const s = pageRef.state;
        if (s.c__sample) {
            try { this.sample = JSON.parse(s.c__sample); } catch (e) { this.sample = {}; }
        }
        if (s.c__metadata) {
            try { this.metadata = JSON.parse(s.c__metadata); } catch (e) { this.metadata = {}; }
        }
        if (s.c__fileName) this.fileName = s.c__fileName;
        if (s.c__contentDocumentId) {
            this.contentDocumentId = s.c__contentDocumentId;
            this.loadContentVersion();
        }
    }

    async loadContentVersion() {
        try {
            this.contentVersionId = await getContentVersionId({ contentDocumentId: this.contentDocumentId });
        } catch (e) {
            console.error('Failed to resolve ContentVersion id', e);
            this.contentVersionId = this.contentDocumentId;
        }
    }

    // Render rows for the table — re-runs whenever `sample` changes.
    get rows() {
        return FIELDS.map((f) => {
            const value = this.sample ? this.sample[f.api] : null;
            return {
                api: f.api,
                label: f.label,
                group: f.group,
                type: f.type,
                value: value == null ? '' : value,
                checked: !!value,
                options: f.options || [],
                isText: f.type === 'text',
                isDate: f.type === 'date',
                isNumber: f.type === 'number',
                isTextarea: f.type === 'textarea',
                isCheckbox: f.type === 'checkbox',
                isPicklist: f.type === 'picklist'
            };
        });
    }

    get pdfUrl() {
        if (!this.contentVersionId) return '';
        return `/sfc/servlet.shepherd/version/download/${this.contentVersionId}`;
    }

    get hasPdf() {
        return !!this.contentVersionId;
    }

    get extractedDate() {
        return this.metadata && this.metadata.extracted_date;
    }

    get confidenceNotes() {
        return this.metadata && this.metadata.confidence_notes;
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        const type = event.target.dataset.type;
        let value;
        if (type === 'checkbox') {
            value = event.target.checked;
        } else if (type === 'number') {
            value = event.target.value === '' ? null : Number(event.target.value);
        } else {
            value = event.target.value;
        }
        this.sample = { ...this.sample, [field]: value };
    }

    async handleImport() {
        this.isSaving = true;
        try {
            const result = await createSample({ data: this.sample });
            if (result.success) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Sample created',
                    message: `${result.recordName} created from ${this.fileName || 'TRF'}`,
                    variant: 'success'
                }));
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result.recordId,
                        objectApiName: 'Sample__c',
                        actionName: 'view'
                    }
                });
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Could not create sample',
                    message: result.errorMessage || 'Unknown error',
                    variant: 'error'
                }));
            }
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: e?.body?.message || e.message,
                variant: 'error'
            }));
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Sample_Import' }
        });
    }
}

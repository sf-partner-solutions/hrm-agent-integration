import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import createSample from '@salesforce/apex/SampleTrfController.createSample';

const SAMPLE_TYPE_OPTIONS = [
    'Tissue', 'Blood', 'Saliva', 'Urine', 'Cells', 'Cell Pellet',
    'DNA', 'RNA', 'Plasma', 'Serum', 'Other'
].map((v) => ({ label: v, value: v }));

const GENDER_OPTIONS = [
    'Male', 'Female', 'Other', 'Unknown'
].map((v) => ({ label: v, value: v }));

const PRIORITY_OPTIONS = [
    'STAT', 'ASAP', 'Routine'
].map((v) => ({ label: v, value: v }));

const STATUS_OPTIONS = [
    'New', 'In Progress', 'Testing Completed', 'Complete'
].map((v) => ({ label: v, value: v }));

export default class SampleFieldsPreview extends NavigationMixin(LightningElement) {
    @api extractedJson;
    @api fileName;
    @api contentDocumentId;

    @track sample = {};
    @track metadata = {};
    isSaving = false;

    sampleTypeOptions = SAMPLE_TYPE_OPTIONS;
    genderOptions = GENDER_OPTIONS;
    priorityOptions = PRIORITY_OPTIONS;
    statusOptions = STATUS_OPTIONS;

    connectedCallback() {
        this.hydrate();
    }

    hydrate() {
        try {
            const parsed = JSON.parse(this.extractedJson || '{}');
            this.sample = parsed.sample || {};
            this.metadata = parsed.extraction_metadata || {};
        } catch (e) {
            console.error('Could not parse extracted JSON', e);
            this.sample = {};
            this.metadata = {};
        }
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        let value = event.target.value;
        if (event.target.type === 'checkbox') {
            value = event.target.checked;
        } else if (event.target.type === 'number') {
            value = value === '' ? null : Number(value);
        }
        this.sample = { ...this.sample, [field]: value };
    }

    handleReviewAndSave() {
        // Hand off to the side-by-side review page via URL-addressable LWC.
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__sampleReviewAndSave' },
            state: {
                c__sample: JSON.stringify(this.sample || {}),
                c__metadata: JSON.stringify(this.metadata || {}),
                c__contentDocumentId: this.contentDocumentId,
                c__fileName: this.fileName
            }
        });
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
                this.dispatchEvent(new CustomEvent('imported', {
                    detail: { recordId: result.recordId, recordName: result.recordName }
                }));
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
        this.dispatchEvent(new CustomEvent('cancel'));
    }
}

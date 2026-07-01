import { LightningElement, track } from 'lwc';
import processUploadedFile from '@salesforce/apex/SampleTrfAgentAction.processUploadedFile';

const STATES = {
    UPLOAD: 'UPLOAD_REQUIRED',
    FIELDS: 'FIELDS_EXTRACTED',
    SUCCESS: 'SUCCESS',
    ERROR: 'ERROR'
};

export default class SampleImportRouter extends LightningElement {
    @track responseType = STATES.UPLOAD;
    @track extractedJson;
    @track fileName;
    @track contentDocumentId;
    @track errorMessage;
    @track createdRecordId;
    @track createdRecordName;

    get showUpload() { return this.responseType === STATES.UPLOAD; }
    get showPreview() { return this.responseType === STATES.FIELDS; }
    get showSuccess() { return this.responseType === STATES.SUCCESS; }
    get showError() { return this.responseType === STATES.ERROR; }

    async handleFileUploaded(event) {
        const { contentDocumentId, fileName } = event.detail;
        this.fileName = fileName;
        this.contentDocumentId = contentDocumentId;

        const uploadHandler = this.template.querySelector('c-sample-trf-upload-handler');
        if (uploadHandler) uploadHandler.isProcessing = true;

        try {
            const result = await processUploadedFile({ contentDocumentId });
            if (!result.success) {
                this.responseType = STATES.ERROR;
                this.errorMessage = result.errorMessage || result.message;
                return;
            }
            this.responseType = result.responseType;
            this.extractedJson = result.extractedSampleJson;
        } catch (e) {
            this.responseType = STATES.ERROR;
            this.errorMessage = e?.body?.message || e.message;
        } finally {
            if (uploadHandler) uploadHandler.isProcessing = false;
        }
    }

    handleImported(event) {
        this.createdRecordId = event.detail.recordId;
        this.createdRecordName = event.detail.recordName;
        this.responseType = STATES.SUCCESS;
    }

    handleCancel() {
        this.reset();
    }

    handleReset() {
        this.reset();
    }

    reset() {
        this.responseType = STATES.UPLOAD;
        this.extractedJson = null;
        this.fileName = null;
        this.contentDocumentId = null;
        this.errorMessage = null;
        this.createdRecordId = null;
        this.createdRecordName = null;
    }
}

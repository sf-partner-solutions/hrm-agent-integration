import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SampleTrfUploadHandler extends LightningElement {
    @api recordId;
    @api isProcessing = false;
    uploadedFiles = [];

    get acceptedFormats() {
        return ['.pdf'];
    }

    handleUploadFinished(event) {
        const files = event.detail.files;
        if (files && files.length > 0) {
            this.uploadedFiles = files;
            this.isProcessing = true;
            this.showToast('Uploaded', `${files[0].name} uploaded. Parsing with AI…`, 'success');
            this.dispatchEvent(new CustomEvent('fileuploaded', {
                detail: {
                    files,
                    contentDocumentId: files[0].documentId || files[0].contentDocumentId,
                    fileName: files[0].name
                }
            }));
        }
    }

    handleUploadError() {
        this.showToast('Error', 'Failed to upload TRF. Please try again.', 'error');
    }

    handleRemove() {
        this.uploadedFiles = [];
        this.dispatchEvent(new CustomEvent('fileremove'));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get hasUploadedFiles() {
        return this.uploadedFiles.length > 0;
    }

    get uploadedFileName() {
        return this.hasUploadedFiles ? this.uploadedFiles[0].name : '';
    }
}

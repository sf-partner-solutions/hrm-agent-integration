import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import AMADEUS_LOGO from '@salesforce/resourceUrl/AmadeusLogo';

export default class MenuUploadHandler extends LightningElement {
    @api recordId;
    @api isProcessing = false;  // Made public so parent can control it
    amadeusLogoUrl = AMADEUS_LOGO;
    uploadedFiles = [];
    isUploading = false;

    get acceptedFormats() {
        return ['.pdf'];
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        console.log('Upload finished, files:', uploadedFiles);

        if (uploadedFiles && uploadedFiles.length > 0) {
            this.uploadedFiles = uploadedFiles;
            this.isProcessing = true; // Start processing state

            // Log the file details to debug
            console.log('First file details:', uploadedFiles[0]);
            console.log('documentId:', uploadedFiles[0].documentId);
            console.log('contentDocumentId:', uploadedFiles[0].contentDocumentId);

            // Show success message
            this.showToast('Success', `File ${uploadedFiles[0].name} uploaded successfully. Processing...`, 'success');

            // Dispatch event to parent/agent with file details
            // Note: lightning-file-upload returns documentId which is the ContentDocumentId
            const fileUploadEvent = new CustomEvent('fileuploaded', {
                detail: {
                    files: uploadedFiles,
                    contentDocumentId: uploadedFiles[0].documentId || uploadedFiles[0].contentDocumentId,
                    fileName: uploadedFiles[0].name
                }
            });
            this.dispatchEvent(fileUploadEvent);
        }
    }

    handleUploadError(event) {
        this.showToast('Error', 'Failed to upload file. Please try again.', 'error');
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    get hasUploadedFiles() {
        return this.uploadedFiles.length > 0;
    }

    get uploadedFileName() {
        return this.hasUploadedFiles ? this.uploadedFiles[0].name : '';
    }

    handleRemove() {
        this.uploadedFiles = [];

        // Dispatch event to notify file removed
        const removeEvent = new CustomEvent('fileremove');
        this.dispatchEvent(removeEvent);
    }
}
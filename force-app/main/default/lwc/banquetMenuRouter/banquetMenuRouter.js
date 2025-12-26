import { LightningElement, api } from 'lwc';
import processUploadedFile from '@salesforce/apex/BanquetMenuAgentAction.processUploadedFile';

export default class BanquetMenuRouter extends LightningElement {
    _value;

    // Individual properties for template use
    responseType;
    message;
    extractedItemsJson;
    itemCount;
    errorMessage;
    success;

    @api
    get value() {
        return this._value;
    }

    set value(value) {
        this._value = value;
        console.log('BanquetMenuRouter received value:', JSON.stringify(value));

        // Extract properties from the value object
        if (value) {
            this.responseType = value.responseType;
            this.message = value.message;
            this.extractedItemsJson = value.extractedItemsJson;
            this.itemCount = value.itemCount;
            this.errorMessage = value.errorMessage;
            this.success = value.success;
        }
    }

    connectedCallback() {
        console.log('BanquetMenuRouter connected');
        console.log('Value:', this._value);
        console.log('ResponseType:', this.responseType);
    }

    get showUploadHandler() {
        return this.responseType === 'UPLOAD_REQUIRED';
    }

    get showItemsPreview() {
        return this.responseType === 'ITEMS_EXTRACTED';
    }

    get showSuccess() {
        return this.responseType === 'SUCCESS';
    }

    get showError() {
        return this.responseType === 'ERROR';
    }

    get parsedItems() {
        if (this.extractedItemsJson) {
            try {
                const data = JSON.parse(this.extractedItemsJson);
                return data.items || [];
            } catch (e) {
                console.error('Error parsing items:', e);
                return [];
            }
        }
        return [];
    }

    get parsedMetadata() {
        if (this.extractedItemsJson) {
            try {
                const data = JSON.parse(this.extractedItemsJson);
                return data.extraction_metadata || {};
            } catch (e) {
                console.error('Error parsing metadata:', e);
                return {};
            }
        }
        return {};
    }

    async handleFileUploaded(event) {
        console.log('handleFileUploaded called with event:', event.detail);

        // Get the file ID from the upload event
        const fileId = event.detail.contentDocumentId;
        console.log('File uploaded with ID:', fileId);

        if (!fileId) {
            console.error('No file ID received!');
            this.responseType = 'ERROR';
            this.errorMessage = 'No file ID received from upload';
            return;
        }

        // Start processing indicator
        const uploadHandler = this.template.querySelector('c-menu-upload-handler');
        if (uploadHandler) {
            uploadHandler.isProcessing = true;
        }

        try {
            console.log('Calling processUploadedFile with:', fileId);
            // Call Apex to process the uploaded file
            const result = await processUploadedFile({ contentDocumentId: fileId });
            console.log('Processing result:', result);

            // Update component state with the response
            if (result) {
                this.responseType = result.responseType;
                this.message = result.message;
                this.extractedItemsJson = result.extractedItemsJson;
                this.itemCount = result.itemCount;
                this.errorMessage = result.errorMessage;
                this.success = result.success;
                console.log('Component state updated, responseType:', this.responseType);
            }
        } catch (error) {
            console.error('Error processing file:', error);
            console.error('Error details:', JSON.stringify(error));
            this.responseType = 'ERROR';
            this.errorMessage = error.body ? error.body.message : error.message;
            this.success = false;
        } finally {
            // Stop processing spinner
            if (uploadHandler) {
                uploadHandler.isProcessing = false;
            }
        }

        // Fire event for Agent framework (in case it's listening)
        this.dispatchEvent(new CustomEvent('fileready', {
            detail: {
                contentDocumentId: fileId,
                fileName: event.detail.fileName
            },
            bubbles: true,
            composed: true
        }));
    }

    handleItemsSaved(event) {
        // Update the response type to show success
        this.responseType = 'SUCCESS';
        this.message = event.detail.message;
        this.itemCount = event.detail.itemCount;
    }
}
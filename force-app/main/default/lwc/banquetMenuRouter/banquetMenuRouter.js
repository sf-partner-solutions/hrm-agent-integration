import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import MENU_INGESTION_CHANNEL from '@salesforce/messageChannel/MenuIngestionStatus__c';
import processUploadedFile from '@salesforce/apex/BanquetMenuAgentAction.processUploadedFile';

const PROPERTY_FIELDS = ['Location__c.Name'];

export default class BanquetMenuRouter extends LightningElement {
    _value;
    subscription = null;

    // API properties automatically provided by Salesforce on record pages
    @api recordId;
    @api objectApiName;

    // Deprecated API properties (kept for backward compatibility)
    _propertyId;
    _propertyName;

    @api
    get propertyId() {
        // Always prioritize recordId over the deprecated property
        return this.recordId || this._propertyId;
    }
    set propertyId(value) {
        this._propertyId = value;
    }

    @api
    get propertyName() {
        return this._propertyName;
    }
    set propertyName(value) {
        this._propertyName = value;
    }

    // Individual properties for template use
    responseType;
    message;
    extractedItemsJson;
    itemCount;
    errorMessage;
    success;
    contentDocumentId;
    pageReference;

    // Wire the MessageContext for Lightning Message Service
    @wire(MessageContext)
    messageContext;

    @api
    get value() {
        return this._value;
    }

    set value(value) {
        this._value = value;
        console.log('BanquetMenuRouter received value:', JSON.stringify(value));
        console.log('BanquetMenuRouter recordId at value setter:', this.recordId);

        // Extract properties from the value object
        if (value) {
            this.responseType = value.responseType;
            this.message = value.message;
            this.extractedItemsJson = value.extractedItemsJson;
            this.itemCount = value.itemCount;
            this.errorMessage = value.errorMessage;
            this.success = value.success;
            // Use propertyId from value or fallback to recordId
            this.propertyId = value.propertyId || this.recordId;
            console.log('Property ID set in value setter:', this.propertyId);

            // Use propertyName if provided in value
            if (value.propertyName) {
                this.propertyName = value.propertyName;
            }
        }
    }

    // Wire adapter to get current page reference and extract record ID
    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef) {
            this.pageReference = pageRef;
            console.log('=== Page Reference in Router ===');
            console.log('Page Ref:', JSON.stringify(pageRef));

            // Try to extract record ID from various sources
            if (pageRef.attributes && pageRef.attributes.recordId) {
                this.recordId = pageRef.attributes.recordId;
                console.log('Got recordId from attributes:', this.recordId);
            } else if (pageRef.state && pageRef.state.recordId) {
                this.recordId = pageRef.state.recordId;
                console.log('Got recordId from state:', this.recordId);
            }
        }
    }

    // Wire adapter to get the property name
    @wire(getRecord, { recordId: '$propertyId', fields: PROPERTY_FIELDS })
    wiredProperty({ error, data }) {
        if (data) {
            this.propertyName = data.fields.Name.value;
            console.log('Property name fetched from record:', this.propertyName);
        } else if (error) {
            console.error('Error fetching property name:', error);
        }
    }

    connectedCallback() {
        console.log('=== BanquetMenuRouter connected ===');
        console.log('Value:', this._value);
        console.log('ResponseType:', this.responseType);
        console.log('Record ID from page:', this.recordId);
        console.log('Property ID (auto-resolved):', this.propertyId);

        // Subscribe to menu ingestion messages
        this.subscribeToMessageChannel();

        // If we're on a Lightning page (not in agent context), show manual upload by default
        if (!this._value && !this.responseType) {
            this.responseType = 'MANUAL_UPLOAD';
            console.log('Setting default responseType to MANUAL_UPLOAD for Lightning page');
        }
    }

    disconnectedCallback() {
        this.unsubscribeFromMessageChannel();
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                MENU_INGESTION_CHANNEL,
                (message) => this.handleMessage(message)
            );
            console.log('Subscribed to menu ingestion message channel');
        }
    }

    unsubscribeFromMessageChannel() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
            console.log('Unsubscribed from menu ingestion message channel');
        }
    }

    handleMessage(message) {
        console.log('Received message via LMS:', message);

        // Update component state based on the message
        if (message.status === 'SUCCESS') {
            this.responseType = 'SUCCESS';
            this.message = message.message;
            this.itemCount = message.itemCount;

            // Optionally update property info if provided
            if (message.propertyId) {
                this.propertyId = message.propertyId;
            }
            if (message.propertyName) {
                this.propertyName = message.propertyName;
            }

            console.log('Updated router to show success state');
        }
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
        console.log('Current propertyId:', this.propertyId);
        console.log('Current propertyName:', this.propertyName);

        // Get the file ID from the upload event
        const fileId = event.detail.contentDocumentId;
        console.log('File uploaded with ID:', fileId);

        // Store the content document ID for later use
        this.contentDocumentId = fileId;

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
            console.log('Calling processUploadedFile with:', fileId, 'propertyId:', this.propertyId);
            // Call Apex to process the uploaded file, passing the property ID
            const result = await processUploadedFile({
                contentDocumentId: fileId,
                propertyId: this.propertyId
            });
            console.log('Processing result:', result);

            // Update component state with the response
            if (result) {
                this.responseType = result.responseType;
                this.message = result.message;
                this.extractedItemsJson = result.extractedItemsJson;
                this.itemCount = result.itemCount;
                this.errorMessage = result.errorMessage;
                this.success = result.success;
                // Preserve the property ID if it comes back in the response
                if (result.propertyId) {
                    this.propertyId = result.propertyId;
                }
                console.log('Component state updated, responseType:', this.responseType);
                console.log('Property ID after processing:', this.propertyId);
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
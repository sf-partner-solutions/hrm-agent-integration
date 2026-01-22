import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { getRecord } from 'lightning/uiRecordApi';
import getEmailLogs from '@salesforce/apex/EmailThreadTreeController.getEmailLogs';
import getThreadDetails from '@salesforce/apex/EmailThreadTreeController.getThreadDetails';
import getEmailLogsForBooking from '@salesforce/apex/EmailThreadTreeController.getEmailLogsForBooking';
import getThreadDetailsForBooking from '@salesforce/apex/EmailThreadTreeController.getThreadDetailsForBooking';

const COLUMNS = [
    {
        type: 'text',
        fieldName: 'name',
        label: 'Log #',
        initialWidth: 120
    },
    {
        type: 'date',
        fieldName: 'createdDate',
        label: 'Date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        },
        initialWidth: 180
    },
    {
        type: 'text',
        fieldName: 'subject',
        label: 'Subject',
        initialWidth: 250
    },
    {
        type: 'text',
        fieldName: 'messagePreview',
        label: 'Message',
        initialWidth: 300,
        wrapText: true
    },
    {
        type: 'text',
        fieldName: 'senderName',
        label: 'From',
        initialWidth: 150
    },
    {
        type: 'text',
        fieldName: 'emailIntent',
        label: 'Intent',
        initialWidth: 140,
        cellAttributes: {
            class: { fieldName: 'intentClass' }
        }
    },
    {
        type: 'text',
        fieldName: 'processingStatus',
        label: 'Status',
        initialWidth: 130,
        cellAttributes: {
            class: { fieldName: 'statusClass' }
        }
    },
    {
        type: 'button',
        typeAttributes: {
            label: 'View Details',
            name: 'view_details',
            variant: 'base',
            iconName: 'utility:preview'
        },
        initialWidth: 130
    }
];

export default class EmailThreadViewer extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @track threadDetails;
    @track emailLogs = [];
    @track error;
    @track isLoading = true;

    columns = COLUMNS;
    wiredLogsResult;
    wiredThreadResult;
    isBookingContext = false;

    // Determine context based on recordId prefix
    get contextType() {
        if (!this.recordId) return null;
        // Email_Thread__c IDs start with 'a0' typically for custom objects
        // Booking__c IDs also start with 'a0' but we can use objectApiName if available
        if (this.objectApiName === 'Booking__c') {
            return 'Booking';
        } else if (this.objectApiName === 'Email_Thread__c') {
            return 'EmailThread';
        }
        // Fallback: try to detect from the record
        return null;
    }

    connectedCallback() {
        this.detectContext();
    }

    detectContext() {
        if (this.objectApiName === 'Booking__c') {
            this.isBookingContext = true;
        } else if (this.objectApiName === 'Email_Thread__c') {
            this.isBookingContext = false;
        }
    }

    // Wire for Email_Thread__c context
    @wire(getThreadDetails, { threadId: '$threadIdParam' })
    wiredThread(result) {
        this.wiredThreadResult = result;
        const { data, error } = result;
        if (data) {
            this.threadDetails = data;
            this.error = undefined;
        } else if (error) {
            // Only show error if we're in thread context
            if (!this.isBookingContext) {
                this.error = this.reduceErrors(error);
            }
            this.threadDetails = undefined;
        }
    }

    @wire(getEmailLogs, { threadId: '$threadIdParam' })
    wiredLogs(result) {
        this.wiredLogsResult = result;
        const { data, error } = result;
        if (!this.isBookingContext) {
            this.isLoading = false;
            if (data) {
                this.emailLogs = this.processLogs(data);
                this.error = undefined;
            } else if (error) {
                this.error = this.reduceErrors(error);
                this.emailLogs = [];
            }
        }
    }

    // Wire for Booking__c context
    @wire(getThreadDetailsForBooking, { bookingId: '$bookingIdParam' })
    wiredThreadForBooking(result) {
        if (this.isBookingContext) {
            this.wiredThreadResult = result;
            const { data, error } = result;
            if (data) {
                this.threadDetails = data;
                this.error = undefined;
            } else if (error) {
                this.error = this.reduceErrors(error);
                this.threadDetails = undefined;
            }
        }
    }

    @wire(getEmailLogsForBooking, { bookingId: '$bookingIdParam' })
    wiredLogsForBooking(result) {
        if (this.isBookingContext) {
            this.wiredLogsResult = result;
            const { data, error } = result;
            this.isLoading = false;
            if (data) {
                this.emailLogs = this.processLogs(data);
                this.error = undefined;
            } else if (error) {
                this.error = this.reduceErrors(error);
                this.emailLogs = [];
            }
        }
    }

    // Reactive properties to trigger the correct wire
    get threadIdParam() {
        return this.isBookingContext ? null : this.recordId;
    }

    get bookingIdParam() {
        return this.isBookingContext ? this.recordId : null;
    }

    processLogs(logs) {
        return logs.map(log => {
            const processed = { ...log };

            // Create message preview showing received and replied content
            processed.messagePreview = this.createMessagePreview(log.originalEmail, log.generatedResponse);

            // Add CSS classes based on intent
            if (log.emailIntent) {
                processed.intentClass = this.getIntentClass(log.emailIntent);
            }

            // Add CSS classes based on status
            if (log.processingStatus) {
                processed.statusClass = this.getStatusClass(log.processingStatus);
            }

            // Transform children to _children for lightning-tree-grid
            // Apex returns 'children' but tree-grid requires '_children'
            if (log.children && log.children.length > 0) {
                processed._children = log.children.map(child => ({
                    ...child,
                    _children: child.children || [],
                    intentClass: '',
                    statusClass: '',
                    messagePreview: child.originalEmail || child.generatedResponse || ''
                }));
            }

            return processed;
        });
    }

    createMessagePreview(originalEmail, generatedResponse) {
        const parts = [];
        if (originalEmail) {
            const truncated = originalEmail.length > 150 ? originalEmail.substring(0, 150) + '...' : originalEmail;
            parts.push('Received: ' + truncated);
        }
        if (generatedResponse) {
            const truncated = generatedResponse.length > 150 ? generatedResponse.substring(0, 150) + '...' : generatedResponse;
            parts.push('Reply: ' + truncated);
        }
        return parts.join(' | ');
    }

    getIntentClass(intent) {
        const intentClasses = {
            'New_Inquiry': 'slds-text-color_success',
            'Booking_Confirmation': 'slds-text-color_success',
            'Booking_Rejection': 'slds-text-color_error',
            'Follow_Up_Answer': 'slds-text-color_weak'
        };
        return intentClasses[intent] || '';
    }

    getStatusClass(status) {
        const statusClasses = {
            'Processed': 'slds-text-color_success',
            'Error': 'slds-text-color_error',
            'Manual_Review': 'slds-text-color_default',
            'Pending_Email_Send': 'slds-text-color_weak',
            'Skipped': 'slds-text-color_inverse-weak'
        };
        return statusClasses[status] || '';
    }

    get hasThreadDetails() {
        return this.threadDetails != null;
    }

    get threadSubject() {
        return this.threadDetails?.Thread_Subject__c || 'No Subject';
    }

    get senderInfo() {
        const name = this.threadDetails?.Sender_Name__c || 'Unknown';
        const email = this.threadDetails?.Sender_Email__c || '';
        return email ? `${name} <${email}>` : name;
    }

    get locationName() {
        return this.threadDetails?.Location__r?.Name || 'Not assigned';
    }

    get threadStatus() {
        return this.threadDetails?.Thread_Status__c || 'Unknown';
    }

    get threadStatusClass() {
        const status = this.threadDetails?.Thread_Status__c;
        const classes = {
            'Active': 'slds-badge slds-badge_success',
            'Closed': 'slds-badge slds-badge_inverse',
            'Pending_Response': 'slds-badge slds-badge_warning'
        };
        return classes[status] || 'slds-badge';
    }

    get hasBooking() {
        return this.threadDetails?.Booking__c != null;
    }

    get bookingName() {
        return this.threadDetails?.Booking__r?.Name || '';
    }

    get emailCount() {
        return this.emailLogs ? this.emailLogs.length : 0;
    }

    get firstEmailDate() {
        if (this.threadDetails?.First_Email_Date__c) {
            return new Date(this.threadDetails.First_Email_Date__c).toLocaleDateString();
        }
        return '';
    }

    get lastEmailDate() {
        if (this.threadDetails?.Last_Email_Date__c) {
            return new Date(this.threadDetails.Last_Email_Date__c).toLocaleDateString();
        }
        return '';
    }

    // Hide booking link when already on booking page
    get showBookingLink() {
        return !this.isBookingContext && this.hasBooking;
    }

    get cardTitle() {
        return this.isBookingContext ? 'Email Conversation' : 'Email Thread Conversation';
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view_details') {
            // Navigate to Email Processing Log record
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.id,
                    objectApiName: 'Email_Processing_Log__c',
                    actionName: 'view'
                }
            });
        }
    }

    handleRefresh() {
        this.isLoading = true;
        Promise.all([
            refreshApex(this.wiredLogsResult),
            refreshApex(this.wiredThreadResult)
        ]).then(() => {
            this.isLoading = false;
        }).catch(error => {
            this.error = this.reduceErrors(error);
            this.isLoading = false;
        });
    }

    navigateToBooking() {
        if (this.threadDetails?.Booking__c) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.threadDetails.Booking__c,
                    objectApiName: 'Booking__c',
                    actionName: 'view'
                }
            });
        }
    }

    navigateToThread() {
        if (this.threadDetails?.Id) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.threadDetails.Id,
                    objectApiName: 'Email_Thread__c',
                    actionName: 'view'
                }
            });
        }
    }

    reduceErrors(errors) {
        if (!Array.isArray(errors)) {
            errors = [errors];
        }

        return errors
            .filter(error => !!error)
            .map(error => {
                if (typeof error === 'string') {
                    return error;
                }
                if (error.message) {
                    return error.message;
                }
                if (error.body && error.body.message) {
                    return error.body.message;
                }
                return JSON.stringify(error);
            })
            .join(', ');
    }
}

/*
 * Copyright 2022 salesforce.com, inc.
 * All Rights Reserved
 * Company Confidential
 */

import { LightningElement, api, track } from 'lwc';

export default class CardDataSelector extends LightningElement {
    
    logoUrl = '/resource/partnerLogo'; // Adjust the path if needed
    textValue = 'New PTO Request'; // Default text
    
    @track startDate = '';
    @track endDate = '';
    @track isScheduled = false;
    @track scheduledDays = 0;
    
    @api
    get value() {
        return this._value;
    }
    
    /**
     * @param {} value
     */
    set value(value) {
        this._value = value;
    }

    /*
    connectedCallback() {
        if (this.value) {
            // Handle any initial value if needed
            // this.value.updatedFlights = this.updatedValue;
            if (this.value.responses && this.value.responses[0] && this.value.responses[0].responseText) {
                this.textValue = this.value.responses[0].responseText.replace(/<[^>]*>/g, '');
                console.log('this.textValue: ', this.textValue);
                console.log('Object.assign: ', Object.assign({}, this.textValue));
                console.log('JSON.stringify: ', JSON.stringify(this.textValue, null, 2));
            }
        }
    }
    */

    // Check if both dates are selected to enable the Schedule button
    get isScheduleDisabled() {
        return !this.startDate || !this.endDate;
    }

    // Show initial form or scheduled confirmation
    get showInitialForm() {
        return !this.isScheduled;
    }

    get showConfirmation() {
        return this.isScheduled;
    }

    get confirmationText() {
        return `Your new PTO has been scheduled for ${this.scheduledDays} days:`;
    }

    // Handle start date change
    handleStartDateChange(event) {
        this.startDate = event.target.value;
        this.calculateDays();
    }

    // Handle end date change
    handleEndDateChange(event) {
        this.endDate = event.target.value;
        this.calculateDays();
    }

    // Calculate number of days between selected dates
    calculateDays() {
        if (this.startDate && this.endDate) {
            const start = new Date(this.startDate);
            const end = new Date(this.endDate);
            const timeDiff = end.getTime() - start.getTime();
            this.scheduledDays = Math.ceil(timeDiff / (1000 * 3600 * 24)) + 1; // +1 to include both start and end dates
        }
    }

    // Handle Schedule button click
    handleSchedule() {
        if (this.startDate && this.endDate) {
            this.isScheduled = true;
            
            // Dispatch custom event with selected dates
            const scheduleEvent = new CustomEvent('schedule', {
                detail: {
                    startDate: this.startDate,
                    endDate: this.endDate,
                    days: this.scheduledDays
                }
            });
            this.dispatchEvent(scheduleEvent);
        }
    }

    // Handle View in Workday button click
    handleViewInWorkday() {
        // Dispatch custom event for parent component to handle
        const viewEvent = new CustomEvent('viewworkday', {
            detail: {
                startDate: this.startDate,
                endDate: this.endDate,
                days: this.scheduledDays
            }
        });
        this.dispatchEvent(viewEvent);
    }
}
/*
 * Copyright 2022 salesforce.com, inc.
 * All Rights Reserved
 * Company Confidential
 */

import { LightningElement, api } from 'lwc';

export default class FlightDetails extends LightningElement {

   logoUrl = '/resource/partnerLogo'; // Adjust the path if needed
    textValue = 'Default Text'; // Default text

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

    connectedCallback() {
        if (this.value) {

            // this.value.updatedFlights = this.updatedValue;
            this.textValue = this.value.responses[0].responseText.replace(/<[^>]*>/g, '');
            console.log('this.textValue: ', this.textValue);
            console.log('Object.assign: ', Object.assign({}, this.textValue));
            console.log('JSON.stringify: ', JSON.stringify(this.textValue, null, 2));
        }
    }

}

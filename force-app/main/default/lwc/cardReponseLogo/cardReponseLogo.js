import { LightningElement, api } from 'lwc';

export default class CardResponseLogo extends LightningElement {
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
            this.textValue = this.value;

        }
    }
}

import { LightningElement } from 'lwc';

export default class BanquetMenuTest extends LightningElement {
    // Simple test component
    menuResponse = {
        responseType: 'UPLOAD_REQUIRED',
        message: 'Please upload a banquet menu PDF file to begin the extraction process.',
        success: true
    };
}
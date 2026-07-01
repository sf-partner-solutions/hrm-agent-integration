import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const STATIC_PREVIEW = [
    { id: 1, customer: 'TWA',    boxId: 'BX000025', boxPosition: 'A02', sampleId: 'S000440' },
    { id: 2, customer: 'TWA',    boxId: 'BX000025', boxPosition: 'A03', sampleId: 'S000441' },
    { id: 3, customer: 'TWA',    boxId: 'BX000025', boxPosition: 'A04', sampleId: 'S000442' },
    { id: 4, customer: 'TWA',    boxId: 'BX000025', boxPosition: 'A05', sampleId: 'S000443' },
    { id: 5, customer: 'TWA',    boxId: 'BX000025', boxPosition: 'A06', sampleId: 'S000444' },
    { id: 6, customer: 'Lockbox', boxId: 'BX000026', boxPosition: 'A01', sampleId: 'S000445' },
    { id: 7, customer: 'Lockbox', boxId: 'BX000026', boxPosition: 'A02', sampleId: 'S000446' },
    { id: 8, customer: 'Lockbox', boxId: 'BX000026', boxPosition: 'A03', sampleId: 'S000447' },
    { id: 9, customer: 'Lockbox', boxId: 'BX000026', boxPosition: 'A04', sampleId: 'S000448' },
    { id:10, customer: 'Lockbox', boxId: 'BX000026', boxPosition: 'A05', sampleId: 'S000449' }
];

const COLUMNS = [
    { label: 'Customer Sample Name', fieldName: 'customer' },
    { label: 'Box ID',               fieldName: 'boxId' },
    { label: 'Box Position',         fieldName: 'boxPosition' },
    { label: 'Sample ID',            fieldName: 'sampleId' }
];

export default class SampleCsvImportPreview extends LightningElement {
    rows = STATIC_PREVIEW;
    columns = COLUMNS;
    fileName = 'CSV Import.csv';
    hasFile = true; // demo: pre-loaded

    handleChooseFile() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Demo only',
            message: 'This CSV importer is a visual recreation. Use "Import Sample with AI" above for the live demo.',
            variant: 'info'
        }));
    }

    handleImport() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Looks good!',
            message: '10 rows ready to import (visual demo).',
            variant: 'success'
        }));
    }
}

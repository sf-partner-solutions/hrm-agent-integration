import LightningDatatable from 'lightning/datatable';
import picklistStatic from './picklistStatic.html';
import picklistEditable from './picklistEditable.html';

export default class CustomDataTable extends LightningDatatable {
    static customTypes = {
        picklistColumn: {
            template: picklistStatic,
            editTemplate: picklistEditable,
            standardCellLayout: true,
            typeAttributes: ['label', 'placeholder', 'options', 'value', 'context']
        }
    };
}
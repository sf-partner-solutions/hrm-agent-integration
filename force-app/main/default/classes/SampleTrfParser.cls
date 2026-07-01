/**
 * Parses the JSON returned by the Sample_TRF_Ingestion prompt template
 * and converts it into a Sample__c SObject ready for insert.
 *
 * Note: Apex identifiers cannot contain "__c". We deserialize JSON keys that
 * include the field API name (e.g. Patient_Name__c) into plain Apex properties
 * via @SerializedName-style hand parsing in JsonMapAdapter; here we use a
 * Map<String, Object> intermediate so the LWC and prompt template can speak
 * the Sample__c field API names directly.
 *
 * Modeled on BanquetMenuParser, but single-record (one TRF -> one Sample__c).
 */
public with sharing class SampleTrfParser {

    /**
     * @description Loose wrapper used over Apex bridges (LWC -> Apex).
     * The LWC sends a Map<String, Object> with keys matching Sample__c field API names.
     */
    public class SampleData {
        @AuraEnabled public Map<String, Object> fields;
    }

    public class ExtractionMetadata {
        @AuraEnabled public String form_type;
        @AuraEnabled public String extracted_date;
        @AuraEnabled public String confidence_notes;
    }

    public class TrfExtractionResponse {
        @AuraEnabled public Map<String, Object> sample;
        @AuraEnabled public ExtractionMetadata extraction_metadata;
    }

    public static TrfExtractionResponse parseTrfJSON(String jsonResponse) {
        return (TrfExtractionResponse) JSON.deserialize(jsonResponse, TrfExtractionResponse.class);
    }

    private static final Set<String> DATE_FIELDS = new Set<String>{
        'Date_of_Collection__c', 'Patient_DOB__c'
    };

    private static final Set<String> BOOLEAN_FIELDS = new Set<String>{
        'Frozen__c', 'Quality_Control_Check__c'
    };

    private static final Set<String> NUMBER_FIELDS = new Set<String>{
        'Number_of_Aliquots__c', 'Concentration__c'
    };

    private static final Set<String> ALLOWED_FIELDS = new Set<String>{
        'Customer_Sample_Name__c',
        'Sample_ID__c',
        'Sample_Type__c',
        'Frozen__c',
        'Date_of_Collection__c',
        'Number_of_Aliquots__c',
        'Current_Protocol__c',
        'Next_Protocol__c',
        'Concentration__c',
        'Quality_Control_Check__c',
        'Freezer_Refrigerator__c',
        'Drawer__c',
        'Box_ID__c',
        'Rack__c',
        'Box_Position__c',
        'Patient_Name__c',
        'Patient_DOB__c',
        'Patient_MRN__c',
        'Patient_Gender__c',
        'Ordering_Physician__c',
        'Tests_Requested__c',
        'Clinical_Notes__c',
        'Priority__c',
        'Status__c',
        'Record_Type_Label__c'
    };

    public static Sample__c toSampleRecord(Map<String, Object> data) {
        Sample__c rec = new Sample__c();
        if (data == null) return rec;

        for (String key : data.keySet()) {
            if (!ALLOWED_FIELDS.contains(key)) continue;
            Object raw = data.get(key);
            if (raw == null) continue;

            if (DATE_FIELDS.contains(key)) {
                rec.put(key, parseDate(String.valueOf(raw)));
            } else if (BOOLEAN_FIELDS.contains(key)) {
                rec.put(key, raw instanceof Boolean ? (Boolean) raw : Boolean.valueOf(String.valueOf(raw)));
            } else if (NUMBER_FIELDS.contains(key)) {
                if (raw instanceof Decimal) {
                    rec.put(key, raw);
                } else if (raw instanceof Integer || raw instanceof Long) {
                    rec.put(key, Decimal.valueOf(String.valueOf(raw)));
                } else if (raw instanceof Double) {
                    rec.put(key, Decimal.valueOf(String.valueOf(raw)));
                } else {
                    String s = String.valueOf(raw);
                    if (String.isNotBlank(s)) {
                        try { rec.put(key, Decimal.valueOf(s)); } catch (Exception ex) { /* skip */ }
                    }
                }
            } else {
                rec.put(key, String.valueOf(raw));
            }
        }

        // Defaults
        if (rec.Status__c == null) rec.Status__c = 'New';
        if (rec.Record_Type_Label__c == null) rec.Record_Type_Label__c = 'Submitted Sample';
        return rec;
    }

    /**
     * Tolerant date parser. Accepts ISO yyyy-MM-dd or M/d/yyyy.
     */
    private static Date parseDate(String s) {
        if (String.isBlank(s)) return null;
        try {
            if (s.contains('-')) {
                return Date.valueOf(s);
            }
            if (s.contains('/')) {
                List<String> parts = s.split('/');
                if (parts.size() == 3) {
                    Integer month = Integer.valueOf(parts[0]);
                    Integer day   = Integer.valueOf(parts[1]);
                    Integer year  = Integer.valueOf(parts[2]);
                    return Date.newInstance(year, month, day);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not parse date string: ' + s);
        }
        return null;
    }
}

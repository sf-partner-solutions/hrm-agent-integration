@IsTest
private class SampleTrfControllerTest {

    @IsTest
    static void createSample_insertsRecord() {
        Map<String, Object> data = new Map<String, Object>{
            'Customer_Sample_Name__c' => 'Test Patient TRF',
            'Sample_Type__c'          => 'Blood',
            'Date_of_Collection__c'   => '2026-01-15',
            'Number_of_Aliquots__c'   => 2,
            'Patient_Name__c'         => 'Test Patient',
            'Patient_DOB__c'          => '1990-06-01',
            'Patient_Gender__c'       => 'Female',
            'Priority__c'             => 'Routine'
        };

        Test.startTest();
        SampleTrfController.CreateResult res = SampleTrfController.createSample(data);
        Test.stopTest();

        System.assertEquals(true, res.success, 'Expected createSample to succeed: ' + res.errorMessage);
        System.assertNotEquals(null, res.recordId, 'Record id should be populated');

        Sample__c rec = [SELECT Id, Customer_Sample_Name__c, Sample_Type__c, Patient_Name__c, Status__c FROM Sample__c WHERE Id = :res.recordId];
        System.assertEquals('Test Patient TRF', rec.Customer_Sample_Name__c);
        System.assertEquals('Blood', rec.Sample_Type__c);
        System.assertEquals('Test Patient', rec.Patient_Name__c);
        System.assertEquals('New', rec.Status__c);
    }

    @IsTest
    static void getRecentSamples_returnsList() {
        insert new Sample__c(Customer_Sample_Name__c = 'Recent', Sample_Type__c = 'Tissue');
        Test.startTest();
        List<Sample__c> samples = SampleTrfController.getRecentSamples();
        Test.stopTest();
        System.assert(samples.size() >= 1);
    }

    @IsTest
    static void processUploadedFile_uploadRequiredBranch() {
        Test.startTest();
        SampleTrfAgentAction.SampleIngestionOutput out = SampleTrfAgentAction.processUploadedFile(null);
        Test.stopTest();
        System.assertEquals('UPLOAD_REQUIRED', out.responseType);
        System.assertEquals(true, out.success);
    }

    @IsTest
    static void parser_handlesMockJson() {
        String mockJson = '{"sample":{"Customer_Sample_Name__c":"X","Sample_Type__c":"Blood","Patient_Name__c":"Pt","Frozen__c":true,"Number_of_Aliquots__c":2},"extraction_metadata":{"form_type":"TRF","extracted_date":"2026-01-01","confidence_notes":"ok"}}';
        SampleTrfParser.TrfExtractionResponse resp = SampleTrfParser.parseTrfJSON(mockJson);
        System.assertEquals('Blood', String.valueOf(resp.sample.get('Sample_Type__c')));
        Sample__c rec = SampleTrfParser.toSampleRecord(resp.sample);
        System.assertEquals('Pt', rec.Patient_Name__c);
        System.assertEquals(true, rec.Frozen__c);
        System.assertEquals(2, rec.Number_of_Aliquots__c);
    }
}

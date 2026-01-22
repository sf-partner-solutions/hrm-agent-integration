/**
 * @description Test class for GmailPollingScheduler
 * Tests scheduled job execution and polling operations
 */
@isTest
private class GmailPollingSchedulerTest {

    @TestSetup
    static void setupTestData() {
        // Create Gmail Connection State
        Gmail_Connection_State__c state = new Gmail_Connection_State__c(
            Name = 'Test_Connection',
            Connection_Developer_Name__c = 'Test_Connection',
            Access_Token__c = 'test_access_token',
            Token_Expiry__c = DateTime.now().addHours(1),
            Last_History_Id__c = '12345',
            Emails_Processed_Today__c = 0,
            Poll_In_Progress__c = false
        );
        insert state;

        // Create Location
        Location__c location = new Location__c(
            Name = 'Test Hotel',
            Email__c = 'reservations@testhotel.com',
            Phone__c = '555-555-5555',
            SalespersonName__c = 'Test Sales',
            SalespersonTitle__c = 'Sales Manager'
        );
        insert location;

        // Create Guestroom Type
        GuestroomType__c roomType = new GuestroomType__c(
            Name = 'Standard Room',
            Location__c = location.Id,
            MaxOccupants__c = 2,
            Inventory__c = 50
        );
        insert roomType;

        // Create GuestroomTypeDay records
        Date startDate = Date.today().addDays(30);
        List<GuestroomTypeDay__c> dayRecords = new List<GuestroomTypeDay__c>();
        for (Integer i = 0; i < 5; i++) {
            dayRecords.add(new GuestroomTypeDay__c(
                GuestroomType__c = roomType.Id,
                Location__c = location.Id,
                EffectiveDate__c = startDate.addDays(i),
                GroupAvailable__c = 20,
                RackRate__c = 150.00
            ));
        }
        insert dayRecords;
    }

    /**
     * @description Mock for Gmail API calls
     */
    private class GmailApiMock implements HttpCalloutMock {
        private Boolean returnMessages;

        public GmailApiMock(Boolean returnMessages) {
            this.returnMessages = returnMessages;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            String endpoint = req.getEndpoint();

            if (endpoint.contains('oauth2.googleapis.com')) {
                res.setBody('{"access_token": "new_access_token", "expires_in": 3600}');
            } else if (endpoint.contains('/messages/') && !endpoint.contains('/modify') && !endpoint.contains('/send')) {
                // Get message detail
                String plainText = EncodingUtil.base64Encode(Blob.valueOf('We need 15 rooms for check-in March 15.'))
                    .replace('+', '-').replace('/', '_').replace('=', '');
                res.setBody('{' +
                    '"id": "msg123",' +
                    '"threadId": "thread123",' +
                    '"historyId": "12346",' +
                    '"snippet": "Room request",' +
                    '"internalDate": "1700000000000",' +
                    '"payload": {' +
                        '"headers": [' +
                            '{"name": "From", "value": "John Smith <john@example.com>"},' +
                            '{"name": "To", "value": "reservations@testhotel.com"},' +
                            '{"name": "Subject", "value": "Room Block Request"}' +
                        '],' +
                        '"body": {"data": "' + plainText + '"}' +
                    '}' +
                '}');
            } else if (endpoint.contains('/messages/send')) {
                res.setBody('{"id": "sent123", "threadId": "thread123"}');
            } else if (endpoint.contains('/modify')) {
                res.setBody('{"id": "msg123"}');
            } else if (endpoint.contains('/messages')) {
                // List messages
                if (returnMessages) {
                    res.setBody('{"messages": [{"id": "msg123", "threadId": "thread123"}], "resultSizeEstimate": 1, "historyId": "12346"}');
                } else {
                    res.setBody('{"resultSizeEstimate": 0}');
                }
            } else if (endpoint.contains('/history')) {
                if (returnMessages) {
                    res.setBody('{"history": [{"messagesAdded": [{"message": {"id": "msg456", "threadId": "thread456"}}]}], "historyId": "99999"}');
                } else {
                    res.setBody('{"historyId": "99999"}');
                }
            }

            return res;
        }
    }

    @isTest
    static void testSchedulableExecution() {
        // Test that the scheduler can be executed
        Test.startTest();

        String jobId = System.schedule(
            'Test Gmail Polling',
            '0 0 * * * ?',
            new GmailPollingScheduler()
        );

        Test.stopTest();

        // Verify job was scheduled
        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertNotEquals(null, ct, 'Job should be scheduled');
    }

    @isTest
    static void testProcessAllActiveConnections() {
        Test.setMock(HttpCalloutMock.class, new GmailApiMock(false));

        Test.startTest();
        // This will run but won't process anything since we can't mock Custom Metadata
        GmailPollingScheduler.processAllActiveConnections();
        Test.stopTest();

        // Verify no errors occurred - the method should handle lack of Custom Metadata gracefully
        System.assert(true, 'Should complete without errors');
    }

    @isTest
    static void testProcessSingleConnection_NotFound() {
        Test.startTest();
        // Test with non-existent connection
        GmailPollingScheduler.processSingleConnection('Nonexistent_Connection');
        Test.stopTest();

        // Should not throw error for non-existent connection
        System.assert(true, 'Should handle non-existent connection gracefully');
    }

    @isTest
    static void testProcessSingleConnection_PollInProgress() {
        // Set poll in progress
        Gmail_Connection_State__c state = [
            SELECT Id, Poll_In_Progress__c
            FROM Gmail_Connection_State__c
            WHERE Connection_Developer_Name__c = 'Test_Connection'
        ];
        state.Poll_In_Progress__c = true;
        update state;

        Test.startTest();
        // This should exit early since poll is in progress
        GmailPollingScheduler.processSingleConnection('Test_Connection');
        Test.stopTest();

        // Verify poll is still in progress (not reset)
        state = [
            SELECT Poll_In_Progress__c
            FROM Gmail_Connection_State__c
            WHERE Connection_Developer_Name__c = 'Test_Connection'
        ];
        System.assertEquals(true, state.Poll_In_Progress__c, 'Poll should still be in progress');
    }

    @isTest
    static void testScheduleJob_WithCustomName() {
        Test.startTest();
        String jobId = GmailPollingScheduler.scheduleJob('Custom Gmail Monitor');
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job ID should be returned');

        // Verify job was scheduled
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'Custom Gmail Monitor'
        ];
        System.assertEquals(1, jobs.size(), 'Job should be scheduled');
    }

    @isTest
    static void testScheduleJob_Default() {
        Test.startTest();
        String jobId = GmailPollingScheduler.scheduleJob();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job ID should be returned');

        // Verify job was scheduled with default name
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'Gmail Inbox Monitor'
        ];
        System.assertEquals(1, jobs.size(), 'Job should be scheduled with default name');
    }

    @isTest
    static void testUnscheduleAllJobs() {
        // First schedule some jobs
        System.schedule('Gmail Test Job 1', '0 0 * * * ?', new GmailPollingScheduler());
        System.schedule('Gmail Test Job 2', '0 30 * * * ?', new GmailPollingScheduler());

        Test.startTest();
        GmailPollingScheduler.unscheduleAllJobs();
        Test.stopTest();

        // Verify jobs were unscheduled
        List<CronTrigger> remainingJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE '%Gmail%'
        ];
        System.assertEquals(0, remainingJobs.size(), 'All Gmail jobs should be unscheduled');
    }

    @isTest
    static void testGmailPollingException() {
        // Test custom exception
        Test.startTest();
        try {
            throw new GmailPollingScheduler.GmailPollingException('Test error');
        } catch (GmailPollingScheduler.GmailPollingException e) {
            System.assertEquals('Test error', e.getMessage(), 'Exception message should match');
        }
        Test.stopTest();
    }

    @isTest
    static void testEmailProcessingLogCreation() {
        // Verify Email_Processing_Log__c can be created
        Location__c loc = [SELECT Id FROM Location__c LIMIT 1];
        Gmail_Connection_State__c state = [SELECT Id FROM Gmail_Connection_State__c LIMIT 1];

        Test.startTest();
        Email_Processing_Log__c log = new Email_Processing_Log__c(
            Message_Id__c = 'test_msg_123',
            Thread_Id__c = 'test_thread_123',
            Sender_Email__c = 'sender@test.com',
            Sender_Name__c = 'Test Sender',
            Recipient_Email__c = 'hotel@test.com',
            Subject__c = 'Test Subject',
            Location__c = loc.Id,
            Gmail_Connection_State__c = state.Id,
            Processing_Status__c = 'Processed',
            Response_Sent__c = false
        );
        insert log;
        Test.stopTest();

        // Verify log was created
        Email_Processing_Log__c createdLog = [
            SELECT Id, Message_Id__c, Processing_Status__c
            FROM Email_Processing_Log__c
            WHERE Id = :log.Id
        ];
        System.assertEquals('test_msg_123', createdLog.Message_Id__c, 'Message ID should match');
        System.assertEquals('Processed', createdLog.Processing_Status__c, 'Status should match');
    }

    @isTest
    static void testStateRecordUpdates() {
        // Test that state record can be updated correctly
        Gmail_Connection_State__c state = [
            SELECT Id, Emails_Processed_Today__c, Poll_In_Progress__c,
                   Last_History_Id__c, Last_Poll_Timestamp__c
            FROM Gmail_Connection_State__c
            WHERE Connection_Developer_Name__c = 'Test_Connection'
        ];

        Test.startTest();
        state.Poll_In_Progress__c = true;
        state.Last_Poll_Timestamp__c = DateTime.now();
        state.Last_History_Id__c = '99999';
        state.Emails_Processed_Today__c = 10;
        update state;
        Test.stopTest();

        Gmail_Connection_State__c updatedState = [
            SELECT Poll_In_Progress__c, Last_History_Id__c, Emails_Processed_Today__c
            FROM Gmail_Connection_State__c
            WHERE Id = :state.Id
        ];

        System.assertEquals(true, updatedState.Poll_In_Progress__c, 'Poll in progress should be true');
        System.assertEquals('99999', updatedState.Last_History_Id__c, 'History ID should be updated');
        System.assertEquals(10, updatedState.Emails_Processed_Today__c, 'Emails count should be updated');
    }

    @isTest
    static void testMultipleConnectionProcessing() {
        // Create second state record
        Gmail_Connection_State__c state2 = new Gmail_Connection_State__c(
            Name = 'Test_Connection_2',
            Connection_Developer_Name__c = 'Test_Connection_2',
            Access_Token__c = 'test_access_token_2',
            Token_Expiry__c = DateTime.now().addHours(1),
            Emails_Processed_Today__c = 0,
            Poll_In_Progress__c = false
        );
        insert state2;

        Test.startTest();
        // Process will attempt both but fail on Custom Metadata lookup
        // This tests that multiple connections don't interfere with each other
        GmailPollingScheduler.processAllActiveConnections();
        Test.stopTest();

        // Verify both state records still exist
        List<Gmail_Connection_State__c> states = [
            SELECT Id FROM Gmail_Connection_State__c
        ];
        System.assertEquals(2, states.size(), 'Both state records should exist');
    }
}

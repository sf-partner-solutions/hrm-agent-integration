/**
 * @description Test class for Gmail invocable action classes
 */
@isTest
private class GmailActionsTest {

    @TestSetup
    static void setupTestData() {
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

        Location__c location = new Location__c(
            Name = 'Test Hotel',
            Email__c = 'reservations@testhotel.com',
            Phone__c = '555-555-5555',
            SalespersonName__c = 'Test Sales',
            SalespersonTitle__c = 'Sales Manager'
        );
        insert location;

        GuestroomType__c roomType = new GuestroomType__c(
            Name = 'Standard Room',
            Location__c = location.Id,
            MaxOccupants__c = 2,
            Inventory__c = 50
        );
        insert roomType;

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

    private class GmailApiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            String endpoint = req.getEndpoint();

            if (endpoint.contains('/messages/send')) {
                res.setBody('{"id": "sent123", "threadId": "thread123"}');
            } else if (endpoint.contains('/messages') && endpoint.contains('/modify')) {
                res.setBody('{"id": "msg123"}');
            } else if (endpoint.contains('/messages/')) {
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
            } else if (endpoint.contains('/messages')) {
                res.setBody('{"messages": [{"id": "msg123", "threadId": "thread123"}], "resultSizeEstimate": 1}');
            } else if (endpoint.contains('/history')) {
                res.setBody('{"history": [{"messagesAdded": [{"message": {"id": "msg456", "threadId": "thread456"}}]}], "historyId": "99999"}');
            } else if (endpoint.contains('oauth2.googleapis.com')) {
                res.setBody('{"access_token": "new_token", "expires_in": 3600}');
            }

            return res;
        }
    }

    @isTest
    static void testRefreshTokenAction() {
        Test.startTest();
        GmailRefreshTokenAction.Input input = new GmailRefreshTokenAction.Input();
        input.connectionDeveloperName = 'Test_Connection';

        List<GmailRefreshTokenAction.Output> outputs =
            GmailRefreshTokenAction.execute(new List<GmailRefreshTokenAction.Input>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
    }

    @isTest
    static void testGetMessagesAction() {
        Test.setMock(HttpCalloutMock.class, new GmailApiMock());

        Test.startTest();
        GmailGetMessagesAction.Input input = new GmailGetMessagesAction.Input();
        input.accessToken = 'test_access_token';
        input.connectionDeveloperName = 'Test_Connection';
        input.useHistoryApi = false;
        input.maxMessages = 10;

        List<GmailGetMessagesAction.Output> outputs =
            GmailGetMessagesAction.execute(new List<GmailGetMessagesAction.Input>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(true, outputs[0].success, 'Should succeed');
    }

    @isTest
    static void testParseMessageAction() {
        Test.setMock(HttpCalloutMock.class, new GmailApiMock());

        Test.startTest();
        GmailParseMessageAction.Input input = new GmailParseMessageAction.Input();
        input.accessToken = 'test_access_token';
        input.messageId = 'msg123';

        List<GmailParseMessageAction.Output> outputs =
            GmailParseMessageAction.execute(new List<GmailParseMessageAction.Input>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(true, outputs[0].success, 'Should succeed');
        System.assertEquals('john@example.com', outputs[0].senderEmail, 'Sender email should be parsed');
    }

    @isTest
    static void testCheckAvailabilityAction() {
        Location__c loc = [SELECT Id FROM Location__c LIMIT 1];

        Test.startTest();
        GmailCheckAvailabilityAction.Input input = new GmailCheckAvailabilityAction.Input();
        input.locationId = loc.Id;
        input.checkInDate = Date.today().addDays(30);
        input.checkOutDate = Date.today().addDays(32);
        input.roomsRequested = 10;

        List<GmailCheckAvailabilityAction.Output> outputs =
            GmailCheckAvailabilityAction.execute(new List<GmailCheckAvailabilityAction.Input>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(true, outputs[0].success, 'Should succeed');
    }

    @isTest
    static void testSendReplyAction() {
        Test.setMock(HttpCalloutMock.class, new GmailApiMock());

        Test.startTest();
        GmailSendReplyAction.Input input = new GmailSendReplyAction.Input();
        input.accessToken = 'test_access_token';
        input.threadId = 'thread123';
        input.toEmail = 'guest@example.com';
        input.fromEmail = 'hotel@example.com';
        input.subject = 'RE: Room Request';
        input.bodyHtml = '<html><body>Thank you!</body></html>';

        List<GmailSendReplyAction.Output> outputs =
            GmailSendReplyAction.execute(new List<GmailSendReplyAction.Input>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(true, outputs[0].success, 'Should succeed');
    }

    @isTest
    static void testCreateLogAction() {
        Location__c loc = [SELECT Id FROM Location__c LIMIT 1];
        Gmail_Connection_State__c state = [SELECT Id FROM Gmail_Connection_State__c LIMIT 1];

        Test.startTest();
        GmailCreateLogAction.Input input = new GmailCreateLogAction.Input();
        input.messageId = 'msg_test_123';
        input.threadId = 'thread_test_123';
        input.senderEmail = 'sender@example.com';
        input.senderName = 'Test Sender';
        input.recipientEmail = 'hotel@example.com';
        input.subject = 'Test Subject';
        input.locationId = loc.Id;
        input.gmailConnectionStateId = state.Id;
        input.processingStatus = 'Processed';

        List<GmailCreateLogAction.Output> outputs =
            GmailCreateLogAction.execute(new List<GmailCreateLogAction.Input>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(true, outputs[0].success, 'Should succeed');
        System.assertNotEquals(null, outputs[0].logRecordId, 'Should return log ID');
    }

    @isTest
    static void testUpdateStateAction() {
        Test.startTest();
        GmailUpdateStateAction.Input input = new GmailUpdateStateAction.Input();
        input.connectionDeveloperName = 'Test_Connection';
        input.newHistoryId = '99999';
        input.emailsProcessed = 5;
        input.success = true;

        List<GmailUpdateStateAction.Output> outputs =
            GmailUpdateStateAction.execute(new List<GmailUpdateStateAction.Input>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(true, outputs[0].success, 'Should succeed');
    }

    @isTest
    static void testGenerateResponseAction() {
        Location__c loc = [SELECT Id FROM Location__c LIMIT 1];

        String bookingRequestJson = '{"checkInDate": "' + Date.today().addDays(30) + '", ' +
            '"checkOutDate": "' + Date.today().addDays(32) + '", ' +
            '"totalRoomsRequested": 10, "guestName": "John Smith"}';

        String availabilityJson = '{"isAvailable": true, "availabilityStatus": "full", ' +
            '"availableRooms": 20, "requestedRooms": 10, "numberOfNights": 2, ' +
            '"ratePerNight": 150.00, "totalEstimate": 3000.00}';

        Test.startTest();
        GmailGenerateResponseAction.Input input = new GmailGenerateResponseAction.Input();
        input.bookingRequestJson = bookingRequestJson;
        input.availabilityJson = availabilityJson;
        input.locationId = loc.Id;
        input.originalSubject = 'Room Request';
        input.senderFirstName = 'John';
        input.senderFullName = 'John Smith';

        List<GmailGenerateResponseAction.Output> outputs =
            GmailGenerateResponseAction.execute(new List<GmailGenerateResponseAction.Input>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(true, outputs[0].success, 'Should succeed');
    }

    @isTest
    static void testMarkReadAction() {
        Test.setMock(HttpCalloutMock.class, new GmailApiMock());

        Test.startTest();
        GmailMarkReadAction.Input input = new GmailMarkReadAction.Input();
        input.accessToken = 'test_access_token';
        input.messageId = 'msg123';

        List<GmailMarkReadAction.Output> outputs =
            GmailMarkReadAction.execute(new List<GmailMarkReadAction.Input>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(true, outputs[0].success, 'Should succeed');
    }
}

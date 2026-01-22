/**
 * @description Test class for GmailAPIService
 * Tests Gmail API operations with HTTP mocks
 */
@isTest
private class GmailAPIServiceTest {

    /**
     * @description Mock for successful message list response
     */
    private class ListMessagesSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"messages": [{"id": "msg123", "threadId": "thread123"}, {"id": "msg456", "threadId": "thread456"}], "resultSizeEstimate": 2}');
            return res;
        }
    }

    /**
     * @description Mock for empty message list response
     */
    private class ListMessagesEmptyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"resultSizeEstimate": 0}');
            return res;
        }
    }

    /**
     * @description Mock for failed API response
     */
    private class ApiErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(401);
            res.setBody('{"error": {"code": 401, "message": "Request had invalid authentication credentials"}}');
            return res;
        }
    }

    /**
     * @description Mock for successful message detail response
     */
    private class GetMessageSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            // Build a realistic Gmail message response
            String body = '{' +
                '"id": "msg123",' +
                '"threadId": "thread123",' +
                '"historyId": "12345",' +
                '"snippet": "Test email snippet",' +
                '"internalDate": "1700000000000",' +
                '"payload": {' +
                    '"headers": [' +
                        '{"name": "From", "value": "John Smith <john.smith@example.com>"},' +
                        '{"name": "To", "value": "reservations@hotel.com"},' +
                        '{"name": "Subject", "value": "Room Block Request"}' +
                    '],' +
                    '"body": {' +
                        '"data": "' + EncodingUtil.base64Encode(Blob.valueOf('We need 15 rooms for next week.'))
                            .replace('+', '-').replace('/', '_').replace('=', '') + '"' +
                    '}' +
                '}' +
            '}';
            res.setBody(body);
            return res;
        }
    }

    /**
     * @description Mock for multipart message response
     */
    private class GetMultipartMessageMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            String plainText = EncodingUtil.base64Encode(Blob.valueOf('Plain text body'))
                .replace('+', '-').replace('/', '_').replace('=', '');

            String body = '{' +
                '"id": "msg456",' +
                '"threadId": "thread456",' +
                '"historyId": "12346",' +
                '"snippet": "Multipart email",' +
                '"internalDate": "1700000000000",' +
                '"payload": {' +
                    '"mimeType": "multipart/alternative",' +
                    '"headers": [' +
                        '{"name": "From", "value": "Jane Doe <jane@example.com>"},' +
                        '{"name": "To", "value": "sales@hotel.com"},' +
                        '{"name": "Subject", "value": "Group Booking Inquiry"}' +
                    '],' +
                    '"body": {},' +
                    '"parts": [' +
                        '{"mimeType": "text/plain", "body": {"data": "' + plainText + '"}},' +
                        '{"mimeType": "text/html", "body": {"data": "' + plainText + '"}}' +
                    ']' +
                '}' +
            '}';
            res.setBody(body);
            return res;
        }
    }

    /**
     * @description Mock for send reply success
     */
    private class SendReplySuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"id": "sent123", "threadId": "thread123"}');
            return res;
        }
    }

    /**
     * @description Mock for send reply failure
     */
    private class SendReplyFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"error": {"message": "Invalid request"}}');
            return res;
        }
    }

    /**
     * @description Mock for mark as read success
     */
    private class MarkAsReadSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"id": "msg123"}');
            return res;
        }
    }

    /**
     * @description Mock for history list success
     */
    private class HistoryListSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{' +
                '"history": [' +
                    '{"messagesAdded": [{"message": {"id": "newmsg1", "threadId": "thread1"}}]},' +
                    '{"messagesAdded": [{"message": {"id": "newmsg2", "threadId": "thread2"}}]}' +
                '],' +
                '"historyId": "99999"' +
            '}');
            return res;
        }
    }

    /**
     * @description Mock for history ID expired
     */
    private class HistoryExpiredMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(404);
            res.setBody('{"error": {"message": "History ID not found"}}');
            return res;
        }
    }

    @isTest
    static void testListMessages_Success() {
        Test.setMock(HttpCalloutMock.class, new ListMessagesSuccessMock());

        Test.startTest();
        GmailAPIService.ListMessagesResult result = GmailAPIService.listMessages(
            'test_access_token',
            'is:unread',
            10
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed');
        System.assertEquals(2, result.messages.size(), 'Should have 2 messages');
        System.assertEquals('msg123', result.messages[0].id, 'First message ID should match');
        System.assertEquals('thread123', result.messages[0].threadId, 'First thread ID should match');
    }

    @isTest
    static void testListMessages_Empty() {
        Test.setMock(HttpCalloutMock.class, new ListMessagesEmptyMock());

        Test.startTest();
        GmailAPIService.ListMessagesResult result = GmailAPIService.listMessages(
            'test_access_token',
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed even with empty results');
        System.assertEquals(0, result.messages.size(), 'Should have 0 messages');
    }

    @isTest
    static void testListMessages_Error() {
        Test.setMock(HttpCalloutMock.class, new ApiErrorMock());

        Test.startTest();
        GmailAPIService.ListMessagesResult result = GmailAPIService.listMessages(
            'invalid_token',
            'is:unread',
            10
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail with error');
        System.assertNotEquals(null, result.errorMessage, 'Should have error message');
    }

    @isTest
    static void testGetMessage_Success() {
        Test.setMock(HttpCalloutMock.class, new GetMessageSuccessMock());

        Test.startTest();
        GmailAPIService.GmailMessageDetail detail = GmailAPIService.getMessage(
            'test_access_token',
            'msg123'
        );
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Should return message detail');
        System.assertEquals('msg123', detail.id, 'Message ID should match');
        System.assertEquals('thread123', detail.threadId, 'Thread ID should match');
        System.assertNotEquals(null, detail.headers, 'Should have headers');
        System.assertEquals('reservations@hotel.com', detail.headers.get('to'), 'To header should match');
        System.assertEquals('Room Block Request', detail.headers.get('subject'), 'Subject should match');
    }

    @isTest
    static void testGetMessage_Multipart() {
        Test.setMock(HttpCalloutMock.class, new GetMultipartMessageMock());

        Test.startTest();
        GmailAPIService.GmailMessageDetail detail = GmailAPIService.getMessage(
            'test_access_token',
            'msg456'
        );
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Should return message detail');
        System.assertNotEquals(null, detail.body, 'Should have body');
        System.assertEquals('Plain text body', detail.body, 'Body should be extracted from parts');
    }

    @isTest
    static void testGetMessage_Error() {
        Test.setMock(HttpCalloutMock.class, new ApiErrorMock());

        Test.startTest();
        GmailAPIService.GmailMessageDetail detail = GmailAPIService.getMessage(
            'invalid_token',
            'msg123'
        );
        Test.stopTest();

        System.assertEquals(null, detail, 'Should return null on error');
    }

    @isTest
    static void testSendReply_Success() {
        Test.setMock(HttpCalloutMock.class, new SendReplySuccessMock());

        Test.startTest();
        Boolean result = GmailAPIService.sendReply(
            'test_access_token',
            'thread123',
            'guest@example.com',
            'RE: Room Block Request',
            '<html><body>Thank you for your inquiry!</body></html>',
            'reservations@hotel.com'
        );
        Test.stopTest();

        System.assertEquals(true, result, 'Should send successfully');
    }

    @isTest
    static void testSendReply_Failure() {
        Test.setMock(HttpCalloutMock.class, new SendReplyFailureMock());

        Test.startTest();
        Boolean result = GmailAPIService.sendReply(
            'test_access_token',
            'thread123',
            'guest@example.com',
            'RE: Room Block Request',
            '<html><body>Thank you!</body></html>',
            'reservations@hotel.com'
        );
        Test.stopTest();

        System.assertEquals(false, result, 'Should fail');
    }

    @isTest
    static void testMarkAsRead_Success() {
        Test.setMock(HttpCalloutMock.class, new MarkAsReadSuccessMock());

        Test.startTest();
        Boolean result = GmailAPIService.markAsRead('test_access_token', 'msg123');
        Test.stopTest();

        System.assertEquals(true, result, 'Should mark as read successfully');
    }

    @isTest
    static void testMarkAsRead_Failure() {
        Test.setMock(HttpCalloutMock.class, new ApiErrorMock());

        Test.startTest();
        Boolean result = GmailAPIService.markAsRead('invalid_token', 'msg123');
        Test.stopTest();

        System.assertEquals(false, result, 'Should fail to mark as read');
    }

    @isTest
    static void testGetHistoryList_Success() {
        Test.setMock(HttpCalloutMock.class, new HistoryListSuccessMock());

        Test.startTest();
        GmailAPIService.ListMessagesResult result = GmailAPIService.getHistoryList(
            'test_access_token',
            '12345'
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed');
        System.assertEquals(2, result.messages.size(), 'Should have 2 new messages');
        System.assertEquals('99999', result.newHistoryId, 'New history ID should be returned');
    }

    @isTest
    static void testGetHistoryList_Expired() {
        Test.setMock(HttpCalloutMock.class, new HistoryExpiredMock());

        Test.startTest();
        GmailAPIService.ListMessagesResult result = GmailAPIService.getHistoryList(
            'test_access_token',
            '00001'
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail for expired history');
        System.assert(result.errorMessage.contains('expired') || result.errorMessage.contains('404'),
            'Error should indicate history expired or not found');
    }
}

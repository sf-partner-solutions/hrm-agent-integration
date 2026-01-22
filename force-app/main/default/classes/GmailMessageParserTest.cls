/**
 * @description Test class for GmailMessageParser
 * Tests email parsing utilities
 */
@isTest
private class GmailMessageParserTest {

    /**
     * @description Helper method to create a mock message detail
     */
    private static GmailAPIService.GmailMessageDetail createMockMessage(
        String fromHeader,
        String toHeader,
        String subject,
        String body
    ) {
        GmailAPIService.GmailMessageDetail detail = new GmailAPIService.GmailMessageDetail();
        detail.id = 'test123';
        detail.threadId = 'thread123';
        detail.headers = new Map<String, String>();

        if (fromHeader != null) {
            detail.headers.put('from', fromHeader);
        }
        if (toHeader != null) {
            detail.headers.put('to', toHeader);
        }
        if (subject != null) {
            detail.headers.put('subject', subject);
        }
        detail.body = body;
        detail.internalDate = DateTime.now().getTime();

        return detail;
    }

    @isTest
    static void testExtractRecipientEmail_SimpleEmail() {
        GmailAPIService.GmailMessageDetail message = createMockMessage(
            'sender@example.com',
            'reservations@hotel.com',
            'Room Request',
            'Test body'
        );

        Test.startTest();
        String recipientEmail = GmailMessageParser.extractRecipientEmail(message);
        Test.stopTest();

        System.assertEquals('reservations@hotel.com', recipientEmail, 'Should extract simple email');
    }

    @isTest
    static void testExtractRecipientEmail_WithDisplayName() {
        GmailAPIService.GmailMessageDetail message = createMockMessage(
            'sender@example.com',
            'Hotel Reservations <reservations@hotel.com>',
            'Room Request',
            'Test body'
        );

        Test.startTest();
        String recipientEmail = GmailMessageParser.extractRecipientEmail(message);
        Test.stopTest();

        System.assertEquals('reservations@hotel.com', recipientEmail, 'Should extract email from display name format');
    }

    @isTest
    static void testExtractRecipientEmail_MultipleRecipients() {
        GmailAPIService.GmailMessageDetail message = createMockMessage(
            'sender@example.com',
            'reservations@hotel.com, sales@hotel.com',
            'Room Request',
            'Test body'
        );

        Test.startTest();
        String recipientEmail = GmailMessageParser.extractRecipientEmail(message);
        Test.stopTest();

        System.assertEquals('reservations@hotel.com', recipientEmail, 'Should extract first email from multiple');
    }

    @isTest
    static void testExtractRecipientEmail_DeliveredTo() {
        GmailAPIService.GmailMessageDetail message = new GmailAPIService.GmailMessageDetail();
        message.headers = new Map<String, String>();
        message.headers.put('delivered-to', 'delivered@hotel.com');

        Test.startTest();
        String recipientEmail = GmailMessageParser.extractRecipientEmail(message);
        Test.stopTest();

        System.assertEquals('delivered@hotel.com', recipientEmail, 'Should use delivered-to as fallback');
    }

    @isTest
    static void testExtractRecipientEmail_NullMessage() {
        Test.startTest();
        String recipientEmail = GmailMessageParser.extractRecipientEmail(null);
        Test.stopTest();

        System.assertEquals(null, recipientEmail, 'Should return null for null message');
    }

    @isTest
    static void testExtractSenderInfo_WithDisplayName() {
        GmailAPIService.GmailMessageDetail message = createMockMessage(
            'John Smith <john.smith@example.com>',
            'reservations@hotel.com',
            'Room Request',
            'Test body'
        );

        Test.startTest();
        GmailMessageParser.SenderInfo senderInfo = GmailMessageParser.extractSenderInfo(message);
        Test.stopTest();

        System.assertEquals('john.smith@example.com', senderInfo.email, 'Email should be extracted');
        System.assertEquals('John Smith', senderInfo.name, 'Name should be extracted');
        System.assertEquals('John', senderInfo.firstName, 'First name should be extracted');
    }

    @isTest
    static void testExtractSenderInfo_QuotedDisplayName() {
        GmailAPIService.GmailMessageDetail message = createMockMessage(
            '"Jane Doe" <jane.doe@example.com>',
            'reservations@hotel.com',
            'Room Request',
            'Test body'
        );

        Test.startTest();
        GmailMessageParser.SenderInfo senderInfo = GmailMessageParser.extractSenderInfo(message);
        Test.stopTest();

        System.assertEquals('jane.doe@example.com', senderInfo.email, 'Email should be extracted');
        System.assertEquals('Jane Doe', senderInfo.name, 'Name should have quotes removed');
        System.assertEquals('Jane', senderInfo.firstName, 'First name should be extracted');
    }

    @isTest
    static void testExtractSenderInfo_EmailOnly() {
        GmailAPIService.GmailMessageDetail message = createMockMessage(
            'john@example.com',
            'reservations@hotel.com',
            'Room Request',
            'Test body'
        );

        Test.startTest();
        GmailMessageParser.SenderInfo senderInfo = GmailMessageParser.extractSenderInfo(message);
        Test.stopTest();

        System.assertEquals('john@example.com', senderInfo.email, 'Email should be extracted');
    }

    @isTest
    static void testExtractFirstName_SimpleFirstLast() {
        Test.startTest();
        String firstName = GmailMessageParser.extractFirstName('John Smith');
        Test.stopTest();

        System.assertEquals('John', firstName, 'Should extract first name from "First Last"');
    }

    @isTest
    static void testExtractFirstName_LastCommaFirst() {
        Test.startTest();
        String firstName = GmailMessageParser.extractFirstName('Smith, John');
        Test.stopTest();

        System.assertEquals('John', firstName, 'Should extract first name from "Last, First"');
    }

    @isTest
    static void testExtractFirstName_WithTitle() {
        Test.startTest();
        String firstName = GmailMessageParser.extractFirstName('Dr. John Smith');
        Test.stopTest();

        System.assertEquals('John', firstName, 'Should extract first name after title');
    }

    @isTest
    static void testExtractFirstName_WithCoachTitle() {
        Test.startTest();
        String firstName = GmailMessageParser.extractFirstName('Coach Mike Johnson');
        Test.stopTest();

        System.assertEquals('Mike', firstName, 'Should extract first name after Coach');
    }

    @isTest
    static void testExtractFirstName_Null() {
        Test.startTest();
        String firstName = GmailMessageParser.extractFirstName(null);
        Test.stopTest();

        System.assertEquals(null, firstName, 'Should return null for null input');
    }

    @isTest
    static void testExtractFirstName_Blank() {
        Test.startTest();
        String firstName = GmailMessageParser.extractFirstName('   ');
        Test.stopTest();

        System.assertEquals(null, firstName, 'Should return null for blank input');
    }

    @isTest
    static void testGetSubject() {
        GmailAPIService.GmailMessageDetail message = createMockMessage(
            'sender@example.com',
            'reservations@hotel.com',
            'Room Block Request for ABC Corp',
            'Test body'
        );

        Test.startTest();
        String subject = GmailMessageParser.getSubject(message);
        Test.stopTest();

        System.assertEquals('Room Block Request for ABC Corp', subject, 'Subject should match');
    }

    @isTest
    static void testGetEmailBody() {
        GmailAPIService.GmailMessageDetail message = createMockMessage(
            'sender@example.com',
            'reservations@hotel.com',
            'Room Request',
            'We need 15 rooms for next week.'
        );

        Test.startTest();
        String body = GmailMessageParser.getEmailBody(message);
        Test.stopTest();

        System.assertEquals('We need 15 rooms for next week.', body, 'Body should match');
    }

    @isTest
    static void testGetMessageDate() {
        GmailAPIService.GmailMessageDetail message = new GmailAPIService.GmailMessageDetail();
        message.internalDate = 1700000000000L;

        Test.startTest();
        DateTime messageDate = GmailMessageParser.getMessageDate(message);
        Test.stopTest();

        System.assertNotEquals(null, messageDate, 'Should return a date');
    }

    @isTest
    static void testIsLikelyBookingRequest_ValidRequest() {
        Test.startTest();
        Boolean isBooking = GmailMessageParser.isLikelyBookingRequest(
            'Room Block Request',
            'We need 15 rooms for our team for check-in on March 15.'
        );
        Test.stopTest();

        System.assertEquals(true, isBooking, 'Should identify as booking request');
    }

    @isTest
    static void testIsLikelyBookingRequest_MultipleKeywords() {
        Test.startTest();
        Boolean isBooking = GmailMessageParser.isLikelyBookingRequest(
            'Group Reservation Inquiry',
            'Looking for availability for 20 guests, 10 rooms for 3 nights.'
        );
        Test.stopTest();

        System.assertEquals(true, isBooking, 'Should identify as booking request with multiple keywords');
    }

    @isTest
    static void testIsLikelyBookingRequest_Spam() {
        Test.startTest();
        Boolean isBooking = GmailMessageParser.isLikelyBookingRequest(
            'Special Offer - Unsubscribe',
            'Click here to unsubscribe from our mailing list.'
        );
        Test.stopTest();

        System.assertEquals(false, isBooking, 'Should identify spam as non-booking');
    }

    @isTest
    static void testIsLikelyBookingRequest_OutOfOffice() {
        Test.startTest();
        Boolean isBooking = GmailMessageParser.isLikelyBookingRequest(
            'Out of Office: Re: Room Request',
            'I am currently out of office and will return on Monday. This is an automatic reply.'
        );
        Test.stopTest();

        System.assertEquals(false, isBooking, 'Should identify out of office as non-booking');
    }

    @isTest
    static void testIsLikelyBookingRequest_BlankContent() {
        Test.startTest();
        Boolean isBooking = GmailMessageParser.isLikelyBookingRequest(null, null);
        Test.stopTest();

        System.assertEquals(false, isBooking, 'Should return false for blank content');
    }

    @isTest
    static void testCreateReplySubject_NoPrefix() {
        Test.startTest();
        String replySubject = GmailMessageParser.createReplySubject('Room Block Request');
        Test.stopTest();

        System.assertEquals('RE: Room Block Request', replySubject, 'Should add RE: prefix');
    }

    @isTest
    static void testCreateReplySubject_AlreadyHasRE() {
        Test.startTest();
        String replySubject = GmailMessageParser.createReplySubject('RE: Room Block Request');
        Test.stopTest();

        System.assertEquals('RE: Room Block Request', replySubject, 'Should not double RE: prefix');
    }

    @isTest
    static void testCreateReplySubject_HasReLowercase() {
        Test.startTest();
        String replySubject = GmailMessageParser.createReplySubject('Re: Room Block Request');
        Test.stopTest();

        System.assertEquals('Re: Room Block Request', replySubject, 'Should not add if already has Re:');
    }

    @isTest
    static void testCreateReplySubject_Blank() {
        Test.startTest();
        String replySubject = GmailMessageParser.createReplySubject(null);
        Test.stopTest();

        System.assertEquals('RE: Room Reservation Request', replySubject, 'Should use default subject for blank');
    }
}

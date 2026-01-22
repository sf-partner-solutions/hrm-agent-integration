/**
 * @description Test class for BookingResponseService
 * Tests response email generation
 */
@isTest
private class BookingResponseServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create test Location
        Location__c location = new Location__c(
            Name = 'Grand Hotel Miami',
            Email__c = 'reservations@grandhotelmiami.com',
            Phone__c = '305-555-1234',
            SalespersonName__c = 'Maria Rodriguez',
            SalespersonTitle__c = 'Group Sales Manager'
        );
        insert location;
    }

    private static LocationEmailMappingService.LocationLookupResult getTestLocation() {
        Location__c loc = [SELECT Id FROM Location__c LIMIT 1];
        return LocationEmailMappingService.findLocationById(loc.Id);
    }

    private static BookingResponseService.BookingRequest createTestRequest() {
        BookingResponseService.BookingRequest request = new BookingResponseService.BookingRequest();
        request.checkInDate = Date.today().addDays(30);
        request.checkOutDate = Date.today().addDays(33);
        request.numberOfRooms = 15;
        request.numberOfNights = 3;
        request.guestName = 'John Smith';
        request.guestFirstName = 'John';
        request.organizationName = 'ABC Soccer Club';
        request.originalSubject = 'Room Block Request for Tournament';
        return request;
    }

    @isTest
    static void testGenerateResponse_FullAvailability() {
        BookingResponseService.BookingRequest request = createTestRequest();

        RoomInventoryService.AvailabilityResult availability = new RoomInventoryService.AvailabilityResult();
        availability.isAvailable = true;
        availability.availabilityStatus = 'full';
        availability.availableRooms = 15;
        availability.requestedRooms = 15;
        availability.numberOfNights = 3;
        availability.ratePerNight = 150.00;
        availability.totalEstimate = 6750.00;

        LocationEmailMappingService.LocationLookupResult location = getTestLocation();

        Test.startTest();
        BookingResponseService.ResponseResult result =
            BookingResponseService.generateResponse(request, availability, location);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Response generation should succeed');
        System.assertNotEquals(null, result.emailSubject, 'Subject should be set');
        System.assert(result.emailSubject.contains('RE:'), 'Subject should have RE: prefix');
        System.assertNotEquals(null, result.emailBodyHtml, 'HTML body should be set');
        System.assert(result.emailBodyHtml.contains('John'), 'HTML should contain first name');
        System.assert(result.emailBodyHtml.contains('Grand Hotel Miami'), 'HTML should contain hotel name');
        System.assert(result.emailBodyHtml.contains('15'), 'HTML should contain room count');
        System.assert(result.emailBodyHtml.contains('Maria Rodriguez'), 'HTML should contain salesperson name');
        System.assertNotEquals(null, result.emailBodyPlain, 'Plain text body should be set');
    }

    @isTest
    static void testGenerateResponse_PartialAvailability() {
        BookingResponseService.BookingRequest request = createTestRequest();
        request.numberOfRooms = 20;

        RoomInventoryService.AvailabilityResult availability = new RoomInventoryService.AvailabilityResult();
        availability.isAvailable = false;
        availability.availabilityStatus = 'partial';
        availability.availableRooms = 12;
        availability.requestedRooms = 20;
        availability.numberOfNights = 3;
        availability.ratePerNight = 150.00;
        availability.totalEstimate = 5400.00;

        LocationEmailMappingService.LocationLookupResult location = getTestLocation();

        Test.startTest();
        BookingResponseService.ResponseResult result =
            BookingResponseService.generateResponse(request, availability, location);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Response generation should succeed');
        System.assert(result.emailBodyHtml.contains('12'), 'HTML should contain available rooms');
        System.assert(result.emailBodyHtml.contains('20'), 'HTML should contain requested rooms');
        System.assert(result.emailBodyHtml.contains('waitlist') ||
                     result.emailBodyHtml.contains('alternative'),
            'HTML should offer alternatives');
    }

    @isTest
    static void testGenerateResponse_NoAvailability() {
        BookingResponseService.BookingRequest request = createTestRequest();

        RoomInventoryService.AvailabilityResult availability = new RoomInventoryService.AvailabilityResult();
        availability.isAvailable = false;
        availability.availabilityStatus = 'none';
        availability.availableRooms = 0;
        availability.requestedRooms = 15;

        LocationEmailMappingService.LocationLookupResult location = getTestLocation();

        Test.startTest();
        BookingResponseService.ResponseResult result =
            BookingResponseService.generateResponse(request, availability, location);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Response generation should succeed');
        System.assert(result.emailBodyHtml.contains('sorry') ||
                     result.emailBodyHtml.contains('fully committed'),
            'HTML should express apology');
        System.assert(result.emailBodyHtml.contains('alternative') ||
                     result.emailBodyHtml.contains('waitlist') ||
                     result.emailBodyHtml.contains('Different'),
            'HTML should offer alternatives');
    }

    @isTest
    static void testGenerateResponse_NoOrganization() {
        BookingResponseService.BookingRequest request = createTestRequest();
        request.organizationName = null;

        RoomInventoryService.AvailabilityResult availability = new RoomInventoryService.AvailabilityResult();
        availability.isAvailable = true;
        availability.availabilityStatus = 'full';
        availability.availableRooms = 15;
        availability.numberOfNights = 3;
        availability.ratePerNight = 150.00;
        availability.totalEstimate = 6750.00;

        LocationEmailMappingService.LocationLookupResult location = getTestLocation();

        Test.startTest();
        BookingResponseService.ResponseResult result =
            BookingResponseService.generateResponse(request, availability, location);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed without organization');
    }

    @isTest
    static void testGenerateResponse_NoFirstName() {
        BookingResponseService.BookingRequest request = createTestRequest();
        request.guestFirstName = null;

        RoomInventoryService.AvailabilityResult availability = new RoomInventoryService.AvailabilityResult();
        availability.isAvailable = true;
        availability.availabilityStatus = 'full';
        availability.availableRooms = 15;
        availability.numberOfNights = 3;
        availability.ratePerNight = 150.00;
        availability.totalEstimate = 6750.00;

        LocationEmailMappingService.LocationLookupResult location = getTestLocation();

        Test.startTest();
        BookingResponseService.ResponseResult result =
            BookingResponseService.generateResponse(request, availability, location);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Should succeed without first name');
        System.assert(result.emailBodyHtml.contains('there'), 'Should use fallback greeting');
    }

    @isTest
    static void testParseBookingRequestFromJson_Valid() {
        String jsonString = '{"checkInDate": "2025-03-15", "checkOutDate": "2025-03-18", ' +
            '"totalRoomsRequested": 15, "numberOfNights": 3, "guestName": "John Smith", ' +
            '"organizationName": "ABC Corp", "roomTypePreference": "Standard King"}';

        Test.startTest();
        BookingResponseService.BookingRequest request =
            BookingResponseService.parseBookingRequestFromJson(jsonString);
        Test.stopTest();

        System.assertEquals(Date.valueOf('2025-03-15'), request.checkInDate, 'Check-in date should match');
        System.assertEquals(Date.valueOf('2025-03-18'), request.checkOutDate, 'Check-out date should match');
        System.assertEquals(15, request.numberOfRooms, 'Room count should match');
        System.assertEquals('John Smith', request.guestName, 'Guest name should match');
        System.assertEquals('John', request.guestFirstName, 'First name should be extracted');
        System.assertEquals('ABC Corp', request.organizationName, 'Organization should match');
    }

    @isTest
    static void testParseBookingRequestFromJson_Partial() {
        String jsonString = '{"checkInDate": "2025-03-15", "totalRoomsRequested": 10}';

        Test.startTest();
        BookingResponseService.BookingRequest request =
            BookingResponseService.parseBookingRequestFromJson(jsonString);
        Test.stopTest();

        System.assertEquals(Date.valueOf('2025-03-15'), request.checkInDate, 'Check-in date should match');
        System.assertEquals(10, request.numberOfRooms, 'Room count should match');
        System.assertEquals(null, request.checkOutDate, 'Missing fields should be null');
    }

    @isTest
    static void testParseBookingRequestFromJson_Blank() {
        Test.startTest();
        BookingResponseService.BookingRequest request =
            BookingResponseService.parseBookingRequestFromJson('');
        Test.stopTest();

        System.assertNotEquals(null, request, 'Should return empty request object');
        System.assertEquals(null, request.checkInDate, 'Fields should be null');
    }

    @isTest
    static void testParseBookingRequestFromJson_Null() {
        Test.startTest();
        BookingResponseService.BookingRequest request =
            BookingResponseService.parseBookingRequestFromJson(null);
        Test.stopTest();

        System.assertNotEquals(null, request, 'Should return empty request object');
    }

    @isTest
    static void testParseBookingRequestFromJson_Invalid() {
        Test.startTest();
        BookingResponseService.BookingRequest request =
            BookingResponseService.parseBookingRequestFromJson('not valid json {');
        Test.stopTest();

        System.assertNotEquals(null, request, 'Should return empty request on invalid JSON');
    }

    @isTest
    static void testEmailSubjectCreation() {
        BookingResponseService.BookingRequest request = createTestRequest();
        request.originalSubject = 'Room Block Request';

        RoomInventoryService.AvailabilityResult availability = new RoomInventoryService.AvailabilityResult();
        availability.availabilityStatus = 'full';
        availability.availableRooms = 15;
        availability.numberOfNights = 3;
        availability.ratePerNight = 150.00;
        availability.totalEstimate = 6750.00;

        LocationEmailMappingService.LocationLookupResult location = getTestLocation();

        Test.startTest();
        BookingResponseService.ResponseResult result =
            BookingResponseService.generateResponse(request, availability, location);
        Test.stopTest();

        System.assertEquals('RE: Room Block Request', result.emailSubject, 'Subject should have RE: prefix');
    }

    @isTest
    static void testPlainTextGeneration() {
        BookingResponseService.BookingRequest request = createTestRequest();

        RoomInventoryService.AvailabilityResult availability = new RoomInventoryService.AvailabilityResult();
        availability.availabilityStatus = 'full';
        availability.availableRooms = 15;
        availability.numberOfNights = 3;
        availability.ratePerNight = 150.00;
        availability.totalEstimate = 6750.00;

        LocationEmailMappingService.LocationLookupResult location = getTestLocation();

        Test.startTest();
        BookingResponseService.ResponseResult result =
            BookingResponseService.generateResponse(request, availability, location);
        Test.stopTest();

        System.assertNotEquals(null, result.emailBodyPlain, 'Plain text should be generated');
        System.assertEquals(false, result.emailBodyPlain.contains('<html>'), 'Plain text should not contain HTML');
        System.assertEquals(false, result.emailBodyPlain.contains('<p>'), 'Plain text should not contain HTML tags');
    }
}

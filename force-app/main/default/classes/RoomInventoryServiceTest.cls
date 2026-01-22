/**
 * @description Test class for RoomInventoryService
 * Tests room availability checking
 */
@isTest
private class RoomInventoryServiceTest {

    private static Id testLocationId;
    private static Id testGuestroomTypeId;

    @TestSetup
    static void setupTestData() {
        // Create test Location
        Location__c location = new Location__c(
            Name = 'Test Hotel',
            Email__c = 'test@testhotel.com',
            Phone__c = '555-555-5555'
        );
        insert location;

        // Create test Guestroom Types
        GuestroomType__c kingRoom = new GuestroomType__c(
            Name = 'Standard King',
            Location__c = location.Id,
            MaxOccupants__c = 2,
            Inventory__c = 50
        );

        GuestroomType__c queenRoom = new GuestroomType__c(
            Name = 'Double Queen',
            Location__c = location.Id,
            MaxOccupants__c = 4,
            Inventory__c = 30
        );

        insert new List<GuestroomType__c>{ kingRoom, queenRoom };

        // Create Guestroom Type Day records for testing
        Date startDate = Date.today().addDays(30);
        List<GuestroomTypeDay__c> dayRecords = new List<GuestroomTypeDay__c>();

        for (Integer i = 0; i < 5; i++) {
            // King room inventory
            dayRecords.add(new GuestroomTypeDay__c(
                GuestroomType__c = kingRoom.Id,
                Location__c = location.Id,
                EffectiveDate__c = startDate.addDays(i),
                GroupAvailable__c = i == 2 ? 8 : 20, // Constraint on day 3
                RackRate__c = 150.00
            ));

            // Queen room inventory
            dayRecords.add(new GuestroomTypeDay__c(
                GuestroomType__c = queenRoom.Id,
                Location__c = location.Id,
                EffectiveDate__c = startDate.addDays(i),
                GroupAvailable__c = i == 2 ? 5 : 15, // Constraint on day 3
                RackRate__c = 175.00
            ));
        }

        insert dayRecords;
    }

    private static Location__c getTestLocation() {
        return [SELECT Id FROM Location__c WHERE Name = 'Test Hotel' LIMIT 1];
    }

    @isTest
    static void testCheckAvailability_FullAvailability() {
        Location__c loc = getTestLocation();
        Date checkIn = Date.today().addDays(30);
        Date checkOut = Date.today().addDays(32); // 2 nights

        Test.startTest();
        RoomInventoryService.AvailabilityResult result =
            RoomInventoryService.checkAvailability(loc.Id, checkIn, checkOut, 10, null);
        Test.stopTest();

        System.assertEquals('full', result.availabilityStatus, 'Should have full availability');
        System.assertEquals(true, result.isAvailable, 'Should be available');
        System.assert(result.availableRooms >= 10, 'Should have at least 10 rooms available');
        System.assertEquals(2, result.numberOfNights, 'Should be 2 nights');
        System.assert(result.ratePerNight > 0, 'Rate should be set');
        System.assert(result.totalEstimate > 0, 'Total estimate should be calculated');
    }

    @isTest
    static void testCheckAvailability_PartialAvailability() {
        Location__c loc = getTestLocation();
        Date checkIn = Date.today().addDays(32); // Day with constraint
        Date checkOut = Date.today().addDays(33);

        Test.startTest();
        RoomInventoryService.AvailabilityResult result =
            RoomInventoryService.checkAvailability(loc.Id, checkIn, checkOut, 20, null);
        Test.stopTest();

        System.assertEquals('partial', result.availabilityStatus, 'Should have partial availability');
        System.assertEquals(false, result.isAvailable, 'Should not be fully available');
        System.assert(result.availableRooms < 20, 'Should have fewer than requested rooms');
        System.assert(result.availableRooms > 0, 'Should have some availability');
    }

    @isTest
    static void testCheckAvailability_NoAvailability() {
        Location__c loc = getTestLocation();
        Date checkIn = Date.today().addDays(100); // No inventory records
        Date checkOut = Date.today().addDays(101);

        Test.startTest();
        RoomInventoryService.AvailabilityResult result =
            RoomInventoryService.checkAvailability(loc.Id, checkIn, checkOut, 10, null);
        Test.stopTest();

        System.assertEquals('none', result.availabilityStatus, 'Should have no availability');
        System.assertEquals(false, result.isAvailable, 'Should not be available');
        System.assertEquals(0, result.availableRooms, 'Should have 0 rooms');
    }

    @isTest
    static void testCheckAvailability_FilterByRoomType() {
        Location__c loc = getTestLocation();
        Date checkIn = Date.today().addDays(30);
        Date checkOut = Date.today().addDays(31);

        Test.startTest();
        RoomInventoryService.AvailabilityResult result =
            RoomInventoryService.checkAvailability(loc.Id, checkIn, checkOut, 5, 'Standard King');
        Test.stopTest();

        System.assertEquals('full', result.availabilityStatus, 'Should have full availability for room type');
        System.assert(result.availableRooms >= 5, 'Should have at least 5 King rooms');
    }

    @isTest
    static void testCheckAvailability_AnyRoomType() {
        Location__c loc = getTestLocation();
        Date checkIn = Date.today().addDays(30);
        Date checkOut = Date.today().addDays(31);

        Test.startTest();
        RoomInventoryService.AvailabilityResult result =
            RoomInventoryService.checkAvailability(loc.Id, checkIn, checkOut, 10, 'Any');
        Test.stopTest();

        System.assertEquals('full', result.availabilityStatus, 'Should have full availability');
        System.assert(result.availableRooms >= 10, 'Should have availability across all types');
    }

    @isTest
    static void testCheckAvailability_InvalidLocationId() {
        Test.startTest();
        RoomInventoryService.AvailabilityResult result =
            RoomInventoryService.checkAvailability(null, Date.today(), Date.today().addDays(1), 10, null);
        Test.stopTest();

        System.assertNotEquals(null, result.errorMessage, 'Should have error message');
        System.assert(result.errorMessage.contains('Location'), 'Error should mention Location');
    }

    @isTest
    static void testCheckAvailability_InvalidDates() {
        Location__c loc = getTestLocation();

        Test.startTest();
        RoomInventoryService.AvailabilityResult result =
            RoomInventoryService.checkAvailability(loc.Id, null, null, 10, null);
        Test.stopTest();

        System.assertNotEquals(null, result.errorMessage, 'Should have error message');
        System.assert(result.errorMessage.contains('date'), 'Error should mention dates');
    }

    @isTest
    static void testCheckAvailability_CheckOutBeforeCheckIn() {
        Location__c loc = getTestLocation();
        Date checkIn = Date.today().addDays(35);
        Date checkOut = Date.today().addDays(30); // Before check-in

        Test.startTest();
        RoomInventoryService.AvailabilityResult result =
            RoomInventoryService.checkAvailability(loc.Id, checkIn, checkOut, 10, null);
        Test.stopTest();

        System.assertNotEquals(null, result.errorMessage, 'Should have error message');
        System.assert(result.errorMessage.contains('after'), 'Error should mention checkout after checkin');
    }

    @isTest
    static void testCheckAvailability_InvalidRooms() {
        Location__c loc = getTestLocation();
        Date checkIn = Date.today().addDays(30);
        Date checkOut = Date.today().addDays(31);

        Test.startTest();
        RoomInventoryService.AvailabilityResult result =
            RoomInventoryService.checkAvailability(loc.Id, checkIn, checkOut, 0, null);
        Test.stopTest();

        System.assertNotEquals(null, result.errorMessage, 'Should have error message');
        System.assert(result.errorMessage.contains('greater than 0'), 'Error should mention rooms > 0');
    }

    @isTest
    static void testToJson() {
        RoomInventoryService.AvailabilityResult result = new RoomInventoryService.AvailabilityResult();
        result.isAvailable = true;
        result.availabilityStatus = 'full';
        result.availableRooms = 10;
        result.requestedRooms = 10;

        Test.startTest();
        String json = RoomInventoryService.toJson(result);
        Test.stopTest();

        System.assertNotEquals(null, json, 'JSON should not be null');
        System.assert(json.contains('full'), 'JSON should contain status');
        System.assert(json.contains('10'), 'JSON should contain room counts');
    }

    @isTest
    static void testGetSummary_FullAvailability() {
        RoomInventoryService.AvailabilityResult result = new RoomInventoryService.AvailabilityResult();
        result.availabilityStatus = 'full';
        result.availableRooms = 15;
        result.numberOfNights = 3;
        result.ratePerNight = 150.00;
        result.totalEstimate = 6750.00;

        Test.startTest();
        String summary = RoomInventoryService.getSummary(result);
        Test.stopTest();

        System.assert(summary.contains('Full availability'), 'Summary should indicate full availability');
        System.assert(summary.contains('15'), 'Summary should contain room count');
    }

    @isTest
    static void testGetSummary_PartialAvailability() {
        RoomInventoryService.AvailabilityResult result = new RoomInventoryService.AvailabilityResult();
        result.availabilityStatus = 'partial';
        result.availableRooms = 8;
        result.requestedRooms = 15;
        result.constrainingDate = '2025-03-15';

        Test.startTest();
        String summary = RoomInventoryService.getSummary(result);
        Test.stopTest();

        System.assert(summary.contains('Partial'), 'Summary should indicate partial availability');
        System.assert(summary.contains('8'), 'Summary should contain available count');
        System.assert(summary.contains('15'), 'Summary should contain requested count');
    }

    @isTest
    static void testGetSummary_NoAvailability() {
        RoomInventoryService.AvailabilityResult result = new RoomInventoryService.AvailabilityResult();
        result.availabilityStatus = 'none';

        Test.startTest();
        String summary = RoomInventoryService.getSummary(result);
        Test.stopTest();

        System.assert(summary.contains('No availability'), 'Summary should indicate no availability');
    }

    @isTest
    static void testGetSummary_WithError() {
        RoomInventoryService.AvailabilityResult result = new RoomInventoryService.AvailabilityResult();
        result.errorMessage = 'Test error';

        Test.startTest();
        String summary = RoomInventoryService.getSummary(result);
        Test.stopTest();

        System.assert(summary.contains('Error'), 'Summary should contain error');
        System.assert(summary.contains('Test error'), 'Summary should contain error message');
    }

    @isTest
    static void testGetSummary_Null() {
        Test.startTest();
        String summary = RoomInventoryService.getSummary(null);
        Test.stopTest();

        System.assert(summary.contains('Unable'), 'Summary should indicate unable to check');
    }

    @isTest
    static void testDateBreakdown() {
        Location__c loc = getTestLocation();
        Date checkIn = Date.today().addDays(30);
        Date checkOut = Date.today().addDays(33); // 3 nights

        Test.startTest();
        RoomInventoryService.AvailabilityResult result =
            RoomInventoryService.checkAvailability(loc.Id, checkIn, checkOut, 5, null);
        Test.stopTest();

        System.assertEquals(3, result.dateBreakdown.size(), 'Should have 3 date breakdown entries');
        for (RoomInventoryService.DateAvailability da : result.dateBreakdown) {
            System.assertNotEquals(null, da.inventoryDate, 'Date should be set');
            System.assertNotEquals(null, da.available, 'Available count should be set');
        }
    }
}

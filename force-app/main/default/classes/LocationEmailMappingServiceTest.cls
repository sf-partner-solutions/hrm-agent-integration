/**
 * @description Test class for LocationEmailMappingService
 * Tests location lookup by email and ID
 */
@isTest
private class LocationEmailMappingServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create test Location records
        Location__c location1 = new Location__c(
            Name = 'Grand Hotel Miami',
            Email__c = 'reservations@grandhotelmiami.com',
            Phone__c = '305-555-1234',
            AddressLine1__c = '100 Ocean Drive',
            City__c = 'Miami',
            StateProvince__c = 'FL',
            PostalCode__c = '33139',
            SalespersonName__c = 'Maria Rodriguez',
            SalespersonTitle__c = 'Group Sales Manager'
        );

        Location__c location2 = new Location__c(
            Name = 'Mountain View Lodge',
            Email__c = 'bookings@mountainviewlodge.com',
            Phone__c = '970-555-5678'
        );

        insert new List<Location__c>{ location1, location2 };
    }

    @isTest
    static void testFindLocationByEmail_Found() {
        Test.startTest();
        LocationEmailMappingService.LocationLookupResult result =
            LocationEmailMappingService.findLocationByEmail('reservations@grandhotelmiami.com');
        Test.stopTest();

        System.assertEquals(true, result.found, 'Location should be found');
        System.assertEquals('Grand Hotel Miami', result.locationName, 'Name should match');
        System.assertEquals('reservations@grandhotelmiami.com', result.email, 'Email should match');
        System.assertEquals('305-555-1234', result.phone, 'Phone should match');
        System.assertEquals('Miami', result.city, 'City should match');
        System.assertEquals('FL', result.stateProvince, 'State should match');
        System.assertEquals('Maria Rodriguez', result.salespersonName, 'Salesperson name should match');
        System.assertEquals('Group Sales Manager', result.salespersonTitle, 'Title should match');
    }

    @isTest
    static void testFindLocationByEmail_CaseInsensitive() {
        Test.startTest();
        LocationEmailMappingService.LocationLookupResult result =
            LocationEmailMappingService.findLocationByEmail('RESERVATIONS@GRANDHOTELMIAMI.COM');
        Test.stopTest();

        System.assertEquals(true, result.found, 'Location should be found (case insensitive)');
        System.assertEquals('Grand Hotel Miami', result.locationName, 'Name should match');
    }

    @isTest
    static void testFindLocationByEmail_WithWhitespace() {
        Test.startTest();
        LocationEmailMappingService.LocationLookupResult result =
            LocationEmailMappingService.findLocationByEmail('  reservations@grandhotelmiami.com  ');
        Test.stopTest();

        System.assertEquals(true, result.found, 'Location should be found (trimmed)');
    }

    @isTest
    static void testFindLocationByEmail_NotFound() {
        Test.startTest();
        LocationEmailMappingService.LocationLookupResult result =
            LocationEmailMappingService.findLocationByEmail('nonexistent@hotel.com');
        Test.stopTest();

        System.assertEquals(false, result.found, 'Location should not be found');
        System.assertEquals(null, result.locationId, 'Location ID should be null');
    }

    @isTest
    static void testFindLocationByEmail_Null() {
        Test.startTest();
        LocationEmailMappingService.LocationLookupResult result =
            LocationEmailMappingService.findLocationByEmail(null);
        Test.stopTest();

        System.assertEquals(false, result.found, 'Should return not found for null email');
    }

    @isTest
    static void testFindLocationByEmail_Blank() {
        Test.startTest();
        LocationEmailMappingService.LocationLookupResult result =
            LocationEmailMappingService.findLocationByEmail('   ');
        Test.stopTest();

        System.assertEquals(false, result.found, 'Should return not found for blank email');
    }

    @isTest
    static void testFindLocationById_Found() {
        Location__c loc = [SELECT Id FROM Location__c WHERE Name = 'Grand Hotel Miami' LIMIT 1];

        Test.startTest();
        LocationEmailMappingService.LocationLookupResult result =
            LocationEmailMappingService.findLocationById(loc.Id);
        Test.stopTest();

        System.assertEquals(true, result.found, 'Location should be found');
        System.assertEquals('Grand Hotel Miami', result.locationName, 'Name should match');
    }

    @isTest
    static void testFindLocationById_NotFound() {
        Test.startTest();
        // Use a fake but valid-looking ID
        LocationEmailMappingService.LocationLookupResult result =
            LocationEmailMappingService.findLocationById('001000000000000AAA');
        Test.stopTest();

        System.assertEquals(false, result.found, 'Location should not be found');
    }

    @isTest
    static void testFindLocationById_Null() {
        Test.startTest();
        LocationEmailMappingService.LocationLookupResult result =
            LocationEmailMappingService.findLocationById(null);
        Test.stopTest();

        System.assertEquals(false, result.found, 'Should return not found for null ID');
    }

    @isTest
    static void testGetFormattedAddress_FullAddress() {
        LocationEmailMappingService.LocationLookupResult result =
            new LocationEmailMappingService.LocationLookupResult();
        result.found = true;
        result.address = '100 Ocean Drive';
        result.city = 'Miami';
        result.stateProvince = 'FL';
        result.postalCode = '33139';

        Test.startTest();
        String formatted = LocationEmailMappingService.getFormattedAddress(result);
        Test.stopTest();

        System.assert(formatted.contains('100 Ocean Drive'), 'Should contain address');
        System.assert(formatted.contains('Miami'), 'Should contain city');
        System.assert(formatted.contains('FL'), 'Should contain state');
        System.assert(formatted.contains('33139'), 'Should contain postal code');
    }

    @isTest
    static void testGetFormattedAddress_PartialAddress() {
        LocationEmailMappingService.LocationLookupResult result =
            new LocationEmailMappingService.LocationLookupResult();
        result.found = true;
        result.city = 'Denver';
        result.stateProvince = 'CO';

        Test.startTest();
        String formatted = LocationEmailMappingService.getFormattedAddress(result);
        Test.stopTest();

        System.assert(formatted.contains('Denver'), 'Should contain city');
        System.assert(formatted.contains('CO'), 'Should contain state');
    }

    @isTest
    static void testGetFormattedAddress_NotFound() {
        LocationEmailMappingService.LocationLookupResult result =
            new LocationEmailMappingService.LocationLookupResult();
        result.found = false;

        Test.startTest();
        String formatted = LocationEmailMappingService.getFormattedAddress(result);
        Test.stopTest();

        System.assertEquals(null, formatted, 'Should return null for not found');
    }

    @isTest
    static void testGetFormattedAddress_Null() {
        Test.startTest();
        String formatted = LocationEmailMappingService.getFormattedAddress(null);
        Test.stopTest();

        System.assertEquals(null, formatted, 'Should return null for null input');
    }

    @isTest
    static void testGetSalespersonName_WithValue() {
        LocationEmailMappingService.LocationLookupResult result =
            new LocationEmailMappingService.LocationLookupResult();
        result.found = true;
        result.salespersonName = 'John Smith';

        Test.startTest();
        String name = LocationEmailMappingService.getSalespersonName(result);
        Test.stopTest();

        System.assertEquals('John Smith', name, 'Should return actual name');
    }

    @isTest
    static void testGetSalespersonName_Default() {
        LocationEmailMappingService.LocationLookupResult result =
            new LocationEmailMappingService.LocationLookupResult();
        result.found = true;

        Test.startTest();
        String name = LocationEmailMappingService.getSalespersonName(result);
        Test.stopTest();

        System.assertEquals('Reservations Team', name, 'Should return default name');
    }

    @isTest
    static void testGetSalespersonName_Null() {
        Test.startTest();
        String name = LocationEmailMappingService.getSalespersonName(null);
        Test.stopTest();

        System.assertEquals('Reservations Team', name, 'Should return default for null');
    }

    @isTest
    static void testGetSalespersonTitle_WithValue() {
        LocationEmailMappingService.LocationLookupResult result =
            new LocationEmailMappingService.LocationLookupResult();
        result.found = true;
        result.salespersonTitle = 'Director of Sales';

        Test.startTest();
        String title = LocationEmailMappingService.getSalespersonTitle(result);
        Test.stopTest();

        System.assertEquals('Director of Sales', title, 'Should return actual title');
    }

    @isTest
    static void testGetSalespersonTitle_Default() {
        LocationEmailMappingService.LocationLookupResult result =
            new LocationEmailMappingService.LocationLookupResult();
        result.found = true;

        Test.startTest();
        String title = LocationEmailMappingService.getSalespersonTitle(result);
        Test.stopTest();

        System.assertEquals('Group Sales', title, 'Should return default title');
    }
}

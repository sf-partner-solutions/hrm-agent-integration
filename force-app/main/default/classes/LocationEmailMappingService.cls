/**
 * @description Service class for mapping email addresses to Location records
 * Used to determine which hotel property received a booking request
 */
public with sharing class LocationEmailMappingService {

    /**
     * @description Wrapper for Location lookup result
     */
    public class LocationLookupResult {
        public Boolean found;
        public Id locationId;
        public String locationName;
        public String email;
        public String phone;
        public String address;
        public String city;
        public String stateProvince;
        public String postalCode;
        public String salespersonName;
        public String salespersonTitle;

        public LocationLookupResult() {
            this.found = false;
        }
    }

    /**
     * @description Finds a Location record by email address
     * @param recipientEmail The email address to look up
     * @return LocationLookupResult with Location details or not found
     */
    public static LocationLookupResult findLocationByEmail(String recipientEmail) {
        LocationLookupResult result = new LocationLookupResult();

        if (String.isBlank(recipientEmail)) {
            return result;
        }

        // Normalize email
        recipientEmail = recipientEmail.trim().toLowerCase();

        try {
            List<Location__c> locations = [
                SELECT Id, Name, Email__c, Phone__c,
                       AddressLine1__c, City__c, StateProvince__c, PostalCode__c,
                       SalespersonName__c, SalespersonTitle__c
                FROM Location__c
                WHERE Email__c = :recipientEmail
                LIMIT 1
            ];

            if (!locations.isEmpty()) {
                Location__c loc = locations[0];
                result.found = true;
                result.locationId = loc.Id;
                result.locationName = loc.Name;
                result.email = loc.Email__c;
                result.phone = loc.Phone__c;
                result.address = loc.AddressLine1__c;
                result.city = loc.City__c;
                result.stateProvince = loc.StateProvince__c;
                result.postalCode = loc.PostalCode__c;
                result.salespersonName = loc.SalespersonName__c;
                result.salespersonTitle = loc.SalespersonTitle__c;
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error finding location by email: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description Finds a Location record by ID
     * @param locationId The Salesforce ID of the Location
     * @return LocationLookupResult with Location details
     */
    public static LocationLookupResult findLocationById(String locationId) {
        LocationLookupResult result = new LocationLookupResult();

        if (String.isBlank(locationId)) {
            return result;
        }

        try {
            List<Location__c> locations = [
                SELECT Id, Name, Email__c, Phone__c,
                       AddressLine1__c, City__c, StateProvince__c, PostalCode__c,
                       SalespersonName__c, SalespersonTitle__c
                FROM Location__c
                WHERE Id = :locationId
                LIMIT 1
            ];

            if (!locations.isEmpty()) {
                Location__c loc = locations[0];
                result.found = true;
                result.locationId = loc.Id;
                result.locationName = loc.Name;
                result.email = loc.Email__c;
                result.phone = loc.Phone__c;
                result.address = loc.AddressLine1__c;
                result.city = loc.City__c;
                result.stateProvince = loc.StateProvince__c;
                result.postalCode = loc.PostalCode__c;
                result.salespersonName = loc.SalespersonName__c;
                result.salespersonTitle = loc.SalespersonTitle__c;
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error finding location by ID: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description Gets the full formatted address for a Location
     * @param result The LocationLookupResult
     * @return Formatted address string
     */
    public static String getFormattedAddress(LocationLookupResult result) {
        if (result == null || !result.found) {
            return null;
        }

        List<String> addressParts = new List<String>();

        if (String.isNotBlank(result.address)) {
            addressParts.add(result.address);
        }

        List<String> cityStateZip = new List<String>();
        if (String.isNotBlank(result.city)) {
            cityStateZip.add(result.city);
        }
        if (String.isNotBlank(result.stateProvince)) {
            cityStateZip.add(result.stateProvince);
        }
        if (String.isNotBlank(result.postalCode)) {
            cityStateZip.add(result.postalCode);
        }

        if (!cityStateZip.isEmpty()) {
            addressParts.add(String.join(cityStateZip, ', '));
        }

        return addressParts.isEmpty() ? null : String.join(addressParts, '\n');
    }

    /**
     * @description Gets the salesperson name with a fallback default
     * @param result The LocationLookupResult
     * @return The salesperson name or default
     */
    public static String getSalespersonName(LocationLookupResult result) {
        if (result != null && String.isNotBlank(result.salespersonName)) {
            return result.salespersonName;
        }
        return 'Reservations Team';
    }

    /**
     * @description Gets the salesperson title with a fallback default
     * @param result The LocationLookupResult
     * @return The salesperson title or default
     */
    public static String getSalespersonTitle(LocationLookupResult result) {
        if (result != null && String.isNotBlank(result.salespersonTitle)) {
            return result.salespersonTitle;
        }
        return 'Group Sales';
    }
}

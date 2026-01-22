/**
 * @description Flow-invocable action to query and format GuestroomTypeDay__c inventory data
 * Returns inventory records as JSON for AI analysis
 */
global with sharing class QueryGuestroomAvailabilityAction {

    /**
     * @description Input class for the invocable method
     */
    global class Input {
        @InvocableVariable(label='Location ID' description='ID of the Location__c record' required=true)
        public Id locationId;

        @InvocableVariable(label='Check-In Date' description='Start date for availability check' required=true)
        public Date checkInDate;

        @InvocableVariable(label='Check-Out Date' description='End date for availability check (exclusive)' required=true)
        public Date checkOutDate;

        @InvocableVariable(label='Room Type' description='Optional room type filter' required=false)
        public String roomType;
    }

    /**
     * @description Output class containing inventory data
     */
    global class Output {
        @InvocableVariable(label='Inventory JSON')
        public String inventoryJson;

        @InvocableVariable(label='Has Availability')
        public Boolean hasAvailability;

        @InvocableVariable(label='Total Records Found')
        public Integer totalRecords;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    /**
     * @description Invocable method to query inventory data
     * @param inputs List of Input objects containing query parameters
     * @return List of Output objects containing inventory JSON
     */
    @InvocableMethod(
        label='Query Guestroom Availability'
        description='Queries GuestroomTypeDay__c records for the given date range and returns JSON for AI analysis'
        category='Email Booking Automation'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                // Validate inputs
                if (input.locationId == null) {
                    output.success = false;
                    output.errorMessage = 'Location ID is required';
                    outputs.add(output);
                    continue;
                }

                if (input.checkInDate == null || input.checkOutDate == null) {
                    output.success = false;
                    output.errorMessage = 'Check-in and check-out dates are required';
                    outputs.add(output);
                    continue;
                }

                if (input.checkOutDate <= input.checkInDate) {
                    output.success = false;
                    output.errorMessage = 'Check-out date must be after check-in date';
                    outputs.add(output);
                    continue;
                }

                // Build the query
                String query = 'SELECT Id, Name, EffectiveDate__c, GroupAvailable__c, RackRate__c, ' +
                    'GuestroomType__c, GuestroomType__r.Name, Location__c, ' +
                    'PhysicalRoomInventory__c, BlockedDefinite__c, BlockedTentative__c, ' +
                    'TransientProtected__c, TransientSold__c, OutOfService__c ' +
                    'FROM GuestroomTypeDay__c ' +
                    'WHERE Location__c = :locationId ' +
                    'AND EffectiveDate__c >= :checkInDate ' +
                    'AND EffectiveDate__c < :checkOutDate';

                // Add room type filter if specified
                if (String.isNotBlank(input.roomType) && input.roomType != 'Any') {
                    query += ' AND GuestroomType__r.Name = :roomType';
                }

                query += ' ORDER BY EffectiveDate__c ASC, GuestroomType__r.Name ASC';

                // Execute query with bind variables
                Id locationId = input.locationId;
                Date checkInDate = input.checkInDate;
                Date checkOutDate = input.checkOutDate;
                String roomType = input.roomType;

                List<GuestroomTypeDay__c> inventoryRecords = Database.query(query);

                // Transform to JSON-friendly format
                List<Map<String, Object>> inventoryList = new List<Map<String, Object>>();
                Boolean hasAnyAvailability = false;

                for (GuestroomTypeDay__c record : inventoryRecords) {
                    Map<String, Object> recordMap = new Map<String, Object>();
                    recordMap.put('id', record.Id);
                    recordMap.put('name', record.Name);
                    recordMap.put('effectiveDate', record.EffectiveDate__c != null ?
                        String.valueOf(record.EffectiveDate__c) : null);
                    recordMap.put('groupAvailable', record.GroupAvailable__c != null ?
                        record.GroupAvailable__c : 0);
                    recordMap.put('rackRate', record.RackRate__c != null ?
                        record.RackRate__c : 0);
                    recordMap.put('roomTypeName', record.GuestroomType__r != null ?
                        record.GuestroomType__r.Name : 'Unknown');
                    recordMap.put('physicalInventory', record.PhysicalRoomInventory__c != null ?
                        record.PhysicalRoomInventory__c : 0);
                    recordMap.put('blockedDefinite', record.BlockedDefinite__c != null ?
                        record.BlockedDefinite__c : 0);
                    recordMap.put('blockedTentative', record.BlockedTentative__c != null ?
                        record.BlockedTentative__c : 0);
                    recordMap.put('transientProtected', record.TransientProtected__c != null ?
                        record.TransientProtected__c : 0);
                    recordMap.put('transientSold', record.TransientSold__c != null ?
                        record.TransientSold__c : 0);
                    recordMap.put('outOfService', record.OutOfService__c != null ?
                        record.OutOfService__c : 0);

                    inventoryList.add(recordMap);

                    // Check if any availability exists
                    if (record.GroupAvailable__c != null && record.GroupAvailable__c > 0) {
                        hasAnyAvailability = true;
                    }
                }

                output.success = true;
                output.inventoryJson = JSON.serialize(inventoryList);
                output.hasAvailability = hasAnyAvailability;
                output.totalRecords = inventoryRecords.size();

                System.debug('QueryGuestroomAvailabilityAction: Found ' + inventoryRecords.size() +
                    ' inventory records for location ' + locationId +
                    ' from ' + checkInDate + ' to ' + checkOutDate);

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = 'Error querying inventory: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'QueryGuestroomAvailabilityAction error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }

            outputs.add(output);
        }

        return outputs;
    }
}

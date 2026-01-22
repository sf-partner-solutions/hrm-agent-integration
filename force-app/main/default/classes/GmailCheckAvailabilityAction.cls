/**
 * @description Invocable action to check room availability
 */
global with sharing class GmailCheckAvailabilityAction {

    global class Input {
        @InvocableVariable(label='Location ID' required=true)
        public String locationId;

        @InvocableVariable(label='Check-In Date' required=true)
        public Date checkInDate;

        @InvocableVariable(label='Check-Out Date' required=true)
        public Date checkOutDate;

        @InvocableVariable(label='Rooms Requested' required=true)
        public Integer roomsRequested;

        @InvocableVariable(label='Room Type Name')
        public String roomTypeName;
    }

    global class Output {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Is Available')
        public Boolean isAvailable;

        @InvocableVariable(label='Availability Status')
        public String availabilityStatus;

        @InvocableVariable(label='Available Rooms')
        public Integer availableRooms;

        @InvocableVariable(label='Rate Per Night')
        public Decimal ratePerNight;

        @InvocableVariable(label='Number of Nights')
        public Integer numberOfNights;

        @InvocableVariable(label='Total Estimate')
        public Decimal totalEstimate;

        @InvocableVariable(label='Availability JSON')
        public String availabilityJson;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Check Room Availability'
        description='Queries GuestroomTypeDay__c for GroupAvailable__c availability'
        category='Gmail Integration'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                RoomInventoryService.AvailabilityResult result =
                    RoomInventoryService.checkAvailability(
                        Id.valueOf(input.locationId),
                        input.checkInDate,
                        input.checkOutDate,
                        input.roomsRequested,
                        input.roomTypeName
                    );

                output.success = String.isBlank(result.errorMessage);
                output.isAvailable = result.isAvailable;
                output.availabilityStatus = result.availabilityStatus;
                output.availableRooms = result.availableRooms;
                output.ratePerNight = result.ratePerNight;
                output.numberOfNights = result.numberOfNights;
                output.totalEstimate = result.totalEstimate;
                output.availabilityJson = RoomInventoryService.toJson(result);
                output.errorMessage = result.errorMessage;

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = 'Exception: ' + e.getMessage();
            }

            outputs.add(output);
        }

        return outputs;
    }
}

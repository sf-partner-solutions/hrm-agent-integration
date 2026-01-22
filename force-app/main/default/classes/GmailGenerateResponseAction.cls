/**
 * @description Invocable action to generate booking response email
 */
global with sharing class GmailGenerateResponseAction {

    global class Input {
        @InvocableVariable(label='Booking Request JSON' required=true)
        public String bookingRequestJson;

        @InvocableVariable(label='Availability JSON' required=true)
        public String availabilityJson;

        @InvocableVariable(label='Location ID' required=true)
        public String locationId;

        @InvocableVariable(label='Original Subject')
        public String originalSubject;

        @InvocableVariable(label='Sender First Name')
        public String senderFirstName;

        @InvocableVariable(label='Sender Full Name')
        public String senderFullName;
    }

    global class Output {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Email Subject')
        public String emailSubject;

        @InvocableVariable(label='Email Body HTML')
        public String emailBodyHtml;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Generate Booking Response Email'
        description='Generates personalized response email based on availability'
        category='Gmail Integration'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                BookingResponseService.BookingRequest request =
                    BookingResponseService.parseBookingRequestFromJson(input.bookingRequestJson);
                request.originalSubject = input.originalSubject;
                request.guestFirstName = input.senderFirstName;
                request.guestName = input.senderFullName;

                RoomInventoryService.AvailabilityResult availability =
                    (RoomInventoryService.AvailabilityResult) JSON.deserialize(
                        input.availabilityJson,
                        RoomInventoryService.AvailabilityResult.class
                    );

                LocationEmailMappingService.LocationLookupResult location =
                    LocationEmailMappingService.findLocationById(input.locationId);

                BookingResponseService.ResponseResult response =
                    BookingResponseService.generateResponse(request, availability, location);

                output.success = response.success;
                output.emailSubject = response.emailSubject;
                output.emailBodyHtml = response.emailBodyHtml;
                output.errorMessage = response.errorMessage;

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = 'Exception: ' + e.getMessage();
            }

            outputs.add(output);
        }

        return outputs;
    }
}

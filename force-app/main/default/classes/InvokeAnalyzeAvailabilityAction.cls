/**
 * @description Flow-invocable action for analyzing room availability
 * Uses BookingEmailPromptService to invoke the Analyze_Inventory_Availability prompt template
 */
global with sharing class InvokeAnalyzeAvailabilityAction {

    /**
     * @description Input class for the invocable method
     */
    global class Input {
        @InvocableVariable(label='Booking Request JSON' description='Parsed booking request as JSON' required=true)
        public String bookingRequestJson;

        @InvocableVariable(label='Inventory Data JSON' description='GuestroomTypeDay__c records as JSON' required=true)
        public String inventoryDataJson;
    }

    /**
     * @description Output class containing availability analysis
     */
    global class Output {
        @InvocableVariable(label='Availability Status')
        public String availabilityStatus;

        @InvocableVariable(label='Available Rooms')
        public Integer availableRooms;

        @InvocableVariable(label='Requested Rooms')
        public Integer requestedRooms;

        @InvocableVariable(label='Rate Per Night')
        public Decimal ratePerNight;

        @InvocableVariable(label='Total Estimate')
        public Decimal totalEstimate;

        @InvocableVariable(label='Number of Nights')
        public Integer numberOfNights;

        @InvocableVariable(label='Can Accommodate')
        public Boolean canAccommodate;

        @InvocableVariable(label='Shortfall')
        public Integer shortfall;

        @InvocableVariable(label='Constraining Date')
        public Date constrainingDate;

        @InvocableVariable(label='Raw JSON Response')
        public String rawJson;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    /**
     * @description Invocable method to analyze availability
     * @param inputs List of Input objects containing booking request and inventory data
     * @return List of Output objects containing availability analysis
     */
    @InvocableMethod(
        label='Analyze Room Availability'
        description='Analyzes inventory data against booking request using AI to determine availability status'
        category='Email Booking Automation'
    )
    global static List<Output> execute(List<Input> inputs) {
        List<Output> outputs = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                // Validate required inputs
                if (String.isBlank(input.bookingRequestJson)) {
                    output.success = false;
                    output.errorMessage = 'Booking request JSON is required';
                    outputs.add(output);
                    continue;
                }

                if (String.isBlank(input.inventoryDataJson)) {
                    output.success = false;
                    output.errorMessage = 'Inventory data JSON is required';
                    outputs.add(output);
                    continue;
                }

                // Call the prompt service
                BookingEmailPromptService.AvailabilityAnalysis result =
                    BookingEmailPromptService.analyzeAvailability(
                        input.bookingRequestJson,
                        input.inventoryDataJson
                    );

                // Map the result to the output
                output.success = true;
                output.availabilityStatus = result.availabilityStatus;
                output.availableRooms = result.availableRooms;
                output.requestedRooms = result.requestedRooms;
                output.ratePerNight = result.ratePerNight;
                output.totalEstimate = result.totalEstimate;
                output.numberOfNights = result.numberOfNights;
                output.canAccommodate = result.canAccommodate;
                output.shortfall = result.shortfall;
                output.constrainingDate = result.constrainingDate;
                output.rawJson = result.rawJson;

                System.debug('Availability analysis complete. Status: ' + output.availabilityStatus +
                    ', Available: ' + output.availableRooms + ', Requested: ' + output.requestedRooms);

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = 'Error analyzing availability: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'InvokeAnalyzeAvailabilityAction error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }

            outputs.add(output);
        }

        return outputs;
    }
}

/**
 * @description Flow-invocable action to parse availability JSON and extract pricing details
 */
public with sharing class ParseAvailabilityJsonAction {

    /**
     * @description Input parameters for the invocable action
     */
    public class Input {
        @InvocableVariable(label='Availability JSON' description='The raw availability JSON string' required=true)
        public String availabilityJson;

        @InvocableVariable(label='Number of Nights' description='Number of nights for the stay (optional, will calculate from JSON if available)' required=false)
        public Integer numberOfNights;
    }

    /**
     * @description Output results from the invocable action
     */
    public class Output {
        @InvocableVariable(label='Rate Per Night' description='Nightly rate per room')
        public Decimal ratePerNight;

        @InvocableVariable(label='Total Estimate' description='Total estimated cost before taxes')
        public Decimal totalEstimate;

        @InvocableVariable(label='Total With Tax' description='Total estimated cost including estimated taxes (12%)')
        public Decimal totalWithTax;

        @InvocableVariable(label='Rate Per Night Formatted' description='Formatted nightly rate (e.g., $149.00)')
        public String ratePerNightFormatted;

        @InvocableVariable(label='Total Estimate Formatted' description='Formatted total estimate (e.g., $596.00)')
        public String totalEstimateFormatted;

        @InvocableVariable(label='Total With Tax Formatted' description='Formatted total with tax (e.g., $667.52)')
        public String totalWithTaxFormatted;

        @InvocableVariable(label='Number of Nights' description='Number of nights from the availability data')
        public Integer numberOfNights;

        @InvocableVariable(label='Success' description='True if parsing was successful')
        public Boolean success;

        @InvocableVariable(label='Error Message' description='Error message if parsing failed')
        public String errorMessage;
    }

    /**
     * @description Invocable method to parse availability JSON
     * @param inputs List of Input objects
     * @return List of Output objects with parsed pricing data
     */
    @InvocableMethod(label='Parse Availability JSON' description='Extracts rate per night and total estimate from availability JSON' category='Email Processing')
    public static List<Output> parseAvailabilityJson(List<Input> inputs) {
        List<Output> results = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();

            try {
                if (String.isBlank(input.availabilityJson)) {
                    output.success = false;
                    output.errorMessage = 'Availability JSON is empty';
                    results.add(output);
                    continue;
                }

                // Parse the JSON
                Map<String, Object> availabilityMap = (Map<String, Object>) JSON.deserializeUntyped(input.availabilityJson);

                // Extract rate per night
                if (availabilityMap.containsKey('ratePerNight')) {
                    Object rateObj = availabilityMap.get('ratePerNight');
                    if (rateObj != null) {
                        output.ratePerNight = Decimal.valueOf(String.valueOf(rateObj));
                        output.ratePerNightFormatted = '$' + output.ratePerNight.setScale(2).format();
                    }
                }

                // Extract total estimate
                if (availabilityMap.containsKey('totalEstimate')) {
                    Object totalObj = availabilityMap.get('totalEstimate');
                    if (totalObj != null) {
                        output.totalEstimate = Decimal.valueOf(String.valueOf(totalObj));
                        output.totalEstimateFormatted = '$' + output.totalEstimate.setScale(2).format();

                        // Calculate total with estimated 12% tax
                        output.totalWithTax = output.totalEstimate * 1.12;
                        output.totalWithTaxFormatted = '$' + output.totalWithTax.setScale(2).format();
                    }
                }

                // Extract or calculate number of nights
                if (availabilityMap.containsKey('numberOfNights')) {
                    Object nightsObj = availabilityMap.get('numberOfNights');
                    if (nightsObj != null) {
                        output.numberOfNights = Integer.valueOf(String.valueOf(nightsObj));
                    }
                } else if (input.numberOfNights != null) {
                    output.numberOfNights = input.numberOfNights;
                }

                output.success = true;

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = 'Failed to parse availability JSON: ' + e.getMessage();
                System.debug(LoggingLevel.ERROR, 'ParseAvailabilityJsonAction error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }

            results.add(output);
        }

        return results;
    }
}

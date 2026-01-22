/**
 * @description Centralized service for invoking booking-related prompt templates via ConnectApi
 * Handles parsing emails, analyzing availability, and generating responses
 */
public with sharing class BookingEmailPromptService {

    /**
     * @description Wrapper class for parsed booking request data
     */
    public class ParsedBookingRequest {
        @AuraEnabled public Date checkInDate { get; set; }
        @AuraEnabled public Date checkOutDate { get; set; }
        @AuraEnabled public Integer numberOfNights { get; set; }
        @AuraEnabled public Integer totalRoomsRequested { get; set; }
        @AuraEnabled public List<RoomRequest> roomRequests { get; set; }
        @AuraEnabled public Integer numberOfGuests { get; set; }
        @AuraEnabled public String guestName { get; set; }
        @AuraEnabled public String organizationName { get; set; }
        @AuraEnabled public String eventName { get; set; }
        @AuraEnabled public String specialRequests { get; set; }
        @AuraEnabled public Boolean isUrgent { get; set; }
        @AuraEnabled public String confidence { get; set; }
        @AuraEnabled public String roomTypePreference { get; set; }
        @AuraEnabled public Boolean isBookingRequest { get; set; }
        @AuraEnabled public String suggestedAction { get; set; }
        @AuraEnabled public String rawJson { get; set; }
    }

    /**
     * @description Wrapper for individual room type requests
     */
    public class RoomRequest {
        @AuraEnabled public String roomType { get; set; }
        @AuraEnabled public Integer quantity { get; set; }
    }

    /**
     * @description Wrapper class for availability analysis results
     */
    public class AvailabilityAnalysis {
        @AuraEnabled public String availabilityStatus { get; set; }
        @AuraEnabled public Integer requestedRooms { get; set; }
        @AuraEnabled public Integer availableRooms { get; set; }
        @AuraEnabled public String requestedRoomType { get; set; }
        @AuraEnabled public Date checkInDate { get; set; }
        @AuraEnabled public Date checkOutDate { get; set; }
        @AuraEnabled public Integer numberOfNights { get; set; }
        @AuraEnabled public List<DateBreakdown> dateBreakdown { get; set; }
        @AuraEnabled public Date constrainingDate { get; set; }
        @AuraEnabled public Decimal ratePerNight { get; set; }
        @AuraEnabled public Decimal totalEstimate { get; set; }
        @AuraEnabled public Boolean canAccommodate { get; set; }
        @AuraEnabled public Integer shortfall { get; set; }
        @AuraEnabled public String rawJson { get; set; }
    }

    /**
     * @description Wrapper for daily availability breakdown
     */
    public class DateBreakdown {
        @AuraEnabled public String dateValue { get; set; }
        @AuraEnabled public Integer available { get; set; }
        @AuraEnabled public Boolean sufficient { get; set; }
    }

    /**
     * @description Wrapper class for generated email response
     */
    public class GeneratedResponse {
        @AuraEnabled public String emailSubject { get; set; }
        @AuraEnabled public String emailBodyHtml { get; set; }
        @AuraEnabled public String emailBodyPlain { get; set; }
        @AuraEnabled public List<String> followUpQuestions { get; set; }
        @AuraEnabled public String toneCheck { get; set; }
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    /**
     * @description Invokes the Parse_Hotel_Booking_Email prompt template
     * @param emailBody The raw email body text
     * @param subject The email subject line
     * @param senderName The sender's name
     * @return ParsedBookingRequest containing extracted booking details
     */
    public static ParsedBookingRequest parseBookingEmail(String emailBody, String subject, String senderName) {
        try {
            // Build input parameters for the prompt template
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            // EmailBody parameter
            ConnectApi.WrappedValue emailBodyValue = new ConnectApi.WrappedValue();
            emailBodyValue.value = emailBody;
            inputParams.put('Input:EmailBody', emailBodyValue);

            // EmailSubject parameter
            ConnectApi.WrappedValue subjectValue = new ConnectApi.WrappedValue();
            subjectValue.value = String.isNotBlank(subject) ? subject : '';
            inputParams.put('Input:EmailSubject', subjectValue);

            // SenderName parameter
            ConnectApi.WrappedValue senderNameValue = new ConnectApi.WrappedValue();
            senderNameValue.value = String.isNotBlank(senderName) ? senderName : '';
            inputParams.put('Input:SenderName', senderNameValue);

            // TodayDate parameter
            ConnectApi.WrappedValue todayValue = new ConnectApi.WrappedValue();
            todayValue.value = Date.today().format();
            inputParams.put('Input:TodayDate', todayValue);

            // Configure and execute the prompt template
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.applicationName = 'PromptBuilderPreview';
            promptInput.isPreview = false;
            promptInput.inputParams = inputParams;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'Parse_Hotel_Booking_Email',
                    promptInput
                );

            // Process the response
            if (response != null && response.generations != null && !response.generations.isEmpty()) {
                String responseText = response.generations[0].text;
                String cleanedJson = cleanJsonResponse(responseText);

                System.debug('Parse prompt response: ' + cleanedJson);

                return deserializeParsedBookingRequest(cleanedJson);
            }

            throw new BookingPromptException('No response received from Parse_Hotel_Booking_Email prompt');

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error parsing booking email: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new BookingPromptException('Failed to parse booking email: ' + e.getMessage());
        }
    }

    /**
     * @description Invokes the Analyze_Inventory_Availability prompt template
     * @param bookingRequestJson The parsed booking request as JSON
     * @param inventoryJson The GuestroomTypeDay__c records as JSON
     * @return AvailabilityAnalysis containing availability assessment
     */
    public static AvailabilityAnalysis analyzeAvailability(String bookingRequestJson, String inventoryJson) {
        try {
            // Build input parameters
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            ConnectApi.WrappedValue bookingValue = new ConnectApi.WrappedValue();
            bookingValue.value = bookingRequestJson;
            inputParams.put('Input:BookingRequestJson', bookingValue);

            ConnectApi.WrappedValue inventoryValue = new ConnectApi.WrappedValue();
            inventoryValue.value = inventoryJson;
            inputParams.put('Input:InventoryDataJson', inventoryValue);

            // Configure and execute
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.applicationName = 'PromptBuilderPreview';
            promptInput.isPreview = false;
            promptInput.inputParams = inputParams;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'Analyze_Inventory_Availability',
                    promptInput
                );

            if (response != null && response.generations != null && !response.generations.isEmpty()) {
                String responseText = response.generations[0].text;
                String cleanedJson = cleanJsonResponse(responseText);

                System.debug('Availability analysis response: ' + cleanedJson);

                return deserializeAvailabilityAnalysis(cleanedJson);
            }

            throw new BookingPromptException('No response received from Analyze_Inventory_Availability prompt');

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error analyzing availability: ' + e.getMessage());
            throw new BookingPromptException('Failed to analyze availability: ' + e.getMessage());
        }
    }

    /**
     * @description Invokes the Generate_Booking_Response_Email prompt template
     * @param senderInfoJson Sender information as JSON
     * @param bookingRequestJson Parsed booking request as JSON
     * @param availabilityJson Availability analysis as JSON
     * @param hotelInfoJson Hotel information as JSON
     * @return GeneratedResponse containing the email content
     */
    public static GeneratedResponse generateResponse(
        String senderInfoJson,
        String bookingRequestJson,
        String availabilityJson,
        String hotelInfoJson
    ) {
        try {
            // Build input parameters
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            ConnectApi.WrappedValue senderValue = new ConnectApi.WrappedValue();
            senderValue.value = senderInfoJson;
            inputParams.put('Input:SenderInfoJson', senderValue);

            ConnectApi.WrappedValue bookingValue = new ConnectApi.WrappedValue();
            bookingValue.value = bookingRequestJson;
            inputParams.put('Input:BookingRequestJson', bookingValue);

            ConnectApi.WrappedValue availabilityValue = new ConnectApi.WrappedValue();
            availabilityValue.value = availabilityJson;
            inputParams.put('Input:AvailabilityJson', availabilityValue);

            ConnectApi.WrappedValue hotelValue = new ConnectApi.WrappedValue();
            hotelValue.value = hotelInfoJson;
            inputParams.put('Input:HotelInfoJson', hotelValue);

            // Configure and execute
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.applicationName = 'PromptBuilderPreview';
            promptInput.isPreview = false;
            promptInput.inputParams = inputParams;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'Generate_Booking_Response_Email',
                    promptInput
                );

            if (response != null && response.generations != null && !response.generations.isEmpty()) {
                String responseText = response.generations[0].text;
                String cleanedJson = cleanJsonResponse(responseText);

                System.debug('Generated response: ' + cleanedJson);

                return deserializeGeneratedResponse(cleanedJson);
            }

            throw new BookingPromptException('No response received from Generate_Booking_Response_Email prompt');

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error generating response: ' + e.getMessage());
            GeneratedResponse errorResponse = new GeneratedResponse();
            errorResponse.success = false;
            errorResponse.errorMessage = 'Failed to generate response: ' + e.getMessage();
            return errorResponse;
        }
    }

    /**
     * @description Cleans JSON response by removing markdown code blocks
     * @param response The raw response text
     * @return Cleaned JSON string
     */
    private static String cleanJsonResponse(String response) {
        if (response == null) {
            return null;
        }

        String cleaned = response.trim();

        // Remove markdown code blocks
        if (cleaned.contains('```json')) {
            cleaned = cleaned.substringBetween('```json', '```');
        } else if (cleaned.contains('```')) {
            cleaned = cleaned.substringBetween('```', '```');
        }

        return cleaned != null ? cleaned.trim() : response.trim();
    }

    /**
     * @description Deserializes JSON into ParsedBookingRequest
     * @param jsonString The JSON string to deserialize
     * @return ParsedBookingRequest object
     */
    private static ParsedBookingRequest deserializeParsedBookingRequest(String jsonString) {
        ParsedBookingRequest result = new ParsedBookingRequest();
        result.rawJson = jsonString;

        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);

        // Check if it's a booking request
        if (jsonMap.containsKey('isBookingRequest') && jsonMap.get('isBookingRequest') == false) {
            result.isBookingRequest = false;
            result.suggestedAction = (String) jsonMap.get('suggestedAction');
            return result;
        }

        result.isBookingRequest = true;

        // Parse dates
        if (jsonMap.get('checkInDate') != null) {
            result.checkInDate = Date.valueOf((String) jsonMap.get('checkInDate'));
        }
        if (jsonMap.get('checkOutDate') != null) {
            result.checkOutDate = Date.valueOf((String) jsonMap.get('checkOutDate'));
        }

        // Parse numeric fields
        result.numberOfNights = getIntegerValue(jsonMap, 'numberOfNights');
        result.totalRoomsRequested = getIntegerValue(jsonMap, 'totalRoomsRequested');
        result.numberOfGuests = getIntegerValue(jsonMap, 'numberOfGuests');

        // Parse string fields
        result.guestName = (String) jsonMap.get('guestName');
        result.organizationName = (String) jsonMap.get('organizationName');
        result.eventName = (String) jsonMap.get('eventName');
        result.specialRequests = (String) jsonMap.get('specialRequests');
        result.confidence = (String) jsonMap.get('confidence');
        result.roomTypePreference = (String) jsonMap.get('roomTypePreference');

        // Parse boolean
        result.isUrgent = jsonMap.get('isUrgent') == true;

        // Parse room requests array
        if (jsonMap.containsKey('roomRequests')) {
            result.roomRequests = new List<RoomRequest>();
            List<Object> roomList = (List<Object>) jsonMap.get('roomRequests');
            if (roomList != null) {
                for (Object roomObj : roomList) {
                    Map<String, Object> roomMap = (Map<String, Object>) roomObj;
                    RoomRequest rr = new RoomRequest();
                    rr.roomType = (String) roomMap.get('roomType');
                    rr.quantity = getIntegerValue(roomMap, 'quantity');
                    result.roomRequests.add(rr);
                }
            }
        }

        return result;
    }

    /**
     * @description Deserializes JSON into AvailabilityAnalysis
     * @param jsonString The JSON string to deserialize
     * @return AvailabilityAnalysis object
     */
    private static AvailabilityAnalysis deserializeAvailabilityAnalysis(String jsonString) {
        AvailabilityAnalysis result = new AvailabilityAnalysis();
        result.rawJson = jsonString;

        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);

        result.availabilityStatus = (String) jsonMap.get('availabilityStatus');
        result.requestedRooms = getIntegerValue(jsonMap, 'requestedRooms');
        result.availableRooms = getIntegerValue(jsonMap, 'availableRooms');
        result.requestedRoomType = (String) jsonMap.get('requestedRoomType');
        result.numberOfNights = getIntegerValue(jsonMap, 'numberOfNights');
        result.ratePerNight = getDecimalValue(jsonMap, 'ratePerNight');
        result.totalEstimate = getDecimalValue(jsonMap, 'totalEstimate');
        result.canAccommodate = jsonMap.get('canAccommodate') == true;
        result.shortfall = getIntegerValue(jsonMap, 'shortfall');

        // Parse dates
        if (jsonMap.get('checkInDate') != null) {
            result.checkInDate = Date.valueOf((String) jsonMap.get('checkInDate'));
        }
        if (jsonMap.get('checkOutDate') != null) {
            result.checkOutDate = Date.valueOf((String) jsonMap.get('checkOutDate'));
        }
        if (jsonMap.get('constrainingDate') != null) {
            String constrainingStr = (String) jsonMap.get('constrainingDate');
            // Handle the case where it might have extra text
            if (constrainingStr.length() >= 10) {
                result.constrainingDate = Date.valueOf(constrainingStr.substring(0, 10));
            }
        }

        // Parse date breakdown
        if (jsonMap.containsKey('dateBreakdown')) {
            result.dateBreakdown = new List<DateBreakdown>();
            List<Object> breakdownList = (List<Object>) jsonMap.get('dateBreakdown');
            if (breakdownList != null) {
                for (Object bdObj : breakdownList) {
                    Map<String, Object> bdMap = (Map<String, Object>) bdObj;
                    DateBreakdown db = new DateBreakdown();
                    db.dateValue = (String) bdMap.get('date');
                    db.available = getIntegerValue(bdMap, 'available');
                    db.sufficient = bdMap.get('sufficient') == true;
                    result.dateBreakdown.add(db);
                }
            }
        }

        return result;
    }

    /**
     * @description Deserializes JSON into GeneratedResponse
     * @param jsonString The JSON string to deserialize
     * @return GeneratedResponse object
     */
    private static GeneratedResponse deserializeGeneratedResponse(String jsonString) {
        GeneratedResponse result = new GeneratedResponse();

        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);

        result.emailSubject = (String) jsonMap.get('emailSubject');
        result.emailBodyHtml = (String) jsonMap.get('emailBodyHtml');
        result.emailBodyPlain = (String) jsonMap.get('emailBodyPlain');
        result.toneCheck = (String) jsonMap.get('toneCheck');
        result.success = true;

        // Parse follow-up questions
        if (jsonMap.containsKey('followUpQuestions')) {
            result.followUpQuestions = new List<String>();
            List<Object> questionList = (List<Object>) jsonMap.get('followUpQuestions');
            if (questionList != null) {
                for (Object q : questionList) {
                    result.followUpQuestions.add((String) q);
                }
            }
        }

        return result;
    }

    /**
     * @description Safely gets an Integer value from a map
     */
    private static Integer getIntegerValue(Map<String, Object> jsonMap, String key) {
        Object val = jsonMap.get(key);
        if (val == null) {
            return null;
        }
        if (val instanceof Integer) {
            return (Integer) val;
        }
        if (val instanceof Decimal) {
            return ((Decimal) val).intValue();
        }
        return Integer.valueOf(String.valueOf(val));
    }

    /**
     * @description Safely gets a Decimal value from a map
     */
    private static Decimal getDecimalValue(Map<String, Object> jsonMap, String key) {
        Object val = jsonMap.get(key);
        if (val == null) {
            return null;
        }
        if (val instanceof Decimal) {
            return (Decimal) val;
        }
        return Decimal.valueOf(String.valueOf(val));
    }

    /**
     * @description Wrapper class for email intent recognition results
     */
    public class EmailIntentResult {
        @AuraEnabled public String intent { get; set; }  // New_Inquiry, Follow_Up_Answer, Booking_Confirmation, Booking_Rejection, General_Question, Modification_Request
        @AuraEnabled public String confidence { get; set; }  // high, medium, low
        @AuraEnabled public String reasoning { get; set; }
        @AuraEnabled public String extractedGuestName { get; set; }
        @AuraEnabled public String extractedOrganizationName { get; set; }
        @AuraEnabled public String extractedEventName { get; set; }
        @AuraEnabled public Boolean hasBookingConfirmation { get; set; }
        @AuraEnabled public Boolean hasRejection { get; set; }
        @AuraEnabled public Boolean hasNewQuestions { get; set; }
        @AuraEnabled public Boolean answersProvided { get; set; }
        @AuraEnabled public String rawJson { get; set; }
    }

    /**
     * @description Recognizes the intent of an incoming email in a booking conversation thread
     * @param emailBody The raw email body text
     * @param emailSubject The email subject line
     * @param senderName The sender's name
     * @param previousEmailContext Optional context from previous emails in the thread
     * @return EmailIntentResult containing the classified intent
     */
    public static EmailIntentResult recognizeEmailIntent(String emailBody, String emailSubject, String senderName, String previousEmailContext) {
        try {
            // Build input parameters for the prompt template
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            // EmailBody parameter
            ConnectApi.WrappedValue emailBodyValue = new ConnectApi.WrappedValue();
            emailBodyValue.value = emailBody;
            inputParams.put('Input:EmailBody', emailBodyValue);

            // EmailSubject parameter
            ConnectApi.WrappedValue subjectValue = new ConnectApi.WrappedValue();
            subjectValue.value = String.isNotBlank(emailSubject) ? emailSubject : '';
            inputParams.put('Input:EmailSubject', subjectValue);

            // SenderName parameter
            ConnectApi.WrappedValue senderNameValue = new ConnectApi.WrappedValue();
            senderNameValue.value = String.isNotBlank(senderName) ? senderName : '';
            inputParams.put('Input:SenderName', senderNameValue);

            // PreviousEmailContext parameter (optional - helps determine if this is a follow-up)
            ConnectApi.WrappedValue contextValue = new ConnectApi.WrappedValue();
            contextValue.value = String.isNotBlank(previousEmailContext) ? previousEmailContext : '';
            inputParams.put('Input:PreviousEmailContext', contextValue);

            // Configure and execute the prompt template
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.applicationName = 'PromptBuilderPreview';
            promptInput.isPreview = false;
            promptInput.inputParams = inputParams;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'Recognize_Email_Intent',
                    promptInput
                );

            // Process the response
            if (response != null && response.generations != null && !response.generations.isEmpty()) {
                String responseText = response.generations[0].text;
                String cleanedJson = cleanJsonResponse(responseText);

                System.debug('Intent recognition response: ' + cleanedJson);

                return deserializeEmailIntentResult(cleanedJson);
            }

            throw new BookingPromptException('No response received from Recognize_Email_Intent prompt');

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error recognizing email intent: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new BookingPromptException('Failed to recognize email intent: ' + e.getMessage());
        }
    }

    /**
     * @description Deserializes JSON into EmailIntentResult
     * @param jsonString The JSON string to deserialize
     * @return EmailIntentResult object
     */
    private static EmailIntentResult deserializeEmailIntentResult(String jsonString) {
        EmailIntentResult result = new EmailIntentResult();
        result.rawJson = jsonString;

        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);

        result.intent = (String) jsonMap.get('intent');
        result.confidence = (String) jsonMap.get('confidence');
        result.reasoning = (String) jsonMap.get('reasoning');
        result.extractedGuestName = (String) jsonMap.get('extractedGuestName');
        result.extractedOrganizationName = (String) jsonMap.get('extractedOrganizationName');
        result.extractedEventName = (String) jsonMap.get('extractedEventName');
        result.hasBookingConfirmation = jsonMap.get('hasBookingConfirmation') == true;
        result.hasRejection = jsonMap.get('hasRejection') == true;
        result.hasNewQuestions = jsonMap.get('hasNewQuestions') == true;
        result.answersProvided = jsonMap.get('answersProvided') == true;

        return result;
    }

    /**
     * @description Custom exception for booking prompt errors
     */
    public class BookingPromptException extends Exception {}
}

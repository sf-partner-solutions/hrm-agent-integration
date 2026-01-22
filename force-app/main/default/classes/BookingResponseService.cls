/**
 * @description Service class for generating booking response emails
 * Creates personalized HTML email responses based on availability
 */
public with sharing class BookingResponseService {

    /**
     * @description Wrapper for booking request details
     */
    public class BookingRequest {
        public Date checkInDate;
        public Date checkOutDate;
        public Integer numberOfRooms;
        public Integer numberOfNights;
        public Integer numberOfGuests;
        public String guestName;
        public String guestFirstName;
        public String guestEmail;
        public String organizationName;
        public String roomTypePreference;
        public String specialRequests;
        public String originalSubject;
        public String originalEmailBody;
    }

    /**
     * @description Wrapper for response generation result
     */
    public class ResponseResult {
        public String emailSubject;
        public String emailBodyHtml;
        public String emailBodyPlain;
        public Boolean success;
        public String errorMessage;

        public ResponseResult() {
            this.success = false;
        }
    }

    /**
     * @description Generates a response email based on availability
     * @param request The booking request details
     * @param availability The availability check result
     * @param location The location lookup result
     * @return ResponseResult with email content
     */
    public static ResponseResult generateResponse(
        BookingRequest request,
        RoomInventoryService.AvailabilityResult availability,
        LocationEmailMappingService.LocationLookupResult location
    ) {
        ResponseResult result = new ResponseResult();

        try {
            // Determine response type
            String responseType = availability.availabilityStatus;

            // Generate subject
            result.emailSubject = GmailMessageParser.createReplySubject(request.originalSubject);

            // Get personalization details
            String firstName = String.isNotBlank(request.guestFirstName) ?
                request.guestFirstName : 'there';
            String hotelName = location.locationName;
            String salesperson = LocationEmailMappingService.getSalespersonName(location);
            String title = LocationEmailMappingService.getSalespersonTitle(location);
            String phone = location.phone;
            String email = location.email;

            // Generate HTML body based on availability status
            if (responseType == 'full') {
                result.emailBodyHtml = generateFullAvailabilityResponse(
                    request, availability, firstName, hotelName, salesperson, title, phone, email
                );
            } else if (responseType == 'partial') {
                result.emailBodyHtml = generatePartialAvailabilityResponse(
                    request, availability, firstName, hotelName, salesperson, title, phone, email
                );
            } else {
                result.emailBodyHtml = generateNoAvailabilityResponse(
                    request, availability, firstName, hotelName, salesperson, title, phone, email
                );
            }

            // Generate plain text version
            result.emailBodyPlain = stripHtmlTags(result.emailBodyHtml);

            result.success = true;

        } catch (Exception e) {
            result.errorMessage = 'Error generating response: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'Response generation error: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description Generates response for full availability
     */
    private static String generateFullAvailabilityResponse(
        BookingRequest request,
        RoomInventoryService.AvailabilityResult availability,
        String firstName,
        String hotelName,
        String salesperson,
        String title,
        String phone,
        String email
    ) {
        String orgMention = String.isNotBlank(request.organizationName) ?
            ' for ' + request.organizationName : '';

        String html = '<html><body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">';

        html += '<p>Hi ' + firstName + '!</p>';

        html += '<p>Thank you for reaching out to ' + hotelName + orgMention + '. ';
        html += 'We\'re delighted to confirm that we have availability for your requested dates!</p>';

        html += '<p><strong>BOOKING DETAILS:</strong></p>';
        html += '<ul>';
        html += '<li><strong>Check-in:</strong> ' + formatDate(request.checkInDate) + '</li>';
        html += '<li><strong>Check-out:</strong> ' + formatDate(request.checkOutDate) + '</li>';
        html += '<li><strong>Number of Nights:</strong> ' + availability.numberOfNights + '</li>';
        html += '<li><strong>Rooms Available:</strong> ' + availability.availableRooms + ' rooms</li>';
        html += '<li><strong>Rate per Room per Night:</strong> $' + availability.ratePerNight.setScale(2) + '</li>';
        html += '<li><strong>Estimated Total:</strong> $' + availability.totalEstimate.setScale(2) + ' (excluding taxes and fees)</li>';
        html += '</ul>';

        html += '<p>A few quick questions to help us prepare for your group:</p>';
        html += '<ul>';
        html += '<li>Would you like the rooms on the same floor to keep your group together?</li>';
        html += '<li>Will you need any meeting space or a team room?</li>';
        html += '<li>Should we arrange a group breakfast option?</li>';
        html += '</ul>';

        html += '<p>To proceed with the booking, simply reply to this email or call us at ' + phone + '.</p>';

        html += '<p>We look forward to welcoming you to ' + hotelName + '!</p>';

        html += '<p>Warm regards,<br/>';
        html += '<strong>' + salesperson + '</strong><br/>';
        html += title + '<br/>';
        html += hotelName + '<br/>';
        if (String.isNotBlank(phone)) {
            html += phone + '<br/>';
        }
        html += email + '</p>';

        html += '</body></html>';

        return html;
    }

    /**
     * @description Generates response for partial availability
     */
    private static String generatePartialAvailabilityResponse(
        BookingRequest request,
        RoomInventoryService.AvailabilityResult availability,
        String firstName,
        String hotelName,
        String salesperson,
        String title,
        String phone,
        String email
    ) {
        String orgMention = String.isNotBlank(request.organizationName) ?
            request.organizationName : 'your group';

        String html = '<html><body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">';

        html += '<p>Hi ' + firstName + '!</p>';

        html += '<p>Thank you for your interest in ' + hotelName + ' for ' + orgMention + '!</p>';

        html += '<p>I want to be upfront with you - while we\'d love to accommodate your full request for ';
        html += request.numberOfRooms + ' rooms, we currently have <strong>' + availability.availableRooms;
        html += ' rooms</strong> available for your dates.</p>';

        html += '<p><strong>WHAT WE CAN OFFER:</strong></p>';
        html += '<ul>';
        html += '<li><strong>' + availability.availableRooms + ' Rooms</strong></li>';
        html += '<li><strong>Check-in:</strong> ' + formatDate(request.checkInDate) + '</li>';
        html += '<li><strong>Check-out:</strong> ' + formatDate(request.checkOutDate) + '</li>';
        html += '<li><strong>Rate:</strong> $' + availability.ratePerNight.setScale(2) + ' per room per night</li>';
        html += '<li><strong>Estimated Total:</strong> $' + availability.totalEstimate.setScale(2) + ' (excluding taxes)</li>';
        html += '</ul>';

        html += '<p>A few options to consider:</p>';
        html += '<ol>';
        html += '<li>Would ' + availability.availableRooms + ' rooms work if some guests share differently?</li>';
        html += '<li>I can put you on our priority waitlist - cancellations do happen</li>';
        html += '<li>Would you like me to suggest alternative dates with full availability?</li>';
        html += '</ol>';

        html += '<p>' + firstName + ', I really want to make this work for you. ';
        html += 'Give me a call at ' + phone + ' and let\'s figure out the best solution!</p>';

        html += '<p>Best regards,<br/>';
        html += '<strong>' + salesperson + '</strong><br/>';
        html += title + '<br/>';
        html += hotelName + '<br/>';
        html += phone + '</p>';

        html += '</body></html>';

        return html;
    }

    /**
     * @description Generates response for no availability
     */
    private static String generateNoAvailabilityResponse(
        BookingRequest request,
        RoomInventoryService.AvailabilityResult availability,
        String firstName,
        String hotelName,
        String salesperson,
        String title,
        String phone,
        String email
    ) {
        String html = '<html><body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">';

        html += '<p>Hi ' + firstName + ',</p>';

        html += '<p>Thank you so much for thinking of ' + hotelName + ' for your upcoming stay!</p>';

        html += '<p>I\'m sorry to share that we\'re fully committed for ';
        html += formatDate(request.checkInDate) + ' - ' + formatDate(request.checkOutDate) + '. ';
        html += 'We have an event that has taken most of our room inventory for those dates.</p>';

        html += '<p>However, I don\'t want to leave you without options:</p>';
        html += '<ul>';
        html += '<li><strong>Different dates?</strong> If there\'s any flexibility in your schedule, ';
        html += 'I\'d be happy to check availability for alternative dates</li>';
        html += '<li><strong>Waitlist:</strong> I can add you to our cancellation list - sometimes rooms open up</li>';
        html += '<li><strong>Future events:</strong> If this is a recurring event, let me know and I\'ll help you book early next time!</li>';
        html += '</ul>';

        html += '<p>I\'m really sorry we couldn\'t accommodate you this time. Please don\'t hesitate to reach out ';
        html += 'for future events - we\'d love the opportunity to host you!</p>';

        html += '<p>Warm regards,<br/>';
        html += '<strong>' + salesperson + '</strong><br/>';
        html += title + '<br/>';
        html += hotelName + '<br/>';
        html += phone + '</p>';

        html += '</body></html>';

        return html;
    }

    /**
     * @description Formats a date for display
     */
    private static String formatDate(Date d) {
        if (d == null) {
            return 'TBD';
        }

        // Format: "Saturday, March 15, 2025"
        Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
        return dt.format('EEEE, MMMM d, yyyy');
    }

    /**
     * @description Strips HTML tags for plain text version
     */
    private static String stripHtmlTags(String html) {
        if (String.isBlank(html)) {
            return '';
        }

        // Replace common elements with appropriate text
        html = html.replaceAll('(?i)<br[^>]*/?>', '\n');
        html = html.replaceAll('(?i)</p>', '\n\n');
        html = html.replaceAll('(?i)</li>', '\n');
        html = html.replaceAll('(?i)<li[^>]*>', '- ');
        html = html.replaceAll('(?i)</ul>', '\n');
        html = html.replaceAll('(?i)</ol>', '\n');
        html = html.replaceAll('(?i)<strong>', '');
        html = html.replaceAll('(?i)</strong>', '');

        // Remove remaining tags
        html = html.replaceAll('<[^>]+>', '');

        // Clean up whitespace
        html = html.replaceAll('\\n{3,}', '\n\n');

        return html.trim();
    }

    /**
     * @description Parses a booking request from JSON
     * @param jsonString JSON representation of booking request
     * @return BookingRequest object
     */
    public static BookingRequest parseBookingRequestFromJson(String jsonString) {
        if (String.isBlank(jsonString)) {
            return new BookingRequest();
        }

        try {
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);

            BookingRequest request = new BookingRequest();

            // Parse dates
            String checkInStr = (String) jsonMap.get('checkInDate');
            String checkOutStr = (String) jsonMap.get('checkOutDate');

            if (String.isNotBlank(checkInStr)) {
                request.checkInDate = Date.valueOf(checkInStr);
            }
            if (String.isNotBlank(checkOutStr)) {
                request.checkOutDate = Date.valueOf(checkOutStr);
            }

            // Parse other fields
            request.numberOfRooms = jsonMap.get('totalRoomsRequested') != null ?
                Integer.valueOf(jsonMap.get('totalRoomsRequested')) : null;
            request.numberOfNights = jsonMap.get('numberOfNights') != null ?
                Integer.valueOf(jsonMap.get('numberOfNights')) : null;
            request.numberOfGuests = jsonMap.get('numberOfGuests') != null ?
                Integer.valueOf(jsonMap.get('numberOfGuests')) : null;
            request.guestName = (String) jsonMap.get('guestName');
            request.organizationName = (String) jsonMap.get('organizationName');
            request.roomTypePreference = (String) jsonMap.get('roomTypePreference');
            request.specialRequests = (String) jsonMap.get('specialRequests');

            // Extract first name if we have full name
            if (String.isNotBlank(request.guestName)) {
                request.guestFirstName = GmailMessageParser.extractFirstName(request.guestName);
            }

            return request;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error parsing booking request: ' + e.getMessage());
            return new BookingRequest();
        }
    }
}

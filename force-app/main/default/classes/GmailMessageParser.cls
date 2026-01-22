/**
 * @description Utility class for parsing Gmail message data
 * Extracts sender info, recipient email, and prepares data for processing
 */
public with sharing class GmailMessageParser {

    /**
     * @description Wrapper for parsed sender information
     */
    public class SenderInfo {
        public String email;
        public String name;
        public String firstName;

        public SenderInfo() {}
    }

    /**
     * @description Extracts the recipient email address from message headers
     * This is used to determine which Location the email was sent to
     * @param messageDetail The Gmail message detail object
     * @return The recipient email address
     */
    public static String extractRecipientEmail(GmailAPIService.GmailMessageDetail messageDetail) {
        if (messageDetail == null || messageDetail.headers == null) {
            return null;
        }

        // Check "to" header first
        String toHeader = messageDetail.headers.get('to');
        if (String.isNotBlank(toHeader)) {
            return parseEmailFromHeader(toHeader);
        }

        // Fallback to "delivered-to" header
        String deliveredTo = messageDetail.headers.get('delivered-to');
        if (String.isNotBlank(deliveredTo)) {
            return parseEmailFromHeader(deliveredTo);
        }

        return null;
    }

    /**
     * @description Extracts sender information from message headers
     * @param messageDetail The Gmail message detail object
     * @return SenderInfo with email, name, and first name
     */
    public static SenderInfo extractSenderInfo(GmailAPIService.GmailMessageDetail messageDetail) {
        SenderInfo info = new SenderInfo();

        if (messageDetail == null || messageDetail.headers == null) {
            return info;
        }

        String fromHeader = messageDetail.headers.get('from');
        if (String.isBlank(fromHeader)) {
            return info;
        }

        // Parse "Name <email@domain.com>" or just "email@domain.com"
        if (fromHeader.contains('<')) {
            // Format: "Display Name <email@domain.com>"
            Integer startBracket = fromHeader.indexOf('<');
            Integer endBracket = fromHeader.indexOf('>');

            if (startBracket > 0) {
                info.name = fromHeader.substring(0, startBracket).trim();
                // Remove quotes if present
                info.name = info.name.replace('"', '').trim();
            }

            if (startBracket >= 0 && endBracket > startBracket) {
                info.email = fromHeader.substring(startBracket + 1, endBracket).trim().toLowerCase();
            }
        } else {
            // Just email address
            info.email = fromHeader.trim().toLowerCase();
        }

        // Extract first name
        info.firstName = extractFirstName(info.name);

        return info;
    }

    /**
     * @description Extracts first name from full name
     * Handles various formats like "John Smith", "Dr. John Smith", "Smith, John"
     * @param fullName The full name string
     * @return The first name
     */
    public static String extractFirstName(String fullName) {
        if (String.isBlank(fullName)) {
            return null;
        }

        fullName = fullName.trim();

        // Remove common titles/prefixes
        List<String> titles = new List<String>{
            'Dr.', 'Dr', 'Mr.', 'Mr', 'Mrs.', 'Mrs', 'Ms.', 'Ms',
            'Prof.', 'Prof', 'Coach', 'Director', 'Manager'
        };

        for (String title : titles) {
            if (fullName.startsWithIgnoreCase(title + ' ')) {
                fullName = fullName.substring(title.length() + 1).trim();
                break;
            }
        }

        // Check for "Last, First" format
        if (fullName.contains(',')) {
            List<String> parts = fullName.split(',');
            if (parts.size() >= 2) {
                return parts[1].trim().split(' ')[0];
            }
        }

        // Standard "First Last" format - take first word
        List<String> parts = fullName.split(' ');
        if (!parts.isEmpty()) {
            return parts[0];
        }

        return fullName;
    }

    /**
     * @description Gets the email subject from headers
     * @param messageDetail The Gmail message detail object
     * @return The email subject
     */
    public static String getSubject(GmailAPIService.GmailMessageDetail messageDetail) {
        if (messageDetail == null || messageDetail.headers == null) {
            return null;
        }

        return messageDetail.headers.get('subject');
    }

    /**
     * @description Gets the email body text
     * @param messageDetail The Gmail message detail object
     * @return The email body
     */
    public static String getEmailBody(GmailAPIService.GmailMessageDetail messageDetail) {
        if (messageDetail == null) {
            return null;
        }

        return messageDetail.body;
    }

    /**
     * @description Gets the message date
     * @param messageDetail The Gmail message detail object
     * @return The message DateTime
     */
    public static DateTime getMessageDate(GmailAPIService.GmailMessageDetail messageDetail) {
        if (messageDetail == null || messageDetail.internalDate == null) {
            return null;
        }

        // internalDate is in milliseconds since epoch
        return DateTime.newInstance(messageDetail.internalDate);
    }

    /**
     * @description Parses an email address from a header value
     * Handles formats like "Name <email>" or just "email"
     * @param headerValue The header value string
     * @return The parsed email address in lowercase
     */
    private static String parseEmailFromHeader(String headerValue) {
        if (String.isBlank(headerValue)) {
            return null;
        }

        // Check for multiple recipients (comma-separated)
        // For now, just take the first one
        if (headerValue.contains(',')) {
            headerValue = headerValue.split(',')[0].trim();
        }

        // Check for "Name <email>" format
        if (headerValue.contains('<')) {
            Integer startBracket = headerValue.indexOf('<');
            Integer endBracket = headerValue.indexOf('>');

            if (startBracket >= 0 && endBracket > startBracket) {
                return headerValue.substring(startBracket + 1, endBracket).trim().toLowerCase();
            }
        }

        // Just email address
        return headerValue.trim().toLowerCase();
    }

    /**
     * @description Checks if an email appears to be a booking request
     * Uses simple heuristics to filter spam/non-booking emails
     * @param subject Email subject
     * @param body Email body
     * @return True if likely a booking request
     */
    public static Boolean isLikelyBookingRequest(String subject, String body) {
        if (String.isBlank(subject) && String.isBlank(body)) {
            return false;
        }

        String combined = (subject != null ? subject : '') + ' ' + (body != null ? body : '');
        combined = combined.toLowerCase();

        // Positive indicators
        List<String> bookingKeywords = new List<String>{
            'room', 'rooms', 'reservation', 'book', 'booking', 'stay',
            'check-in', 'check in', 'check-out', 'check out',
            'night', 'nights', 'guest', 'guests', 'team', 'group',
            'block', 'availability', 'rate', 'rates', 'quote'
        };

        Integer matchCount = 0;
        for (String keyword : bookingKeywords) {
            if (combined.contains(keyword)) {
                matchCount++;
            }
        }

        // Negative indicators (spam/auto-reply)
        List<String> spamKeywords = new List<String>{
            'unsubscribe', 'out of office', 'automatic reply',
            'auto-reply', 'delivery status', 'failed delivery',
            'mailer-daemon', 'postmaster'
        };

        for (String keyword : spamKeywords) {
            if (combined.contains(keyword)) {
                return false;
            }
        }

        // Need at least 2 booking-related keywords
        return matchCount >= 2;
    }

    /**
     * @description Creates the reply subject line
     * @param originalSubject The original email subject
     * @return Subject prefixed with "RE: " if not already
     */
    public static String createReplySubject(String originalSubject) {
        if (String.isBlank(originalSubject)) {
            return 'RE: Room Reservation Request';
        }

        // Check if already has RE: or Re: prefix
        if (originalSubject.startsWithIgnoreCase('RE:') ||
            originalSubject.startsWithIgnoreCase('Re:')) {
            return originalSubject;
        }

        return 'RE: ' + originalSubject;
    }
}

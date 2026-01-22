/**
 * @description Service class for Gmail API operations
 * Handles message listing, retrieval, and sending replies
 */
public with sharing class GmailAPIService {

    private static final String GMAIL_API_BASE = 'https://gmail.googleapis.com/gmail/v1/users/me';
    private static final Integer DEFAULT_TIMEOUT = 30000;

    /**
     * @description Wrapper for Gmail message metadata
     */
    public class GmailMessage {
        public String id;
        public String threadId;
        public String historyId;
        public List<String> labelIds;
    }

    /**
     * @description Wrapper for Gmail message details
     */
    public class GmailMessageDetail {
        public String id;
        public String threadId;
        public String historyId;
        public Map<String, String> headers;
        public String body;
        public String snippet;
        public Long internalDate;
    }

    /**
     * @description Result wrapper for list messages operation
     */
    public class ListMessagesResult {
        public Boolean success;
        public List<GmailMessage> messages;
        public String newHistoryId;
        public String errorMessage;
        public Integer resultSizeEstimate;

        public ListMessagesResult() {
            this.success = false;
            this.messages = new List<GmailMessage>();
        }
    }

    /**
     * @description Lists messages from Gmail inbox
     * @param accessToken OAuth access token
     * @param query Optional Gmail search query (e.g., "is:unread")
     * @param maxResults Maximum number of messages to return
     * @return ListMessagesResult containing messages or error
     */
    public static ListMessagesResult listMessages(String accessToken, String query, Integer maxResults) {
        ListMessagesResult result = new ListMessagesResult();

        try {
            String endpoint = GMAIL_API_BASE + '/messages';
            List<String> params = new List<String>();

            if (maxResults != null && maxResults > 0) {
                params.add('maxResults=' + maxResults);
            }
            if (String.isNotBlank(query)) {
                params.add('q=' + EncodingUtil.urlEncode(query, 'UTF-8'));
            }

            if (!params.isEmpty()) {
                endpoint += '?' + String.join(params, '&');
            }

            HttpRequest req = buildRequest(endpoint, 'GET', accessToken);
            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                result.success = true;
                result.resultSizeEstimate = (Integer) responseMap.get('resultSizeEstimate');

                List<Object> messagesJson = (List<Object>) responseMap.get('messages');
                if (messagesJson != null) {
                    for (Object msgObj : messagesJson) {
                        Map<String, Object> msgMap = (Map<String, Object>) msgObj;
                        GmailMessage msg = new GmailMessage();
                        msg.id = (String) msgMap.get('id');
                        msg.threadId = (String) msgMap.get('threadId');
                        result.messages.add(msg);
                    }
                }
            } else {
                result.errorMessage = 'List messages failed: ' + res.getStatusCode() + ' - ' + res.getBody();
            }

        } catch (Exception e) {
            result.errorMessage = 'Exception listing messages: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'Error listing messages: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description Gets full message details including body
     * @param accessToken OAuth access token
     * @param messageId Gmail message ID
     * @return GmailMessageDetail or null on error
     */
    public static GmailMessageDetail getMessage(String accessToken, String messageId) {
        try {
            String endpoint = GMAIL_API_BASE + '/messages/' + messageId + '?format=full';

            HttpRequest req = buildRequest(endpoint, 'GET', accessToken);
            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200) {
                return parseMessageDetail(res.getBody());
            } else {
                System.debug(LoggingLevel.ERROR, 'Get message failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Exception getting message: ' + e.getMessage());
        }

        return null;
    }

    /**
     * @description Parses the Gmail API message response
     * @param jsonBody The JSON response body
     * @return GmailMessageDetail with parsed data
     */
    private static GmailMessageDetail parseMessageDetail(String jsonBody) {
        GmailMessageDetail detail = new GmailMessageDetail();
        detail.headers = new Map<String, String>();

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

        detail.id = (String) responseMap.get('id');
        detail.threadId = (String) responseMap.get('threadId');
        detail.historyId = (String) responseMap.get('historyId');
        detail.snippet = (String) responseMap.get('snippet');

        // Parse internalDate - can be String or Long depending on JSON serialization
        Object internalDateObj = responseMap.get('internalDate');
        if (internalDateObj != null) {
            if (internalDateObj instanceof Long) {
                detail.internalDate = (Long) internalDateObj;
            } else if (internalDateObj instanceof Decimal) {
                detail.internalDate = ((Decimal) internalDateObj).longValue();
            } else if (internalDateObj instanceof String) {
                detail.internalDate = Long.valueOf((String) internalDateObj);
            }
        }

        // Parse payload
        Map<String, Object> payload = (Map<String, Object>) responseMap.get('payload');
        if (payload != null) {
            // Parse headers
            List<Object> headers = (List<Object>) payload.get('headers');
            if (headers != null) {
                for (Object headerObj : headers) {
                    Map<String, Object> header = (Map<String, Object>) headerObj;
                    String name = ((String) header.get('name')).toLowerCase();
                    String value = (String) header.get('value');
                    detail.headers.put(name, value);
                }
            }

            // Parse body - try to get plain text first, then HTML
            detail.body = extractBodyFromPayload(payload);
        }

        return detail;
    }

    /**
     * @description Extracts email body from Gmail payload structure
     * @param payload The payload object from Gmail API response
     * @return Decoded email body text
     */
    private static String extractBodyFromPayload(Map<String, Object> payload) {
        // First try to get body data directly
        Map<String, Object> body = (Map<String, Object>) payload.get('body');
        if (body != null) {
            String data = (String) body.get('data');
            if (String.isNotBlank(data)) {
                return decodeBase64Url(data);
            }
        }

        // If no direct body, check parts for multipart messages
        List<Object> parts = (List<Object>) payload.get('parts');
        if (parts != null) {
            // First pass: look for text/plain
            for (Object partObj : parts) {
                Map<String, Object> part = (Map<String, Object>) partObj;
                String mimeType = (String) part.get('mimeType');

                if (mimeType == 'text/plain') {
                    Map<String, Object> partBody = (Map<String, Object>) part.get('body');
                    if (partBody != null) {
                        String data = (String) partBody.get('data');
                        if (String.isNotBlank(data)) {
                            return decodeBase64Url(data);
                        }
                    }
                }

                // Check nested parts (for multipart/alternative)
                List<Object> nestedParts = (List<Object>) part.get('parts');
                if (nestedParts != null) {
                    String nestedBody = extractFromNestedParts(nestedParts, 'text/plain');
                    if (String.isNotBlank(nestedBody)) {
                        return nestedBody;
                    }
                }
            }

            // Second pass: look for text/html if no plain text
            for (Object partObj : parts) {
                Map<String, Object> part = (Map<String, Object>) partObj;
                String mimeType = (String) part.get('mimeType');

                if (mimeType == 'text/html') {
                    Map<String, Object> partBody = (Map<String, Object>) part.get('body');
                    if (partBody != null) {
                        String data = (String) partBody.get('data');
                        if (String.isNotBlank(data)) {
                            return stripHtml(decodeBase64Url(data));
                        }
                    }
                }

                // Check nested parts
                List<Object> nestedParts = (List<Object>) part.get('parts');
                if (nestedParts != null) {
                    String nestedBody = extractFromNestedParts(nestedParts, 'text/html');
                    if (String.isNotBlank(nestedBody)) {
                        return stripHtml(nestedBody);
                    }
                }
            }
        }

        return null;
    }

    /**
     * @description Extracts body from nested parts
     */
    private static String extractFromNestedParts(List<Object> parts, String targetMimeType) {
        for (Object partObj : parts) {
            Map<String, Object> part = (Map<String, Object>) partObj;
            String mimeType = (String) part.get('mimeType');

            if (mimeType == targetMimeType) {
                Map<String, Object> partBody = (Map<String, Object>) part.get('body');
                if (partBody != null) {
                    String data = (String) partBody.get('data');
                    if (String.isNotBlank(data)) {
                        return decodeBase64Url(data);
                    }
                }
            }
        }
        return null;
    }

    /**
     * @description Decodes base64url encoded string (Gmail format)
     * @param base64Url The base64url encoded string
     * @return Decoded string
     */
    private static String decodeBase64Url(String base64Url) {
        if (String.isBlank(base64Url)) {
            return null;
        }

        // Convert base64url to standard base64
        String base64 = base64Url.replace('-', '+').replace('_', '/');

        // Add padding if needed
        Integer padding = Math.mod(4 - Math.mod(base64.length(), 4), 4);
        if (padding != 4) {
            base64 += '='.repeat(padding);
        }

        try {
            Blob decoded = EncodingUtil.base64Decode(base64);
            return decoded.toString();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error decoding base64: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Strips HTML tags from text
     * @param html HTML content
     * @return Plain text
     */
    private static String stripHtml(String html) {
        if (String.isBlank(html)) {
            return null;
        }

        // Remove script and style elements
        html = html.replaceAll('(?i)<script[^>]*>[\\s\\S]*?</script>', '');
        html = html.replaceAll('(?i)<style[^>]*>[\\s\\S]*?</style>', '');

        // Replace common HTML elements with appropriate text
        html = html.replaceAll('(?i)<br[^>]*>', '\n');
        html = html.replaceAll('(?i)</p>', '\n\n');
        html = html.replaceAll('(?i)</div>', '\n');
        html = html.replaceAll('(?i)</li>', '\n');

        // Remove remaining HTML tags
        html = html.replaceAll('<[^>]+>', '');

        // Decode HTML entities
        html = html.replace('&nbsp;', ' ');
        html = html.replace('&amp;', '&');
        html = html.replace('&lt;', '<');
        html = html.replace('&gt;', '>');
        html = html.replace('&quot;', '"');
        html = html.replace('&#39;', '\'');

        // Clean up whitespace
        html = html.replaceAll('[ \\t]+', ' ');
        html = html.replaceAll('\\n{3,}', '\n\n');

        return html.trim();
    }

    /**
     * @description Sends a reply email in a thread
     * @param accessToken OAuth access token
     * @param threadId Gmail thread ID to reply to
     * @param toAddress Recipient email address
     * @param subject Email subject (typically "RE: original subject")
     * @param bodyHtml HTML body of the reply
     * @param fromEmail The sender email address
     * @return True if sent successfully
     */
    public static Boolean sendReply(
        String accessToken,
        String threadId,
        String toAddress,
        String subject,
        String bodyHtml,
        String fromEmail
    ) {
        try {
            String endpoint = GMAIL_API_BASE + '/messages/send';

            // Build MIME message
            String mimeMessage = buildMimeMessage(fromEmail, toAddress, subject, bodyHtml, threadId);
            String encodedMessage = EncodingUtil.base64Encode(Blob.valueOf(mimeMessage))
                .replace('+', '-')
                .replace('/', '_')
                .replace('=', '');

            // Build request body
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('raw', encodedMessage);
            requestBody.put('threadId', threadId);

            HttpRequest req = buildRequest(endpoint, 'POST', accessToken);
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestBody));

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200) {
                System.debug('Email sent successfully');
                return true;
            } else {
                System.debug(LoggingLevel.ERROR, 'Send reply failed: ' + res.getStatusCode() + ' - ' + res.getBody());
                return false;
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Exception sending reply: ' + e.getMessage());
            return false;
        }
    }

    /**
     * @description Builds a MIME message for sending
     */
    private static String buildMimeMessage(
        String fromEmail,
        String toEmail,
        String subject,
        String bodyHtml,
        String threadId
    ) {
        String boundary = '----=_Part_' + String.valueOf(DateTime.now().getTime());

        String message = '';
        message += 'From: ' + fromEmail + '\r\n';
        message += 'To: ' + toEmail + '\r\n';
        message += 'Subject: ' + subject + '\r\n';
        message += 'MIME-Version: 1.0\r\n';
        message += 'Content-Type: multipart/alternative; boundary="' + boundary + '"\r\n';
        message += '\r\n';

        // Plain text version
        String plainText = stripHtml(bodyHtml);
        message += '--' + boundary + '\r\n';
        message += 'Content-Type: text/plain; charset="UTF-8"\r\n';
        message += 'Content-Transfer-Encoding: quoted-printable\r\n';
        message += '\r\n';
        message += plainText + '\r\n';

        // HTML version
        message += '--' + boundary + '\r\n';
        message += 'Content-Type: text/html; charset="UTF-8"\r\n';
        message += 'Content-Transfer-Encoding: quoted-printable\r\n';
        message += '\r\n';
        message += bodyHtml + '\r\n';

        message += '--' + boundary + '--\r\n';

        return message;
    }

    /**
     * @description Marks a message as read
     * @param accessToken OAuth access token
     * @param messageId Gmail message ID
     * @return True if successful
     */
    public static Boolean markAsRead(String accessToken, String messageId) {
        try {
            String endpoint = GMAIL_API_BASE + '/messages/' + messageId + '/modify';

            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('removeLabelIds', new List<String>{ 'UNREAD' });

            HttpRequest req = buildRequest(endpoint, 'POST', accessToken);
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestBody));

            HttpResponse res = new Http().send(req);
            return res.getStatusCode() == 200;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Exception marking as read: ' + e.getMessage());
            return false;
        }
    }

    /**
     * @description Gets history list for incremental sync
     * @param accessToken OAuth access token
     * @param startHistoryId Starting history ID
     * @return ListMessagesResult with new messages
     */
    public static ListMessagesResult getHistoryList(String accessToken, String startHistoryId) {
        ListMessagesResult result = new ListMessagesResult();

        try {
            String endpoint = GMAIL_API_BASE + '/history?startHistoryId=' + startHistoryId +
                             '&historyTypes=messageAdded&labelId=INBOX';

            HttpRequest req = buildRequest(endpoint, 'GET', accessToken);
            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                result.success = true;
                result.newHistoryId = (String) responseMap.get('historyId');

                List<Object> historyList = (List<Object>) responseMap.get('history');
                if (historyList != null) {
                    Set<String> processedIds = new Set<String>();

                    for (Object historyObj : historyList) {
                        Map<String, Object> historyMap = (Map<String, Object>) historyObj;
                        List<Object> messagesAdded = (List<Object>) historyMap.get('messagesAdded');

                        if (messagesAdded != null) {
                            for (Object msgAddedObj : messagesAdded) {
                                Map<String, Object> msgAdded = (Map<String, Object>) msgAddedObj;
                                Map<String, Object> msgMap = (Map<String, Object>) msgAdded.get('message');

                                if (msgMap != null) {
                                    String msgId = (String) msgMap.get('id');
                                    if (!processedIds.contains(msgId)) {
                                        processedIds.add(msgId);

                                        GmailMessage msg = new GmailMessage();
                                        msg.id = msgId;
                                        msg.threadId = (String) msgMap.get('threadId');
                                        result.messages.add(msg);
                                    }
                                }
                            }
                        }
                    }
                }
            } else if (res.getStatusCode() == 404) {
                // History ID is too old, need full sync
                result.success = false;
                result.errorMessage = 'History ID expired, full sync required';
            } else {
                result.errorMessage = 'Get history failed: ' + res.getStatusCode() + ' - ' + res.getBody();
            }

        } catch (Exception e) {
            result.errorMessage = 'Exception getting history: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'Error getting history: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description Builds an HTTP request with authorization
     */
    private static HttpRequest buildRequest(String endpoint, String method, String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setTimeout(DEFAULT_TIMEOUT);
        return req;
    }
}

/**
 * @description Flow-invocable action to find or create Account and Contact records
 * Creates Account from organization name and Contact from guest details
 */
public with sharing class FindOrCreateAccountContactAction {

    /**
     * @description Input parameters for the invocable action
     */
    public class Input {
        @InvocableVariable(label='Organization Name' description='The organization/company name for the Account' required=false)
        public String organizationName;

        @InvocableVariable(label='Guest Name' description='Full name of the guest for the Contact' required=true)
        public String guestName;

        @InvocableVariable(label='Email Address' description='Email address of the guest' required=true)
        public String emailAddress;

        @InvocableVariable(label='Event Name' description='Name of the event/booking' required=false)
        public String eventName;

        @InvocableVariable(label='Phone Number' description='Phone number of the guest' required=false)
        public String phoneNumber;
    }

    /**
     * @description Output results from the invocable action
     */
    public class Output {
        @InvocableVariable(label='Account ID' description='ID of the found or created Account')
        public Id accountId;

        @InvocableVariable(label='Contact ID' description='ID of the found or created Contact')
        public Id contactId;

        @InvocableVariable(label='Account Name' description='Name of the Account')
        public String accountName;

        @InvocableVariable(label='Contact Name' description='Full name of the Contact')
        public String contactName;

        @InvocableVariable(label='Account Created' description='True if a new Account was created')
        public Boolean accountCreated;

        @InvocableVariable(label='Contact Created' description='True if a new Contact was created')
        public Boolean contactCreated;

        @InvocableVariable(label='Success' description='True if operation was successful')
        public Boolean success;

        @InvocableVariable(label='Error Message' description='Error message if operation failed')
        public String errorMessage;
    }

    /**
     * @description Invocable method to find or create Account and Contact
     * @param inputs List of Input objects
     * @return List of Output objects with Account and Contact IDs
     */
    @InvocableMethod(label='Find or Create Account and Contact' description='Finds existing or creates new Account and Contact records for booking' category='Email Processing')
    public static List<Output> findOrCreateAccountContact(List<Input> inputs) {
        List<Output> results = new List<Output>();

        for (Input input : inputs) {
            Output output = new Output();
            output.accountCreated = false;
            output.contactCreated = false;

            try {
                // Parse the guest name
                NameParts nameParts = parseGuestName(input.guestName);

                // Step 1: Find or create Account
                Account acct = findOrCreateAccount(input.organizationName, input.guestName);
                output.accountId = acct.Id;
                output.accountName = acct.Name;
                output.accountCreated = (acct.CreatedDate == System.now().date() ||
                                         acct.CreatedDate == null); // Approximate check for new record

                // Step 2: Find or create Contact
                Contact cont = findOrCreateContact(acct.Id, nameParts, input.emailAddress, input.phoneNumber);
                output.contactId = cont.Id;
                output.contactName = cont.FirstName + ' ' + cont.LastName;
                output.contactCreated = (cont.CreatedDate == System.now().date() ||
                                         cont.CreatedDate == null);

                output.success = true;

            } catch (Exception e) {
                output.success = false;
                output.errorMessage = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'FindOrCreateAccountContactAction error: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }

            results.add(output);
        }

        return results;
    }

    /**
     * @description Finds an existing Account by name or creates a new one
     * @param organizationName The organization name to search for
     * @param guestName Fallback name if no organization
     * @return Account record (existing or newly created)
     */
    private static Account findOrCreateAccount(String organizationName, String guestName) {
        String accountName = String.isNotBlank(organizationName) ? organizationName : guestName;

        // Try to find existing Account by exact name match
        List<Account> existingAccounts = [
            SELECT Id, Name, CreatedDate
            FROM Account
            WHERE Name = :accountName
            LIMIT 1
        ];

        if (!existingAccounts.isEmpty()) {
            System.debug('Found existing Account: ' + existingAccounts[0].Id);
            return existingAccounts[0];
        }

        // Create new Account
        Account newAccount = new Account(
            Name = accountName,
            Type = 'Customer'
        );
        insert newAccount;

        System.debug('Created new Account: ' + newAccount.Id + ' with name: ' + accountName);
        return newAccount;
    }

    /**
     * @description Finds an existing Contact or creates a new one
     * @param accountId The Account ID to associate the Contact with
     * @param nameParts Parsed name components
     * @param email Email address to search/set
     * @param phone Phone number to set
     * @return Contact record (existing or newly created)
     */
    private static Contact findOrCreateContact(Id accountId, NameParts nameParts, String email, String phone) {
        // Try to find existing Contact by email first
        if (String.isNotBlank(email)) {
            List<Contact> contactsByEmail = [
                SELECT Id, FirstName, LastName, Email, AccountId, CreatedDate
                FROM Contact
                WHERE Email = :email
                LIMIT 1
            ];

            if (!contactsByEmail.isEmpty()) {
                Contact existingContact = contactsByEmail[0];

                // If the Contact is not linked to any Account, link it
                if (existingContact.AccountId == null) {
                    existingContact.AccountId = accountId;
                    update existingContact;
                }

                System.debug('Found existing Contact by email: ' + existingContact.Id);
                return existingContact;
            }
        }

        // Try to find by name and Account
        List<Contact> contactsByName = [
            SELECT Id, FirstName, LastName, Email, AccountId, CreatedDate
            FROM Contact
            WHERE FirstName = :nameParts.firstName
            AND LastName = :nameParts.lastName
            AND AccountId = :accountId
            LIMIT 1
        ];

        if (!contactsByName.isEmpty()) {
            Contact existingContact = contactsByName[0];

            // Update email if not set
            if (String.isBlank(existingContact.Email) && String.isNotBlank(email)) {
                existingContact.Email = email;
                update existingContact;
            }

            System.debug('Found existing Contact by name: ' + existingContact.Id);
            return existingContact;
        }

        // Create new Contact
        Contact newContact = new Contact(
            FirstName = nameParts.firstName,
            LastName = nameParts.lastName,
            Email = email,
            Phone = phone,
            AccountId = accountId
        );
        insert newContact;

        System.debug('Created new Contact: ' + newContact.Id + ' for ' + nameParts.firstName + ' ' + nameParts.lastName);
        return newContact;
    }

    /**
     * @description Helper class to hold parsed name parts
     */
    private class NameParts {
        public String firstName;
        public String lastName;
    }

    /**
     * @description Parses a full name into first and last name components
     * @param fullName The full name to parse
     * @return NameParts with firstName and lastName
     */
    private static NameParts parseGuestName(String fullName) {
        NameParts parts = new NameParts();

        if (String.isBlank(fullName)) {
            parts.firstName = 'Unknown';
            parts.lastName = 'Guest';
            return parts;
        }

        fullName = fullName.trim();

        // Handle common formats
        List<String> nameParts = fullName.split('\\s+');

        if (nameParts.size() == 1) {
            // Single name - use as last name
            parts.firstName = '';
            parts.lastName = nameParts[0];
        } else if (nameParts.size() == 2) {
            // First Last
            parts.firstName = nameParts[0];
            parts.lastName = nameParts[1];
        } else {
            // Multiple parts - first word is first name, rest is last name
            parts.firstName = nameParts[0];
            // Build the last name from remaining parts
            List<String> lastNameParts = new List<String>();
            for (Integer i = 1; i < nameParts.size(); i++) {
                lastNameParts.add(nameParts[i]);
            }
            parts.lastName = String.join(lastNameParts, ' ');
        }

        return parts;
    }
}

/**
 * @description Batch class to migrate existing Email_Processing_Log__c records
 * Groups them by Thread_Id__c and creates corresponding Email_Thread__c records
 *
 * Usage:
 * Database.executeBatch(new EmailThreadMigration(), 200);
 */
public with sharing class EmailThreadMigration implements Database.Batchable<SObject>, Database.Stateful {

    // Counters for tracking progress
    private Integer threadsCreated = 0;
    private Integer logsUpdated = 0;
    private Integer errors = 0;

    /**
     * @description Start method - query all Email_Processing_Log__c records without Email_Thread__c
     * @param bc BatchableContext
     * @return QueryLocator for batch processing
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Thread_Id__c, Sender_Email__c, Sender_Name__c, Subject__c,
                   Location__c, CreatedDate, Email_Thread__c
            FROM Email_Processing_Log__c
            WHERE Email_Thread__c = null
            AND Thread_Id__c != null
            ORDER BY Thread_Id__c, CreatedDate
        ]);
    }

    /**
     * @description Execute method - process batch of logs, group by Thread_Id__c
     * @param bc BatchableContext
     * @param scope List of Email_Processing_Log__c records to process
     */
    public void execute(Database.BatchableContext bc, List<Email_Processing_Log__c> scope) {
        // Group logs by Thread_Id__c
        Map<String, List<Email_Processing_Log__c>> logsByThread = new Map<String, List<Email_Processing_Log__c>>();

        for (Email_Processing_Log__c log : scope) {
            if (String.isBlank(log.Thread_Id__c)) {
                continue;
            }

            if (!logsByThread.containsKey(log.Thread_Id__c)) {
                logsByThread.put(log.Thread_Id__c, new List<Email_Processing_Log__c>());
            }
            logsByThread.get(log.Thread_Id__c).add(log);
        }

        // Check which threads already exist
        Set<String> threadIds = logsByThread.keySet();
        Map<String, Email_Thread__c> existingThreads = new Map<String, Email_Thread__c>();

        for (Email_Thread__c thread : [
            SELECT Id, Thread_Id__c
            FROM Email_Thread__c
            WHERE Thread_Id__c IN :threadIds
        ]) {
            existingThreads.put(thread.Thread_Id__c, thread);
        }

        // Create new threads and collect logs to update
        List<Email_Thread__c> threadsToInsert = new List<Email_Thread__c>();
        Map<String, Email_Thread__c> newThreadsByThreadId = new Map<String, Email_Thread__c>();

        for (String threadId : logsByThread.keySet()) {
            if (existingThreads.containsKey(threadId)) {
                continue; // Thread already exists
            }

            List<Email_Processing_Log__c> threadLogs = logsByThread.get(threadId);
            Email_Processing_Log__c firstLog = threadLogs[0];
            Email_Processing_Log__c lastLog = threadLogs[threadLogs.size() - 1];

            // Find first log by CreatedDate (oldest)
            DateTime firstDate = firstLog.CreatedDate;
            DateTime lastDate = lastLog.CreatedDate;
            for (Email_Processing_Log__c log : threadLogs) {
                if (log.CreatedDate < firstDate) {
                    firstLog = log;
                    firstDate = log.CreatedDate;
                }
                if (log.CreatedDate > lastDate) {
                    lastLog = log;
                    lastDate = log.CreatedDate;
                }
            }

            Email_Thread__c newThread = new Email_Thread__c(
                Thread_Id__c = threadId,
                Sender_Email__c = firstLog.Sender_Email__c,
                Sender_Name__c = firstLog.Sender_Name__c,
                Thread_Subject__c = firstLog.Subject__c,
                Location__c = firstLog.Location__c,
                First_Email_Date__c = firstDate,
                Last_Email_Date__c = lastDate,
                Thread_Status__c = 'Active'
            );

            threadsToInsert.add(newThread);
            newThreadsByThreadId.put(threadId, newThread);
        }

        // Insert new threads
        if (!threadsToInsert.isEmpty()) {
            try {
                insert threadsToInsert;
                threadsCreated += threadsToInsert.size();

                // Add newly created threads to existing map
                for (Email_Thread__c thread : threadsToInsert) {
                    existingThreads.put(thread.Thread_Id__c, thread);
                }
            } catch (Exception e) {
                errors++;
                System.debug(LoggingLevel.ERROR, 'Error inserting threads: ' + e.getMessage());
            }
        }

        // Update logs with Email_Thread__c reference
        List<Email_Processing_Log__c> logsToUpdate = new List<Email_Processing_Log__c>();

        for (String threadId : logsByThread.keySet()) {
            Email_Thread__c thread = existingThreads.get(threadId);
            if (thread == null) {
                continue;
            }

            for (Email_Processing_Log__c log : logsByThread.get(threadId)) {
                log.Email_Thread__c = thread.Id;
                logsToUpdate.add(log);
            }
        }

        if (!logsToUpdate.isEmpty()) {
            try {
                update logsToUpdate;
                logsUpdated += logsToUpdate.size();
            } catch (Exception e) {
                errors++;
                System.debug(LoggingLevel.ERROR, 'Error updating logs: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Finish method - log final results
     * @param bc BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('EmailThreadMigration completed:');
        System.debug('  Threads created: ' + threadsCreated);
        System.debug('  Logs updated: ' + logsUpdated);
        System.debug('  Errors: ' + errors);
    }
}

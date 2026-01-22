/**
 * @description Queueable class for Gmail polling that allows HTTP callouts
 * Scheduled Apex cannot make callouts directly, so we use this Queueable
 */
public with sharing class GmailPollingQueueable implements Queueable, Database.AllowsCallouts {

    private String connectionDeveloperName;

    /**
     * @description Constructor for processing all active connections
     */
    public GmailPollingQueueable() {
        this.connectionDeveloperName = null;
    }

    /**
     * @description Constructor for processing a specific connection
     * @param connectionDeveloperName The developer name of the connection to process
     */
    public GmailPollingQueueable(String connectionDeveloperName) {
        this.connectionDeveloperName = connectionDeveloperName;
    }

    /**
     * @description Execute method called by the Queueable framework
     * @param context The QueueableContext
     */
    public void execute(QueueableContext context) {
        if (String.isNotBlank(connectionDeveloperName)) {
            // Process single connection
            GmailPollingScheduler.processSingleConnection(connectionDeveloperName);
        } else {
            // Process all active connections
            processAllConnections();
        }
    }

    /**
     * @description Processes all active Gmail connections
     * Chains additional Queueables for each connection to handle callout limits
     */
    private void processAllConnections() {
        try {
            List<Gmail_Connection__mdt> connections = GmailOAuthService.getActiveConnections();

            if (connections.isEmpty()) {
                System.debug('No active Gmail connections found');
                return;
            }

            // Process first connection in this job
            if (!connections.isEmpty()) {
                Gmail_Connection__mdt firstConnection = connections[0];
                try {
                    GmailPollingScheduler.processSingleConnection(firstConnection.DeveloperName);
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'Error processing connection ' +
                        firstConnection.DeveloperName + ': ' + e.getMessage());
                    logErrorToState(firstConnection.DeveloperName, e.getMessage());
                }

                // Chain next connection if there are more
                if (connections.size() > 1) {
                    List<Gmail_Connection__mdt> remainingConnections = new List<Gmail_Connection__mdt>();
                    for (Integer i = 1; i < connections.size(); i++) {
                        remainingConnections.add(connections[i]);
                    }
                    // Enqueue next connection
                    if (!remainingConnections.isEmpty() && !Test.isRunningTest()) {
                        System.enqueueJob(new GmailPollingQueueable(remainingConnections[0].DeveloperName));
                    }
                }
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in Gmail polling queueable: ' + e.getMessage());
        }
    }

    /**
     * @description Logs an error to the state record
     */
    private void logErrorToState(String devName, String errorMessage) {
        try {
            Gmail_Connection_State__c state = GmailOAuthService.getState(devName);
            if (state != null) {
                state.Last_Error_Message__c = 'Queueable error: ' + errorMessage;
                state.Poll_In_Progress__c = false;
                update state;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to log error to state: ' + e.getMessage());
        }
    }
}

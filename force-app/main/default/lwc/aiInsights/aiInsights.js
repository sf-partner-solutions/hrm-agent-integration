import { LightningElement, track } from 'lwc';
import AMADEUS_LOGO from '@salesforce/resourceUrl/AmadeusLogo';

export default class AiInsights extends LightningElement {
    @track mockLeads = [];
    @track propertyMessages = [];
    amadeusLogo = AMADEUS_LOGO;
    lastUpdated = '';

    connectedCallback() {
        this.initializeMockData();
        this.updateLastUpdatedTime();
        // Simulate real-time updates
        this.startAutoRefresh();
    }

    disconnectedCallback() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }
    }

    initializeMockData() {
        // Mock leads/inquiries data - Corporate events that hotels typically handle
        this.mockLeads = [
            {
                id: 'lead001',
                company: 'Salesforce.com',
                eventName: 'Global Sales Summit 2026',
                dates: 'Mar 15-18, 2026',
                attendees: '450',
                value: '$285,000',
                priority: 'HOT',
                variant: 'error',
                daysUntilEvent: 45
            },
            {
                id: 'lead002',
                company: 'American Medical Association',
                eventName: 'Annual Medical Conference',
                dates: 'Apr 22-25, 2024',
                attendees: '800',
                value: '$520,000',
                priority: 'HIGH',
                variant: 'warning',
                daysUntilEvent: 82
            },
            {
                id: 'lead003',
                company: 'Fortune 500 Finance Group',
                eventName: 'Executive Leadership Retreat',
                dates: 'May 10-12, 2024',
                attendees: '125',
                value: '$145,000',
                priority: 'MEDIUM',
                variant: 'success',
                daysUntilEvent: 100
            }
        ];

        // Mock property messages for Westin Washington DC
        this.propertyMessages = [
            {
                id: 'msg001',
                type: 'VIP Alert',
                icon: 'standard:campaign',
                iconVariant: 'warning',
                title: 'Senator arriving tomorrow',
                content: 'Senator Elizabeth Warren will be checking in tomorrow at 3 PM for the Policy Forum. Please ensure Presidential Suite 2801 is ready with fresh flowers and the requested dietary accommodations.',
                time: '30 min ago',
                hasAction: true,
                actionLabel: 'View Preferences'
            },
            {
                id: 'msg002',
                type: 'Operations Update',
                icon: 'standard:service_resource',
                iconVariant: 'error',
                title: 'Grand Ballroom maintenance scheduled',
                content: 'The Grand Ballroom will undergo lighting system upgrade on Feb 28-29. Please do not book any events in this space. Alternative venues: Capitol Ballroom or Jefferson Hall.',
                time: '2 hours ago',
                hasAction: true,
                actionLabel: 'Check Calendar'
            },
            {
                id: 'msg003',
                type: 'Revenue Alert',
                icon: 'standard:currency',
                iconVariant: 'success',
                title: 'Cherry Blossom Festival - High demand period',
                content: 'Room rates have been dynamically adjusted for March 20 - April 14 due to Cherry Blossom Festival. Current occupancy forecast: 94%. Upselling opportunities available for suite upgrades.',
                time: '5 hours ago',
                hasAction: false
            },
            {
                id: 'msg004',
                type: 'Staff Notice',
                icon: 'standard:people',
                iconVariant: 'info',
                title: 'New concierge service partnership',
                content: 'We\'ve partnered with DC Tours Premium for exclusive White House and Capitol tours for our guests. Training session Thursday at 2 PM in the Madison Conference Room.',
                time: '1 day ago',
                hasAction: true,
                actionLabel: 'Register'
            }
        ];
    }

    updateLastUpdatedTime() {
        const now = new Date();
        const timeString = now.toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
        });
        this.lastUpdated = `${timeString}`;
    }

    startAutoRefresh() {
        // Refresh data every 5 minutes
        this.refreshInterval = setInterval(() => {
            this.updateLastUpdatedTime();
            // In a real implementation, this would fetch new data from AI service
            this.simulateDataUpdate();
        }, 300000); // 5 minutes
    }

    simulateDataUpdate() {
        // Randomly update lead priorities or values to simulate real-time changes
        const leadIndex = Math.floor(Math.random() * this.mockLeads.length);
        const updatedLeads = [...this.mockLeads];

        // Simulate priority change
        const priorities = ['HOT', 'HIGH', 'MEDIUM'];
        const variants = ['error', 'warning', 'success'];
        const randomPriorityIndex = Math.floor(Math.random() * priorities.length);

        updatedLeads[leadIndex] = {
            ...updatedLeads[leadIndex],
            priority: priorities[randomPriorityIndex],
            variant: variants[randomPriorityIndex]
        };

        this.mockLeads = updatedLeads;
    }

    handleViewLead(event) {
        const leadId = event.target.dataset.leadId;
        // In production, this would navigate to the lead record
        console.log('Viewing lead:', leadId);
        // Example navigation (would need proper implementation):
        // this[NavigationMixin.Navigate]({
        //     type: 'standard__recordPage',
        //     attributes: {
        //         recordId: leadId,
        //         actionName: 'view'
        //     }
        // });
    }

    handleMessageAction(event) {
        const messageId = event.target.dataset.messageId;
        // Handle message action
        console.log('Message action for:', messageId);
    }
}
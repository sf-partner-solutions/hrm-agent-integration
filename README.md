# Fdesdo - Employee PTO & Agentforce Integration Platform

> **Disclaimer**: This project was generated using generative AI. Please ensure it meets your specific requirements and security standards before deploying to production environments.

A comprehensive Salesforce Lightning Web Component (LWC) application that provides Employee Goals service integration, PTO (Paid Time Off) management, and Agentforce AI capabilities. This platform empowers employees to manage their time off requests and access intelligent automation through custom Agentforce functions.

## 🎯 Project Overview

The Fdesdo platform is a multi-functional Salesforce application designed to streamline employee services and demonstrate Agentforce integration capabilities. It includes custom Lightning Web Components, Apex controllers, and Agentforce functions for PTO balance checking and request scheduling.

## ✨ Key Features

### PTO Management System
- **PTO Balance Checking**: Real-time PTO balance retrieval for logged-in users via Agentforce
- **PTO Request Scheduling**: Interactive date selector for scheduling new PTO requests
- **HRM Integration**: Direct integration links to external HRM system
- **Visual Feedback**: Modern UI with responsive date pickers and confirmation messages

### Agentforce Integration
- **Get PTO Balance**: AI-powered function to retrieve current PTO balance
- **Select PTO Request**: Intelligent PTO scheduling with conversational AI
- **Custom Agent Responses**: Dynamic HTML responses with partner branding
- **Progress Indicators**: Real-time feedback during AI function execution

### Custom Components
- **Card Data Selector**: Date range picker with automatic day calculation
- **Card Response Logo**: Branded response cards with partner logos
- **Flight Details**: Travel-related functionality components
- **API Login**: Secure authentication interface for external APIs
- **Job Counter**: Background job monitoring component

### In-App Guidance
- **Agentforce Promotion Prompt**: Floating panel promoting Partner Agentforce Suite
- **Contextual Messaging**: Profile-based prompt targeting
- **Custom Branding**: Themed prompts with configurable colors and images

## 🏗️ Technical Architecture

### Components Structure

#### Lightning Web Components (LWC)
1. **cardDataSelector** - PTO date selection and scheduling interface
2. **cardReponseLogo** - Branded response card with partner logo
3. **flightDetails** - Flight information display component
4. **apiLogin** - External API authentication UI
5. **jobCounter** - Asynchronous job status monitor

#### Apex Controllers
1. **CardResponseLogoController.cls** - PTO balance retrieval logic
2. **CardDataSelectorController.cls** - PTO request scheduling logic
3. **ApiLoginController.cls** - External API authentication handler
4. **AgentResponse1.cls** - Agentforce response formatting

#### Agentforce Functions
1. **Get_PTO_Balance** - Retrieves current PTO balance for logged-in user
   - Invocation Target: CardResponseLogoController
   - Type: Apex
   - Progress Message: "Checking PTO Balance"

2. **Select_PTO_for_Ueer** - Initiates PTO request selection
   - Invocation Target: CardDataSelectorController
   - Type: Apex
   - No confirmation required

3. **HTML_ISV_Agent_Response_16** - Custom HTML response formatting

#### Custom Objects
- **Agent_Response__c** - Stores agent response templates
- **API_Token__c** - Manages external API authentication tokens
- **Integration_Setting__mdt** - Custom metadata for integration configuration

#### Prompts
- **TryourAgentforceIntegration** - In-app promotional prompt for Agentforce features
  - Display Type: Floating Panel
  - Position: Middle Center
  - Target: Admin profiles on API Login page
  - Theme: Dark, Theme1 color

### File Structure

```
force-app/main/default/
├── classes/
│   ├── CardResponseLogoController.cls
│   ├── CardDataSelectorController.cls
│   ├── ApiLoginController.cls
│   ├── AgentResponse1.cls
│   └── [100+ utility and service classes]
├── lwc/
│   ├── cardDataSelector/
│   │   ├── cardDataSelector.html
│   │   ├── cardDataSelector.js
│   │   ├── cardDataSelector.css
│   │   └── cardDataSelector.js-meta.xml
│   ├── cardReponseLogo/
│   ├── flightDetails/
│   ├── apiLogin/
│   └── jobCounter/
├── genAiFunctions/
│   ├── Get_PTO_Balance/
│   │   ├── input/schema.json
│   │   ├── output/schema.json
│   │   └── Get_PTO_Balance.genAiFunction-meta.xml
│   ├── Select_PTO_for_Ueer/
│   │   ├── input/schema.json
│   │   ├── output/schema.json
│   │   └── Select_PTO_for_Ueer.genAiFunction-meta.xml
│   └── HTML_ISV_Agent_Response_16/
├── prompts/
│   └── TryourAgentforceIntegration.prompt-meta.xml
├── objects/
│   ├── Agent_Response__c/
│   ├── API_Token__c/
│   └── Integration_Setting__mdt/
├── namedCredentials/
├── externalCredentials/
├── remoteSiteSettings/
├── flexipages/
├── tabs/
└── triggers/
```

## 🚀 Installation & Deployment

### Prerequisites

- Salesforce CLI installed and authenticated
- Access to a Salesforce org with Agentforce enabled (Sandbox or Developer Edition recommended)
- Basic knowledge of Salesforce Lightning App Builder
- Agentforce licenses (for AI functionality)

### Quick Deployment

1. **Clone the repository**

   ```bash
   git clone https://github.com/rreboucas/reboucasfdesdo.git
   cd reboucasfdesdo
   ```

2. **Authenticate to your Salesforce org**

   ```bash
   sf org login web --alias myorg
   ```

3. **Deploy all metadata**

   ```bash
   sf project deploy start --target-org myorg
   ```

4. **Deploy specific components (alternative)**

   ```bash
   # Deploy Apex classes
   sf project deploy start --source-dir force-app/main/default/classes --target-org myorg

   # Deploy LWC components
   sf project deploy start --source-dir force-app/main/default/lwc --target-org myorg

   # Deploy Agentforce functions
   sf project deploy start --source-dir force-app/main/default/genAiFunctions --target-org myorg

   # Deploy prompts
   sf project deploy start --source-dir force-app/main/default/prompts --target-org myorg
   ```

### Post-Deployment Configuration

1. **Create Agent_Response__c records**
   - Navigate to Setup → Object Manager → Agent_Response__c
   - Create records with Agent_Response_Number__c = 1 and 2
   - Add appropriate HTML response content in Response__c field

2. **Configure External API Authentication**
   - Set up Named Credentials for external system integration
   - Create API_Token__c records for authenticated users

3. **Enable Agentforce Functions**
   - Navigate to Setup → Agentforce
   - Activate the "Get PTO Balance" and "Select PTO for Ueer" functions
   - Associate functions with your Agentforce agent

4. **Add Components to Pages**
   - Use Lightning App Builder to add LWC components to relevant pages
   - Configure component properties as needed

## 🎮 Usage

### Checking PTO Balance (via Agentforce)

1. **Open Agentforce** in your Salesforce org
2. **Ask**: "What's my PTO balance?" or "Check my time off balance"
3. **View Response**: Agentforce executes the Get_PTO_Balance function and displays your balance

### Scheduling PTO Request

1. **Open Agentforce** or navigate to a page with the Card Data Selector component
2. **Ask**: "I want to request PTO" or use the visual interface
3. **Select Dates**: Choose start and end dates using the date pickers
4. **Review**: See calculated number of days automatically
5. **Schedule**: Click "Schedule" button to submit request
6. **Confirmation**: View confirmation message with scheduled days
7. **Optional**: Click "View in HRM" to manage in external system

### Using In-App Guidance

1. **Navigate** to the API Login page
2. **View Prompt**: If you're an Admin, the Agentforce Integration promotional prompt appears
3. **Take Action**: Click "Try Now" to explore Partner Agentforce Suite
4. **Dismiss**: Or dismiss the prompt if not interested

## 📝 Component Details

### Card Data Selector

**Features:**
- Start and end date pickers
- Automatic day calculation (inclusive of both dates)
- Disabled submit button until both dates selected
- Confirmation screen with scheduled day count
- Integration link to external HRM system
- Custom events for parent component communication

**Events Dispatched:**
- `schedule` - Fired when PTO is scheduled (includes startDate, endDate, days)
- `viewHRM` - Fired when "View in HRM" is clicked

### Card Response Logo

**Features:**
- Displays partner logo from static resources
- Shows dynamic response text from Agent_Response__c records
- Filters out HTML tags for clean text display
- Retrieves user-specific responses

## 🧪 Testing

Run the test suite to ensure everything is working correctly:

```bash
# Run all tests
sf apex run test --target-org myorg --wait 10

# Run specific test classes
sf apex run test --tests ApiLoginControllerTest --target-org myorg
sf apex run test --tests CardDataSelectorController --target-org myorg

# View test results
sf apex get test --test-run-id <run-id> --target-org myorg
```

## 🔧 Customization

### Adding New PTO Response Messages

Edit the Agent_Response__c records:

```sql
-- Query existing responses
SELECT Agent_Response_Number__c, Response__c FROM Agent_Response__c

-- Update response content via Salesforce UI or Data Loader
```

### Customizing Date Selector Styling

Modify [cardDataSelector.css](force-app/main/default/lwc/cardDataSelector/cardDataSelector.css):

```css
/* Example: Change button colors */
.schedule-button {
    background-color: #0176d3;
    color: white;
}
```

### Adding New Agentforce Functions

1. Create new Apex invocable method
2. Create genAiFunction metadata XML
3. Define input/output schemas in JSON
4. Deploy and activate in Agentforce setup

### Modifying In-App Prompts

Edit [TryourAgentforceIntegration.prompt-meta.xml](force-app/main/default/prompts/TryourAgentforceIntegration.prompt-meta.xml):

```xml
<title>Your Custom Title</title>
<body>Your custom message</body>
<actionButtonLink>https://your-link.com</actionButtonLink>
```

## 📋 Requirements

- **Salesforce API Version**: 64.0+
- **Salesforce Edition**: Enterprise, Unlimited, or Developer Edition
- **Agentforce**: Licenses required for AI functions
- **Browser Support**: Modern browsers supporting Lightning Web Components
- **Permissions**: Users need access to custom objects and components

## 🔍 Key Functionalities Summary

### Employee Services
- ✅ PTO balance checking
- ✅ PTO request scheduling
- ✅ Date range calculation
- ✅ HRM integration links
- ✅ User-specific response retrieval

### Agentforce AI
- ✅ Natural language PTO balance queries
- ✅ Conversational PTO request scheduling
- ✅ Custom HTML agent responses
- ✅ Progress indicators during execution
- ✅ Partner branding integration

### Developer Tools
- ✅ 100+ utility Apex classes
- ✅ CSV data import capabilities
- ✅ Time shifting batch jobs
- ✅ Wave Analytics integration
- ✅ B2B commerce utilities
- ✅ Community/Experience Cloud controllers
- ✅ Metadata service utilities

### Integration Capabilities
- ✅ External API authentication
- ✅ Named credentials support
- ✅ Remote site settings
- ✅ Custom metadata configuration
- ✅ Token management

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 🆘 Support & Troubleshooting

### Common Issues

**Agentforce functions not appearing:**
- Verify Agentforce is enabled in your org
- Check that genAiFunction metadata is deployed
- Ensure Apex controllers are accessible
- Verify function activation in Agentforce setup

**PTO balance not loading:**
- Check Agent_Response__c records exist with correct Agent_Response_Number__c
- Verify current user has created response records
- Review debug logs for query errors

**Component not appearing in Lightning App Builder:**
- Ensure metadata file has `isExposed="true"`
- Verify target configuration matches page type
- Check component deployment status

**Date selector not working:**
- Verify browser JavaScript is enabled
- Check console for errors
- Ensure LWC is properly deployed

**External API integration failing:**
- Verify Named Credentials are configured
- Check API_Token__c records exist
- Review Remote Site Settings
- Check external system connectivity

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Contact

Repository: [https://github.com/rreboucas/reboucasfdesdo](https://github.com/rreboucas/reboucasfdesdo)

---

**Built for modern employee services with Agentforce AI** ⚡

_Last updated: October 2025_

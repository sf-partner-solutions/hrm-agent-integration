/*
 * Copyright 2022 salesforce.com, inc.
 * All Rights Reserved
 * Company Confidential
 * Version: 2.0 - Updated to use storeAuthTokenString method
 */

import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import initiateApiLogin from '@salesforce/apex/MulesoftIntegrationService.initiateApiLogin';
import checkApiConnection from '@salesforce/apex/MulesoftIntegrationService.checkApiConnection';
import disconnectApi from '@salesforce/apex/MulesoftIntegrationService.disconnectApi';
import storeTokenSimple from '@salesforce/apex/MulesoftIntegrationService.storeTokenSimple';

export default class ApiLogin extends LightningElement {
    
    logoUrl = '/resource/partnerLogo'; // Adjust the path if needed
    textValue = 'API Integration'; // Default text
    
    @track isConnected = false;
    @track isConnecting = false;
    @track authWindow = null;
    @track pollInterval = null;
    @track authSessionId = null;
    
    @api
    get value() {
        return this._value;
    }
    
    /**
     * @param {} value
     */
    set value(value) {
        this._value = value;
    }

    connectedCallback() {
        console.log('=== LWC CONNECTED CALLBACK ===');
        
        // Check if API is already connected when component loads
        this.checkConnectionStatus();
        
        // Store bound handler for proper cleanup
        this._boundPostMessage = this.handlePostMessage.bind(this);
        
        // Listen for messages from the popup window
        console.log('Adding window message event listener...');
        window.addEventListener('message', this._boundPostMessage);
        console.log('Message event listener added successfully');
        
        // Test that the message listener is working
        console.log('Current window location:', window.location.href);
        
        // Test postMessage handling after a short delay
        setTimeout(() => {
            console.log('Testing postMessage handler...');
            // Send a test message to ourselves to verify the handler works
            window.postMessage({
                type: 'TEST_MESSAGE',
                data: 'Testing message handler'
            }, window.location.origin);
        }, 1000);
    }

    disconnectedCallback() {
        // Clean up event listener properly
        if (this._boundPostMessage) {
            window.removeEventListener('message', this._boundPostMessage);
            this._boundPostMessage = null;
        }
        
        // Clear any timeouts or intervals
        if (this.popupCheckInterval) {
            clearInterval(this.popupCheckInterval);
            this.popupCheckInterval = null;
        }
        
        if (this.authTimeout) {
            clearTimeout(this.authTimeout);
            this.authTimeout = null;
        }
        
        // Close popup if still open
        if (this.authWindow && !this.authWindow.closed) {
            this.authWindow.close();
            this.authWindow = null;
        }
    }

    // Check if the API is already connected
    async checkConnectionStatus() {
        try {
            const result = await checkApiConnection();
            this.isConnected = result.isConnected;
        } catch (error) {
            console.error('Error checking connection status:', error);
            this.showToast('Error', 'Failed to check connection status', 'error');
        }
    }

    // Show initial form or connected state
    get showInitialForm() {
        return !this.isConnected && !this.isConnecting;
    }

    get showConnectedState() {
        return this.isConnected && !this.isConnecting;
    }

    get connectedText() {
        return 'API Connected';
    }

    // Handle Connect button click
    async handleConnect() {
        console.log('=== CONNECT BUTTON CLICKED ===');
        this.isConnecting = true;
        
        try {
            // Generate a unique session ID for this auth attempt
            this.authSessionId = Date.now().toString();
            console.log('Generated auth session ID:', this.authSessionId);
            
            // Call Apex method to initiate login and get auth URL
            console.log('Calling initiateApiLogin...');
            const result = await initiateApiLogin();
            console.log('initiateApiLogin result:', result);
            
            if (result.success) {
                // Open popup window for OAuth flow
                const authUrl = result.authUrl;
                console.log('Opening popup with URL:', authUrl);
                const windowFeatures = 'width=500,height=600,scrollbars=yes,resizable=yes';
                
                this.authWindow = window.open(authUrl, 'apiAuth', windowFeatures);
                console.log('Popup window opened:', this.authWindow ? 'SUCCESS' : 'FAILED');
                
                // Check if popup was blocked
                if (!this.authWindow) {
                    throw new Error('Popup blocked. Please allow popups for this site.');
                }
                
                // Monitor popup window (no polling - only postMessage)
                console.log('Starting popup monitoring...');
                this.monitorPopup();
                
                // Add timeout to prevent infinite loading (5 minutes)
                console.log('Setting authentication timeout (5 minutes)...');
                this.authTimeout = setTimeout(() => {
                    if (this.isConnecting) {
                        console.log('Authentication timeout - no response received after 5 minutes');
                        this.handleAuthError('Authentication timed out. Please try again.');
                    }
                }, 300000); // 5 minutes
                
            } else {
                throw new Error(result.message || 'Failed to initiate authentication');
            }
        } catch (error) {
            console.error('Error initiating connection:', error);
            this.showToast('Error', error.message || 'Failed to connect to API', 'error');
            this.isConnecting = false;
        }
    }

    // Monitor the popup window
    monitorPopup() {
        console.log('=== MONITOR POPUP STARTED ===');
        
        // Clear any existing interval
        if (this.popupCheckInterval) {
            clearInterval(this.popupCheckInterval);
        }
        
        this.popupCheckInterval = setInterval(() => {
            if (!this.authWindow || this.authWindow.closed) {
                console.log('Popup window detected as closed');
                clearInterval(this.popupCheckInterval);
                this.popupCheckInterval = null;
                
                // If window closed without success message, assume cancelled
                if (this.isConnecting) {
                    console.log('Popup window closed without authentication completion');
                    this.isConnecting = false;
                    this.authWindow = null;
                    this.showToast('Info', 'Authentication cancelled', 'info');
                }
            } else {
                // Log that popup is still open (every 10 seconds to avoid spam)
                const now = Date.now();
                if (!this.lastPopupLog || (now - this.lastPopupLog) > 10000) {
                    console.log('Popup window still open, waiting for postMessage...');
                    this.lastPopupLog = now;
                }
            }
        }, 1000);
    }

    // Stop all authentication polling and monitoring
    stopAuthPolling() {
        // Clear popup monitoring interval
        if (this.popupCheckInterval) {
            clearInterval(this.popupCheckInterval);
            this.popupCheckInterval = null;
        }
        
        // Clear authentication timeout
        if (this.authTimeout) {
            clearTimeout(this.authTimeout);
            this.authTimeout = null;
        }
        
        // Clear any other polling intervals (legacy)
        if (this.pollInterval) {
            clearInterval(this.pollInterval);
            this.pollInterval = null;
        }
        
        console.log('All authentication polling stopped');
    }

    // Handle messages from popup window
    handlePostMessage(event) {
        console.log('=== PostMessage received ===');
        console.log('Event origin:', event.origin);
        console.log('Event data:', event.data);
        console.log('Event source:', event.source);

        // Temporary: Allow all origins for debugging
        console.log('Processing message from origin:', event.origin);

        // More permissive check during debugging
        if (event.origin && !event.origin.includes('herokuapp.com')) {
            console.log('Origin rejected - not from herokuapp. Got:', event.origin);
            return;
        }

        try {
            let data = event.data;
            console.log('Raw postMessage data:', data);
            console.log('Data type:', typeof data);

            // Parse JSON string if needed
            if (typeof data === 'string') {
                try {
                    data = JSON.parse(data);
                    console.log('Parsed JSON data:', data);
                } catch (parseError) {
                    console.error('Failed to parse JSON data:', parseError);
                    this.handleAuthError('Invalid JSON format in authentication response');
                    return;
                }
            }

            console.log('Processing postMessage data:', data);

            if (data && data.type === 'API_AUTH_SUCCESS') {
                console.log('=== SUCCESS MESSAGE RECEIVED ===');
                console.log('Token:', data.token ? 'PROVIDED' : 'MISSING');
                console.log('User ID:', data.userId);
                console.log('Client ID:', data.clientId);
                console.log('Refresh Token:', data.refresh_token ? 'PROVIDED' : 'MISSING');

                // Stop polling to prevent conflicts
                this.stopAuthPolling();

                // Handle success
                this.handleAuthSuccessWithToken(data.token, data.userId);

            } else if (data && data.type === 'API_AUTH_ERROR') {
                console.log('Error message received:', data.error);
                this.handleAuthError(data.error);
            } else if (data && data.type === 'API_AUTH_CANCELLED') {
                console.log('Authentication cancelled by user');
                this.handleAuthError('Authentication was cancelled');
            } else if (data && data.type === 'TEST_MESSAGE') {
                console.log('✅ TEST MESSAGE RECEIVED - PostMessage handler is working!');
                console.log('Test data:', data.data);
            } else {
                console.log('Unknown or missing message type:', data ? data.type : 'NO DATA');
                console.log('Full data object:', data);
            }
        } catch (error) {
            console.error('Error handling post message:', error);
            console.error('Error stack:', error.stack);
            this.handleAuthError('Failed to process authentication response');
        }
    }

    // Handle successful authentication with both tokens from postMessage
    async handleAuthSuccessWithTokens(accessToken, refreshToken, userId, clientId) {
        console.log('=== handleAuthSuccessWithTokens called ===');
        console.log('Access token received:', accessToken ? 'YES' : 'NO');
        console.log('Refresh token received:', refreshToken ? 'YES' : 'NO');
        console.log('User ID received:', userId);
        console.log('Client ID received:', clientId);
        
        try {
            // Stop popup monitoring and timeout
            if (this.popupCheckInterval) {
                clearInterval(this.popupCheckInterval);
                this.popupCheckInterval = null;
            }
            
            if (this.authTimeout) {
                clearTimeout(this.authTimeout);
                this.authTimeout = null;
            }
            
            // Close popup window with delay to ensure postMessage is processed
            if (this.authWindow && !this.authWindow.closed) {
                setTimeout(() => {
                    if (this.authWindow && !this.authWindow.closed) {
                        this.authWindow.close();
                    }
                    this.authWindow = null;
                }, 500); // Small delay to ensure postMessage is fully processed
            }

            console.log('=== ATTEMPTING CORRECTED @AURAENABLED APPROACH ===');
            console.log('Access token to be stored:', accessToken ? accessToken.substring(0, 20) + '...' : 'NONE');
            console.log('Refresh token to be stored:', refreshToken ? refreshToken.substring(0, 20) + '...' : 'NONE');
            console.log('User ID passed as parameter:', userId);
            console.log('Client ID passed as parameter:', clientId);
            
            // Call the method with named parameters object (LWC requirement)
            const result = await storeTokenSimple({ 
                accessToken: accessToken || '', 
                refreshToken: refreshToken || '', 
                userId: userId,
                clientId: clientId || userId  // Use clientId from API response, fallback to userId
            });
            
            console.log('Method result:', result);
            
            if (result?.success) {
                // Update the UI state
                this.isConnecting = false;
                this.isConnected = true;
                
                this.showToast('Success', 'API connected successfully', 'success');
                
                // Dispatch custom event for parent component
                const connectEvent = new CustomEvent('apiconnected', {
                    detail: {
                        connected: true,
                        timestamp: new Date().toISOString()
                    }
                });
                this.dispatchEvent(connectEvent);
            } else {
                throw new Error(result?.message || 'Failed to store token');
            }
            
        } catch (error) {
            console.error('Error handling auth success with tokens:', error);
            console.error('Error details:', JSON.stringify(error, null, 2));
            
            let errorMessage = 'Failed to complete authentication';
            if (error && error.message) {
                errorMessage += ': ' + error.message;
            } else if (typeof error === 'string') {
                errorMessage += ': ' + error;
            } else {
                errorMessage += ': Unknown error occurred';
            }
            
            this.handleAuthError(errorMessage);
        }
    }

    // Handle successful authentication with token from postMessage (legacy method)
    async handleAuthSuccessWithToken(token, userId) {
        console.log('=== handleAuthSuccessWithToken called ===');
        console.log('Token received:', token ? 'YES' : 'NO');
        console.log('User ID received:', userId);

        // Prevent double-processing
        if (!this.isConnecting) {
            console.log('Not currently connecting, ignoring duplicate success message');
            return;
        }
        
        try {
            // Close popup window FIRST
            if (this.authWindow && !this.authWindow.closed) {
                console.log('Closing popup window');
                this.authWindow.close();
                this.authWindow = null;
            }

            // Stop any polling IMMEDIATELY
            this.stopAuthPolling();

            // Parse token data if it's a JSON object, otherwise treat as string
            let accessToken = '';
            let refreshToken = '';
            
            try {
                if (typeof token === 'string' && token.startsWith('{')) {
                    // Token is a JSON string, parse it
                    const tokenData = JSON.parse(token);
                    accessToken = tokenData.access_token || tokenData.accessToken || token;
                    refreshToken = tokenData.refresh_token || tokenData.refreshToken || '';
                    console.log('Parsed token data:', { accessToken: accessToken ? 'PROVIDED' : 'MISSING', refreshToken: refreshToken ? 'PROVIDED' : 'MISSING' });
                } else if (typeof token === 'object' && token !== null) {
                    // Token is already an object
                    accessToken = token.access_token || token.accessToken || String(token);
                    refreshToken = token.refresh_token || token.refreshToken || '';
                    console.log('Token object data:', { accessToken: accessToken ? 'PROVIDED' : 'MISSING', refreshToken: refreshToken ? 'PROVIDED' : 'MISSING' });
                } else {
                    // Token is a simple string
                    accessToken = String(token || '');
                    console.log('Simple token string provided');
                }
            } catch (parseError) {
                console.warn('Token parsing failed, using as simple string:', parseError);
                accessToken = String(token || '');
            }
            
            console.log('=== ATTEMPTING CORRECTED @AURAENABLED APPROACH ===');
            console.log('Access token to be stored:', accessToken.substring(0, 20) + '...');
            console.log('Refresh token to be stored:', refreshToken ? refreshToken.substring(0, 20) + '...' : 'NONE');
            console.log('User ID passed as parameter:', userId);
            
            // Call the method with named parameters object (LWC requirement)
            const result = await storeTokenSimple({ 
                accessToken: accessToken, 
                refreshToken: refreshToken, 
                userId: userId,
                clientId: userId  // Use userId as clientId for legacy method
            });
            
            console.log('Method result:', result);
            
            if (result?.success) {
                // Update the UI state
                this.isConnecting = false;
                this.isConnected = true;
                
                this.showToast('Success', 'API connected successfully', 'success');
                
                // Dispatch custom event for parent component
                const connectEvent = new CustomEvent('apiconnected', {
                    detail: {
                        connected: true,
                        timestamp: new Date().toISOString()
                    }
                });
                this.dispatchEvent(connectEvent);
            } else {
                throw new Error(result?.message || 'Failed to store token');
            }
            
        } catch (error) {
            console.error('Error handling auth success with token:', error);
            console.error('Error details:', JSON.stringify(error, null, 2));
            
            let errorMessage = 'Failed to complete authentication';
            if (error && error.message) {
                errorMessage += ': ' + error.message;
            } else if (typeof error === 'string') {
                errorMessage += ': ' + error;
            } else {
                errorMessage += ': Unknown error occurred';
            }
            
            this.handleAuthError(errorMessage);
        }
    }



    // Handle successful authentication (polling-based)
    async handleAuthSuccess(token = null) {
        try {
            // Close popup window
            if (this.authWindow && !this.authWindow.closed) {
                this.authWindow.close();
                this.authWindow = null;
            }

            // Stop any polling - N/A since we removed polling

            // The token should already be stored by the Apex controller via polling
            // Just update the UI state
            this.isConnecting = false;
            this.isConnected = true;
            
            this.showToast('Success', 'API connected successfully', 'success');
            
            // Dispatch custom event for parent component
            const connectEvent = new CustomEvent('apiconnected', {
                detail: {
                    connected: true,
                    timestamp: new Date().toISOString()
                }
            });
            this.dispatchEvent(connectEvent);
            
        } catch (error) {
            console.error('Error handling auth success:', error);
            this.handleAuthError('Failed to complete authentication');
        }
    }

    // Handle authentication error
    handleAuthError(errorMessage) {
        // Stop all polling and monitoring
        this.stopAuthPolling();
        
        // Close popup window
        if (this.authWindow && !this.authWindow.closed) {
            this.authWindow.close();
            this.authWindow = null;
        }

        this.isConnecting = false;
        this.showToast('Error', errorMessage || 'Authentication failed', 'error');
    }

    // Handle Cancel button click during authentication
    handleCancel() {
        console.log('Authentication cancelled by user');
        this.handleAuthError('Authentication cancelled by user');
    }

    // Handle Disconnect button click
    async handleDisconnect() {
        try {
            const result = await disconnectApi();
            
            if (result.success) {
                this.isConnected = false;
                this.showToast('Success', 'API disconnected successfully', 'success');
                
                // Dispatch custom event for parent component
                const disconnectEvent = new CustomEvent('apidisconnected', {
                    detail: {
                        connected: false,
                        timestamp: new Date().toISOString()
                    }
                });
                this.dispatchEvent(disconnectEvent);
            } else {
                throw new Error(result.message || 'Failed to disconnect');
            }
        } catch (error) {
            console.error('Error disconnecting:', error);
            this.showToast('Error', error.message || 'Failed to disconnect from API', 'error');
        }
    }


    // Show toast message
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}
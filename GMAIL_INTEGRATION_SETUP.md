# Gmail Integration Setup Guide

## Prerequisites: Google Account Preparation

Before creating OAuth credentials, you must establish trust with Google to avoid account blocks.

### If Your Account Was Blocked

1. **Do NOT create a new account immediately** - Google may flag your IP address
2. **Dispute the block right away**:
   - Follow instructions on the "Account Blocked" screen
   - Complete SMS verification if prompted
   - If asked for a reason: *"I am a developer setting up a personal project to test the Gmail API for my own use."*
3. **If appeal is rejected**: Wait 24 hours and use a different internet connection (mobile data) when creating a new account

### "Season" the Account (Critical for New/Recovered Accounts)

Fresh Google accounts have low trust scores. Before attempting OAuth setup:

1. **Log in via a standard browser** (NOT Incognito) and keep the tab open
2. **Send 2-3 manual emails** to your personal address and reply to them
3. **Change a Gmail setting** - update the theme or add a signature (this generates "human activity" logs)

### Add Security Verification

These are major trust signals for Google:

1. **Add a Recovery Email** (your main personal email)
2. **Add a Recovery Phone Number**
3. **Enable 2-Step Verification (2FA)** - This is the single biggest trust signal

---

## Step 1: Create OAuth Credentials in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select or create a project
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID**
5. Select **Web application** as the application type
6. Add an **Authorized redirect URI**: `https://developers.google.com/oauthplayground`
7. Click **Create** and save the **Client ID** and **Client Secret**

---

## Step 2: Enable the Gmail API

1. In Google Cloud Console, go to **APIs & Services** → **Library**
2. Search for **Gmail API**
3. Click **Enable**

---

## Step 3: Generate the Refresh Token

### Important: Browser Setup

**Do NOT use Incognito mode** - it prevents Google from reading trust cookies.

Instead:
1. Open a **normal browser window**
2. **Log into Gmail** with the account you're configuring (e.g., `ashworth.reservations@gmail.com`)
3. Keep that tab open
4. Open a **new tab in the same browser window** for the OAuth Playground

### OAuth Playground Steps

1. Go to [Google OAuth Playground](https://developers.google.com/oauthplayground/) in your new tab
2. Click the **gear icon** (⚙️) in the top right
3. Check **Use your own OAuth credentials**
4. Enter your **Client ID** and **Client Secret** from Step 1
5. Close the settings panel

### Gradual Authorization (Recommended to Avoid Blocks)

If you get blocked requesting all permissions at once, use this approach:

**First Pass - Read Only:**
1. In the left panel, find **Gmail API v1**
2. Select only: `https://www.googleapis.com/auth/gmail.readonly`
3. Click **Authorize APIs**
4. Sign in and grant permissions
5. Click **Exchange authorization code for tokens**
6. Verify it works (this establishes trust between your Project and Account)

**Second Pass - Full Permissions:**
1. Go back to Step 1 in OAuth Playground
2. Select all three scopes:
   - `https://www.googleapis.com/auth/gmail.readonly`
   - `https://www.googleapis.com/auth/gmail.send`
   - `https://www.googleapis.com/auth/gmail.modify`
3. Click **Authorize APIs**
4. Grant all permissions
5. Click **Exchange authorization code for tokens**
6. **Copy the Refresh Token** from the response

---

## Step 4: Configure Custom Metadata in Salesforce

1. In Salesforce Setup, go to **Custom Metadata Types**
2. Find **Gmail Connection** and click **Manage Records**
3. Create a new record with:

| Field | Value |
|-------|-------|
| Label | e.g., `Ashworth Reservations` |
| Developer Name | e.g., `Ashworth_Reservations` |
| Client_Id__c | Your Google Client ID |
| Client_Secret__c | Your Google Client Secret |
| Refresh_Token__c | The refresh token from Step 3 |
| Mailbox_Email__c | The Gmail address (e.g., `ashworth.reservations@gmail.com`) |
| Is_Active__c | `true` |
| Location_Id__c | (if applicable) |

---

## Step 5: Verify Remote Site Settings

Ensure these Remote Site Settings exist in Salesforce Setup → Remote Site Settings:

| Name | URL |
|------|-----|
| Google_OAuth | `https://oauth2.googleapis.com` |
| Gmail_API | `https://gmail.googleapis.com` |

---

## Step 6: Test the Integration

Run this in Developer Console → Debug → Open Execute Anonymous Window:

```apex
GmailOAuthService.TokenRefreshResult result =
    GmailOAuthService.refreshAccessToken('Ashworth_Reservations');
System.debug('Success: ' + result.success);
System.debug('Token: ' + (result.accessToken != null ? 'Retrieved' : 'NULL'));
System.debug('Error: ' + result.errorMessage);
```

---

## Step 7: Schedule Gmail Polling

```apex
// Schedule to run every 5 minutes
String cronExp = '0 0/5 * * * ?';
GmailPollingScheduler scheduler = new GmailPollingScheduler();
System.schedule('Gmail Polling Job', cronExp, scheduler);
```

---

## Quick Reference Checklist

Before OAuth Playground:
- [ ] Account recovered/unblocked (if applicable)
- [ ] 2-Step Verification enabled
- [ ] Recovery email and phone added
- [ ] Sent a few manual emails
- [ ] Changed a Gmail setting (theme/signature)
- [ ] Logged into Gmail in a normal browser (NOT Incognito)
- [ ] OAuth Playground opened in same browser window

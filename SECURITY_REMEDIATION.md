# Security Remediation Guide

## ⚠️ CRITICAL: Credentials That Must Be Rotated Immediately

This document outlines all hardcoded credentials that were exposed in the codebase and **MUST** be rotated before making this repository public.

---

## 🔴 HIGH PRIORITY: OAuth Credentials to Rotate

### 1. Connected App OAuth Credentials

**Status:** EXPOSED IN SOURCE CODE - ROTATE IMMEDIATELY

The following OAuth credentials were hardcoded in 3 different files and have been removed:

- **Client ID:** `***REMOVED***`
- **Client Secret:** `***REMOVED***`

**Files Previously Containing These Credentials:**
- `force-app/main/default/classes/SDO_Service_ArticleRecommendationsHelper.cls` (Line 224-225)
- `force-app/main/default/classes/SDO_Tool_Insights_InsightGeneratorCtrl.cls` (Line 54-55)
- `force-app/main/default/classes/SDO_Tool_EMC_BehaviorScoringController.cls` (Line 60-61)

**Action Required:**

1. **Regenerate Connected App Client Secret**
   - Navigate to: Setup → App Manager → Find the Connected App
   - Click "View" → "Manage Consumer Details"
   - Click "Regenerate Secret"
   - Save the new secret securely

2. **Consider Rotating Client ID (Optional but Recommended)**
   - Create a new Connected App with OAuth settings
   - Update all integrations to use the new Client ID
   - Deactivate the old Connected App

---

### 2. User Passwords to Change

**Status:** EXPOSED IN SOURCE CODE - CHANGE IMMEDIATELY

The following passwords were hardcoded and must be changed:

| User | Password Exposed | Files |
|------|------------------|-------|
| Integration User (alias: 'ehelp') | `***REMOVED***` | SDO_Service_ArticleRecommendationsHelper.cls:227 |
| Integration User (alias: 'euser') | `***REMOVED***` | SDO_Tool_Insights_InsightGeneratorCtrl.cls:57<br>SDO_Tool_EMC_BehaviorScoringController.cls:63 |

**Action Required:**

1. **Change Password for 'ehelp' User**
   ```sql
   SELECT Id, Username, Alias FROM User WHERE Alias = 'ehelp' OR CommunityNickname = 'ehelp'
   OR (FirstName = 'Einstein' AND LastName = 'Helper')
   ```
   - Change password in Salesforce Setup → Users
   - Update any external systems using this password

2. **Change Password for 'euser' User**
   ```sql
   SELECT Id, Username, Alias FROM User WHERE Alias = 'euser' OR CommunityNickname = 'euser'
   ```
   - Change password in Salesforce Setup → Users
   - Update any external systems using this password

3. **Enable Two-Factor Authentication**
   - Enable 2FA for both integration users for additional security

---

### 3. Email Address Exposure

**Status:** REMOVED - VERIFY USAGE

The following email was hardcoded and has been removed:

- **Email:** `***REMOVED***`
- **File:** `force-app/main/default/classes/DBM25Controller.cls` (Line 12)

**Action Required:**

1. **Review Email Usage**
   - Check if this email is still in use for notifications
   - Consider creating a dedicated notification email if needed

2. **Implement Custom Metadata**
   - Create Custom Metadata Type: `DBM_Configuration`
   - Add field: `Notification_Email__c`
   - Store email in Custom Metadata instead of code

---

## 🔄 Code Changes Summary

The following files have been refactored to remove hardcoded credentials:

### Files Modified

1. **SDO_Service_ArticleRecommendationsHelper.cls**
   - ✅ Removed hardcoded Client ID and Secret
   - ✅ Removed hardcoded password
   - ✅ Added SecurityException with setup instructions
   - ⚠️ Method now throws exception until Named Credential is configured

2. **SDO_Tool_Insights_InsightGeneratorCtrl.cls**
   - ✅ Removed hardcoded Client ID and Secret
   - ✅ Removed hardcoded password
   - ✅ Added SecurityException with setup instructions
   - ⚠️ Method now throws exception until Named Credential is configured

3. **SDO_Tool_EMC_BehaviorScoringController.cls**
   - ✅ Removed hardcoded Client ID and Secret
   - ✅ Removed hardcoded password
   - ✅ Added SecurityException with setup instructions
   - ⚠️ Method now throws exception until Named Credential is configured

4. **DBM25Controller.cls**
   - ✅ Removed hardcoded email address
   - ✅ Added helper method for Custom Metadata retrieval
   - ⚠️ Returns empty string until Custom Metadata is configured

5. **SDO_Pardot_ImportDataFromCSVController.cls**
   - ✅ Changed public OAuth properties to private
   - ✅ Added security warnings
   - ⚠️ Still needs complete refactoring to use Named Credentials

---

## 📋 Setup Instructions for Named Credentials

### Step 1: Create External Credential

1. Navigate to: **Setup → Named Credentials → External Credentials**
2. Click **"New"**
3. Configure:
   - **Label:** Einstein Integration Credential
   - **Name:** Einstein_Integration_Credential
   - **Authentication Protocol:** OAuth 2.0
   - **Authentication Flow Type:** Password

4. Add Authentication Parameters:
   - **Client ID:** [Your NEW Client ID]
   - **Client Secret:** [Your NEW Client Secret]
   - **Username:** [Integration User Username]
   - **Password:** [Integration User NEW Password]
   - **Token Endpoint URL:** `https://login.salesforce.com/services/oauth2/token`

5. Click **"Save"**

### Step 2: Create Named Credential

1. Navigate to: **Setup → Named Credentials → Named Credentials**
2. Click **"New"**
3. Configure:
   - **Label:** Einstein Integration
   - **Name:** Einstein_Integration
   - **URL:** `https://login.salesforce.com`
   - **External Credential:** Einstein_Integration_Credential
   - **Enabled for Callouts:** ✓ Checked

4. Click **"Save"**

### Step 3: Create Permission Set

1. Create Permission Set with access to Named Credential
2. Assign to users who need Einstein integration access

### Step 4: Update Code (Future Enhancement)

Replace the current SecurityException code with proper Named Credential callouts:

```apex
public static String getSession(){
    HttpRequest request = new HttpRequest();
    // Use Named Credential - credentials managed securely by Salesforce
    request.setEndpoint('callout:Einstein_Integration/services/oauth2/token?grant_type=password');
    request.setMethod('POST');

    HttpResponse res = (new Http()).send(request);
    Map<String,Object> session = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
    return String.valueOf(session.get('access_token'));
}
```

---

## 🔐 Security Best Practices Going Forward

### 1. Pre-Commit Hooks
Consider implementing git pre-commit hooks to scan for secrets:

```bash
# Install git-secrets
brew install git-secrets

# Initialize in repo
git secrets --install
git secrets --register-aws
git secrets --add 'client_secret'
git secrets --add 'password.*='
```

### 2. Code Review Checklist
Before committing code, verify:
- [ ] No hardcoded passwords or API keys
- [ ] No OAuth Client IDs or Secrets
- [ ] No email addresses (except generic ones like noreply@)
- [ ] No connection strings with embedded credentials
- [ ] All credentials use Named Credentials or Custom Metadata

### 3. Regular Security Audits
- Run security scans quarterly
- Review all Named Credentials access
- Rotate credentials annually (at minimum)
- Monitor API usage for anomalies

### 4. CI/CD Integration
Add secret scanning to your CI/CD pipeline:
- GitHub: Use GitHub Secret Scanning
- GitLab: Use GitLab Secret Detection
- Custom: Use tools like Gitleaks or TruffleHog

---

## 📊 Remediation Checklist

Use this checklist to track your security remediation progress:

- [ ] **Rotate Connected App Client Secret**
  - [ ] Generate new secret in Connected App
  - [ ] Document new secret securely (password manager)
  - [ ] Test with new secret

- [ ] **Change Integration User Passwords**
  - [ ] Change password for 'ehelp' user
  - [ ] Change password for 'euser' user
  - [ ] Enable 2FA for both users
  - [ ] Document new passwords securely

- [ ] **Optional: Rotate Client ID**
  - [ ] Create new Connected App
  - [ ] Test with new Client ID
  - [ ] Deactivate old Connected App

- [ ] **Setup Named Credentials**
  - [ ] Create External Credential
  - [ ] Create Named Credential
  - [ ] Test Named Credential connection
  - [ ] Create and assign Permission Sets

- [ ] **Code Updates**
  - [ ] Refactor SDO_Service_ArticleRecommendationsHelper.cls
  - [ ] Refactor SDO_Tool_Insights_InsightGeneratorCtrl.cls
  - [ ] Refactor SDO_Tool_EMC_BehaviorScoringController.cls
  - [ ] Refactor SDO_Pardot_ImportDataFromCSVController.cls
  - [ ] Create Custom Metadata for DBM25Controller

- [ ] **Git History Cleanup**
  - [ ] Backup repository
  - [ ] Use BFG Repo-Cleaner to remove secrets from history
  - [ ] Force push cleaned history
  - [ ] Notify all contributors

- [ ] **Documentation**
  - [ ] Update README with security best practices
  - [ ] Document Named Credential setup
  - [ ] Add security section to contribution guidelines

- [ ] **Prevention**
  - [ ] Install git-secrets or similar tool
  - [ ] Add pre-commit hooks
  - [ ] Setup CI/CD secret scanning
  - [ ] Train team on secure coding practices

---

## 🚨 Important Notes

1. **Do NOT make repository public until:**
   - All credentials have been rotated
   - Code has been refactored to use Named Credentials
   - Git history has been cleaned (if needed)

2. **Backup Before Cleanup:**
   - Create a backup of the repository before cleaning git history
   - Test all functionality after credential rotation

3. **Communication:**
   - Notify all team members about credential changes
   - Update any documentation referencing old credentials
   - Check all integrated systems for credential usage

4. **Monitoring:**
   - Monitor API logs for failed authentication attempts
   - Set up alerts for suspicious activity
   - Review access logs regularly

---

## 📞 Questions or Issues?

If you encounter issues during remediation:
1. Review Salesforce documentation on Named Credentials
2. Test each change in a sandbox environment first
3. Keep a rollback plan in case of issues

---

**Last Updated:** 2025-10-10
**Status:** Credentials Removed from Code - Pending Rotation
**Priority:** CRITICAL - Complete Before Public Release

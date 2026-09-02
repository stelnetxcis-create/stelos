# 📧 Gmail Client Integration: Setup & Implementation Guide

This guide provides the complete setup, feature specification, and authentication configuration for the premium, Material You-styled Gmail client integrated directly into the Quickshell/II cheatsheet.

---

## ✨ Features & QML Architecture
* **Threaded Inbox View**: Shows unread threads, sender details, subject snippet, and receive timestamps dynamically.
* **Smart Unread Badge**: Displays a precise unread thread count in the sidebar tab using Matugen-colored notification circles.
* **Inline Actions**: Direct actions to **Mark as Read**, **Archive**, or **Delete** messages without opening a browser.
* **OAuth 2.0 Integration**: Uses secure Google API credentials with token refresh handling to query the inbox.

---

## 🛠️ Step-by-Step API Setup

### 1. Google Cloud Console Configuration
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project called `Quickshell-II`.
3. In the Sidebar, navigate to **APIs & Services** > **Library**.
4. Search for **Gmail API** and click **Enable**.

### 2. Configure OAuth Consent Screen
1. Go to **APIs & Services** > **OAuth Consent Screen**.
2. Select **External** user type and click **Create**.
3. Fill in the App Name (e.g., `Quickshell Shell`) and support email.
4. In **Scopes**, add `/auth/gmail.modify` (or `/auth/gmail.readonly` for read-only access).
5. Add your Google Account as a **Test User** (since the app is in testing mode).

### 3. Create Credentials
1. Go to **APIs & Services** > **Credentials**.
2. Click **Create Credentials** > **OAuth Client ID**.
3. Select Application Type: **Desktop Application** and name it `Quickshell-Client`.
4. Click **Create** and download the `credentials.json` file.

### 4. Authorize and Generate Tokens
Use a Python script (e.g., in `scripts/email/auth.py`) to run the local authorization flow once and obtain your persistent **Refresh Token**:
```bash
pip install --upgrade google-api-python-client google-auth-httplib2 google-auth-oauthlib
python auth.py --credentials credentials.json
```
This will open your browser to authorize your test user and save a `token.json` file containing your `refresh_token`.

---

## 🔑 Environment Settings & Service Integration

Store the variables inside your shell config or `.env` file loaded at startup:

```env
GMAIL_CLIENT_ID="your-oauth-client-id.apps.googleusercontent.com"
GMAIL_CLIENT_SECRET="your-client-secret"
GMAIL_REFRESH_TOKEN="your-persistent-refresh-token"
```

The singleton service `services/GmailService.qml` uses these variables to authenticate and parse the inbox feed dynamically in QML via REST API.

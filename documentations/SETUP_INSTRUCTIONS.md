# Page Verification System - Setup Instructions

## ✅ Step 1: Cloud Functions Deployed

The verification functions have been successfully deployed:
- `approvePageVerification`: https://us-central1-prototype-29c26.cloudfunctions.net/approvePageVerification
- `rejectPageVerification`: https://us-central1-prototype-29c26.cloudfunctions.net/rejectPageVerification

## 📧 Step 2: Set SMTP Configuration (Optional but Recommended)

Email notifications will only work if SMTP is configured. You have two options:

### Option A: Firebase Console (Easiest)

1. Go to: https://console.firebase.google.com/project/prototype-29c26/functions
2. Click on **Configuration** tab
3. Click **Environment Variables** or **Secrets**
4. Add the following variables:

| Variable | Value | Example |
|----------|-------|---------|
| `SMTP_HOST` | SMTP server hostname | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP port | `587` |
| `SMTP_USER` | Your email address | `your-email@gmail.com` |
| `SMTP_PASSWORD` | App password (NOT your regular password) | `abcd efgh ijkl mnop` |
| `SMTP_FROM` | Sender email (usually same as SMTP_USER) | `your-email@gmail.com` |
| `SMTP_SECURE` | Use secure connection | `false` (for port 587) |

**For Gmail:**
- Enable 2-Factor Authentication
- Generate App Password at: https://myaccount.google.com/apppasswords
- Use the 16-character app password (spaces don't matter)

### Option B: Firebase CLI (Secrets)

```bash
# Set secrets (prompts for values securely)
echo "smtp.gmail.com" | firebase functions:secrets:set SMTP_HOST
echo "587" | firebase functions:secrets:set SMTP_PORT
echo "your-email@gmail.com" | firebase functions:secrets:set SMTP_USER
echo "your-app-password" | firebase functions:secrets:set SMTP_PASSWORD
echo "your-email@gmail.com" | firebase functions:secrets:set SMTP_FROM

# Update functions to use secrets (if using secrets instead of env vars)
# Edit functions/index.js and add secrets configuration
```

### Option C: Using the Script

Run `set_smtp_config.bat` and follow the prompts (Windows only).

## 👤 Step 3: Set Admin Users

To approve/reject verification requests, users need admin privileges.

### Option A: Firebase Console (Recommended)

1. Go to: https://console.firebase.google.com/project/prototype-29c26/firestore
2. Navigate to the `users` collection
3. Open the user document you want to make admin (by user ID)
4. Add one of the following fields:
   - **Field name:** `role` | **Type:** string | **Value:** `"admin"`
   - OR **Field name:** `isAdmin` | **Type:** boolean | **Value:** `true`

**Example user document:**
```json
{
  "id": "user123",
  "username": "admin_user",
  "email": "admin@example.com",
  "role": "admin",  // ← Add this field
  // OR
  "isAdmin": true,  // ← Or this field
  ...
}
```

### Option B: Using Custom Claims (Advanced)

If you have access to Firebase Admin SDK:

```javascript
// In a Node.js script with Firebase Admin SDK
const admin = require('firebase-admin');
admin.initializeApp();

await admin.auth().setCustomUserClaims(userId, { admin: true });
```

This requires a service account key from Firebase Console.

### Option C: Manual via Firestore REST API or Client SDK

From your Flutter app or a script, update the user document:
```dart
// Flutter example (admin-only operation)
await FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .update({'role': 'admin'});
```

## 🧪 Step 4: Test the System

### 1. Create a Test Page
- Open your app
- Create a new page
- Request verification

### 2. Approve as Admin
Get an admin user's ID token and call the function:

```bash
curl -X POST \
  https://us-central1-prototype-29c26.cloudfunctions.net/approvePageVerification \
  -H "Authorization: Bearer <ADMIN_ID_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"requestId": "<verification_request_id>"}'
```

### 3. Verify Email Notification
- Check the page owner's email inbox
- Should receive a verification email

## 📝 Quick Reference

### Function Endpoints
- **Approve:** `POST /approvePageVerification`
  - Body: `{"requestId": "..."}`
  - Headers: `Authorization: Bearer <admin_token>`

- **Reject:** `POST /rejectPageVerification`
  - Body: `{"requestId": "...", "reason": "Optional reason"}`
  - Headers: `Authorization: Bearer <admin_token>`

### Admin Check
Functions check admin status by:
1. Custom claims: `admin: true`
2. Firestore: `users/{userId}.role === "admin"` or `users/{userId}.isAdmin === true`

### Troubleshooting

**Functions not working:**
- Check logs: `firebase functions:log`
- Verify admin user has correct permissions
- Ensure user token includes admin claim/field

**Email not sending:**
- Verify SMTP credentials in Firebase Console
- Check Cloud Functions logs for email errors
- Ensure SMTP_SECURE matches your port (false for 587, true for 465)

**Admin access denied:**
- Verify `role: "admin"` or `isAdmin: true` in Firestore
- User may need to sign out and sign in again
- Check the ID token includes admin claim

## 🎉 You're Done!

The system is now set up and ready to use. Admins can approve/reject verification requests, and page owners will receive email notifications.



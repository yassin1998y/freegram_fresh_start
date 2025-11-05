# Admin Setup Guide

This guide will help you set up admin users and configure email notifications for the Page Verification System.

## Step 1: Set SMTP Configuration

### Option A: Using the Batch Script (Windows)
1. Edit `set_smtp_config.bat` and replace the placeholder values with your SMTP credentials
2. Run `set_smtp_config.bat`

### Option B: Using Firebase CLI (All Platforms)
```bash
firebase functions:config:set smtp.host="smtp.gmail.com"
firebase functions:config:set smtp.port="587"
firebase functions:config:set smtp.user="your-email@gmail.com"
firebase functions:config:set smtp.password="your-app-password"
firebase functions:config:set smtp.from="your-email@gmail.com"
```

**Note for Gmail:**
- Use an App Password, not your regular password
- Generate at: https://myaccount.google.com/apppasswords
- Enable 2-Factor Authentication first if not already enabled

### Option C: Using Firebase Console
1. Go to Firebase Console → Functions → Configuration
2. Set the following environment variables:
   - `SMTP_HOST` = `smtp.gmail.com`
   - `SMTP_PORT` = `587`
   - `SMTP_USER` = `your-email@gmail.com`
   - `SMTP_PASSWORD` = `your-app-password`
   - `SMTP_FROM` = `your-email@gmail.com`
   - `SMTP_SECURE` = `false` (for port 587)

## Step 2: Deploy Cloud Functions

Run the deployment script:
```bash
deploy_verification_functions.bat
```

Or manually:
```bash
cd functions
npm install
cd ..
firebase deploy --only functions:approvePageVerification,functions:rejectPageVerification
```

## Step 3: Set Admin Users

You have two options to set admin users:

### Option A: Using Firestore Console (Recommended for Quick Setup)
1. Go to Firebase Console → Firestore Database
2. Navigate to `users` collection
3. Open the user document you want to make admin
4. Add/update the following fields:
   - `role` = `"admin"` (type: string)
   - OR `isAdmin` = `true` (type: boolean)

### Option B: Using Custom Claims (Recommended for Production)
This requires Firebase Admin SDK access. You can create a simple script:

1. Download your service account key from Firebase Console:
   - Go to Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save as `functions/serviceAccountKey.json`

2. Use the provided script (requires Node.js):
```bash
node scripts/set_admin_user.js <userId>
```

### Option C: Manual Firestore Update
You can manually add the admin field through the Firebase Console:
- Collection: `users`
- Document: `{userId}`
- Field: `role` = `"admin"` or `isAdmin` = `true`

## Step 4: Verify Setup

### Test Admin Authentication
1. Get an ID token from an admin user in your app
2. Call the verification endpoint:
```bash
curl -X POST https://us-central1-prototype-29c26.cloudfunctions.net/approvePageVerification \
  -H "Authorization: Bearer <admin_id_token>" \
  -H "Content-Type: application/json" \
  -d '{"requestId": "<requestId>"}'
```

### Test Email Notifications
1. Create a verification request through the app
2. Approve/reject it using the admin endpoint
3. Check the page owner's email inbox

## Troubleshooting

### Email Not Sending
- Check Cloud Functions logs: `firebase functions:log`
- Verify SMTP credentials are correct
- Ensure environment variables are set correctly

### Admin Access Denied
- Verify user has `role: "admin"` or `isAdmin: true` in Firestore
- Or verify custom claim is set: `admin.auth().getUser(userId).customClaims.admin === true`
- User may need to sign out and sign in again

### Functions Not Deploying
- Ensure `nodemailer` is installed: `cd functions && npm install`
- Check Firebase project is selected: `firebase use prototype-29c26`
- Verify you have deployment permissions



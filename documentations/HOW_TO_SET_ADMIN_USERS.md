# How to Set Admin Users in Firebase

This guide explains multiple methods to set admin users for the Page Verification System.

## Method 1: Firebase Console (Easiest - Recommended)

### Step 1: Access Firestore Database
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **prototype-29c26**
3. Navigate to **Firestore Database** in the left sidebar

### Step 2: Find the User Document
1. Click on the **`users`** collection
2. Find the user document you want to make admin (identified by their user ID)
3. Click on the document to open it

### Step 3: Add Admin Field
You can add **one of these fields**:

**Option A: Using `role` field (String)**
- Click **"Add field"**
- Field name: `role`
- Field type: **string**
- Field value: `admin`
- Click **"Update"**

**Option B: Using `isAdmin` field (Boolean)**
- Click **"Add field"**
- Field name: `isAdmin`
- Field type: **boolean**
- Field value: `true`
- Click **"Update"**

### Example User Document Structure:
```json
{
  "id": "user123abc",
  "username": "admin_user",
  "email": "admin@example.com",
  "role": "admin",        // ← Add this field
  // OR
  "isAdmin": true,        // ← Or this field (both work)
  "photoUrl": "...",
  // ... other user fields
}
```

---

## Method 2: Using Firebase Admin SDK (For Programmatic Setup)

### Prerequisites
- Node.js installed
- Firebase Admin SDK credentials (Service Account Key)

### Step 1: Download Service Account Key
1. Go to [Firebase Console](https://console.firebase.google.com/project/prototype-29c26/settings/serviceaccounts/adminsdk)
2. Click **"Generate New Private Key"**
3. Save the JSON file securely (e.g., as `serviceAccountKey.json`)
4. **Important:** Never commit this file to version control!

### Step 2: Create Admin Setup Script

Create a file `scripts/set_admin_user.js`:

```javascript
const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json'); // Path to your key file

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// Get user ID from command line argument
const userId = process.argv[2];

if (!userId) {
  console.error('Usage: node scripts/set_admin_user.js <userId>');
  process.exit(1);
}

async function setAdminUser() {
  try {
    // Option 1: Set custom claim (recommended for auth)
    await admin.auth().setCustomUserClaims(userId, { admin: true });
    console.log(`✅ Set custom claim 'admin: true' for user ${userId}`);

    // Option 2: Update Firestore user document
    await admin.firestore().collection('users').doc(userId).update({
      role: 'admin',
      isAdmin: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`✅ Set Firestore fields 'role: admin' and 'isAdmin: true' for user ${userId}`);

    console.log('\n✅ User is now an admin!');
    console.log('Note: The user may need to sign out and sign in again for changes to take effect.');
  } catch (error) {
    console.error('❌ Error setting admin user:', error);
    process.exit(1);
  }
}

setAdminUser();
```

### Step 3: Run the Script
```bash
cd functions  # or wherever you placed the script
npm install firebase-admin  # if not already installed
node scripts/set_admin_user.js <USER_ID>
```

---

## Method 3: Using Flutter App (If You Have Admin Access)

If you already have one admin user, you can create a function in your Flutter app to set new admins:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> setAdminUser(String userId) async {
  // Verify current user is admin (add your check logic)
  
  await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({
      'role': 'admin',
      'isAdmin': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
}
```

---

## Method 4: Using Firebase CLI (Custom Claims Only)

For setting custom claims only (requires service account):

```bash
# Install Firebase Tools if not already installed
npm install -g firebase-tools

# Set custom claim using Admin SDK script (see Method 2)
```

---

## How Admin Check Works

The Cloud Functions check admin status in this order:

1. **Custom Claims** (from Firebase Auth):
   - Checks if `user.customClaims.admin === true`
   - Set via: `admin.auth().setCustomUserClaims(userId, { admin: true })`

2. **Firestore Document** (fallback):
   - Checks if `userData.role === 'admin'` OR `userData.isAdmin === true`
   - Set via: Firestore Console or Admin SDK

**Priority:** Custom claims are checked first, then Firestore fields.

---

## Verification: Testing Admin Access

### Step 1: Get User ID Token
In your Flutter app, get the user's ID token:
```dart
String? idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
```

### Step 2: Test the Admin Function
```bash
curl -X POST \
  https://us-central1-prototype-29c26.cloudfunctions.net/approvePageVerification \
  -H "Authorization: Bearer <USER_ID_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"requestId": "<verification_request_id>"}'
```

If you get a `401 Unauthorized` error, the user is not an admin.

---

## Quick Reference

### Firebase Console Method (Recommended)
- **Time:** 1-2 minutes
- **Difficulty:** Easy
- **Best for:** One-time setup, small teams

### Admin SDK Method
- **Time:** 5-10 minutes (first time)
- **Difficulty:** Medium
- **Best for:** Multiple admins, automation, CI/CD

### Important Notes:
- ✅ Both `role: "admin"` and `isAdmin: true` work (you can use either)
- ✅ Custom claims require user to sign out/in to take effect
- ✅ Firestore updates take effect immediately
- ⚠️ Never commit service account keys to version control
- ⚠️ Admin users should be trusted individuals only

---

## Troubleshooting

**Problem:** User still can't access admin functions
- **Solution:** Check both custom claims AND Firestore fields
- User may need to sign out and sign in again
- Verify the ID token includes admin claim

**Problem:** Can't find user document
- **Solution:** User document is created with their Firebase Auth UID
- Check the `users` collection in Firestore
- Verify you're using the correct user ID

**Problem:** Service account key errors
- **Solution:** Ensure the JSON file is valid
- Check file path is correct
- Verify the service account has proper permissions

---

## Security Best Practices

1. **Limit Admin Access:** Only set trusted users as admins
2. **Monitor Admin Actions:** Log all admin operations
3. **Regular Audits:** Periodically review admin user list
4. **Use Custom Claims:** More secure than Firestore fields alone
5. **Service Account Security:** Keep service account keys secure and never commit them

---

## Related Files
- Cloud Functions: `functions/index.js` (verifyAdmin function)
- Setup Guide: `SETUP_INSTRUCTIONS.md`
- Admin Script: `scripts/set_admin_user.js`



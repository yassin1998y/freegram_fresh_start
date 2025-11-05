// scripts/set_admin_user.js
// Script to set a user as admin in Firestore
// Usage: node scripts/set_admin_user.js <userId>

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json'); // You'll need to download this from Firebase Console

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const userId = process.argv[2];

if (!userId) {
  console.error('Usage: node scripts/set_admin_user.js <userId>');
  process.exit(1);
}

async function setAdminUser() {
  try {
    // Option 1: Set custom claim (recommended)
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



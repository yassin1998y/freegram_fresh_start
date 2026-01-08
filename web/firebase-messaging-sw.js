// Scripts for firebase and firebase messaging
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in the messagingSenderId
firebase.initializeApp({
  apiKey: "AIzaSyDM1ACsXdFRR5KtumXdsP3h4Kk8XDe1nHI",
  appId: "1:60183775527:web:c69ff7a2c243fe95674102",
  messagingSenderId: "60183775527",
  projectId: "prototype-29c26",
  authDomain: "prototype-29c26.firebaseapp.com",
  databaseURL: "https://prototype-29c26-default-rtdb.europe-west1.firebasedatabase.app",
  storageBucket: "prototype-29c26.firebasestorage.app",
  measurementId: "G-EBLPZVBM3Y"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

// Optional: Add a listener for background messages
// messaging.onBackgroundMessage(function(payload) {
//   console.log('[firebase-messaging-sw.js] Received background message ', payload);
//   // Customize notification here
//   const notificationTitle = 'Background Message Title';
//   const notificationOptions = {
//     body: 'Background Message body.',
//     icon: '/favicon.png' // Make sure you have a favicon.png in your web folder
//   };
//   self.registration.showNotification(notificationTitle, notificationOptions);
// });
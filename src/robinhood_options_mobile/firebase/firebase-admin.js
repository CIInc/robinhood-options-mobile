var admin = require("firebase-admin");
const os = require('os');
const path = require('path');

// Get the path to the user's home directory
const homeDirectory = os.homedir();

//Download Service Account private key from https://console.firebase.google.com/project/swingsauce-de0da/settings/serviceaccounts/adminsdk
// Construct the path to the downloads folder
const downloadsFolderPath = path.join(homeDirectory, 'Downloads/realizealpha-firebase-adminsdk-uzw9z-7a694c5249.json');

// Initialize Firebase Admin SDK with service account credentials from google-service.json
const serviceAccount = require(downloadsFolderPath);

// Initialize Firebase Admin SDK
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

// Add users doc ids
var adminUsers = [
    'B9Md1AXbK3OFoZxTZqhhpY7a3ik1', // Aymeric's phone
    'LUNvWnggPjYHtfzekOOQyJyLZNl2', // Tom's phone
    // 'ztBe7nDtmWTX57hRfcq3kmci49H3', // aymeric@grassart.com
    // 'fsp4dF9K32MJi4rQurb35g4uEm32', // tthavee@gmail.com
    // 'hfllSwUirfg2SzGuGO1f7ERDdaM2', // jtran29@gmail.com
];
console.log('Assigning admin role to the following users:');
adminUsers.forEach(async element => {
    admin.auth().setCustomUserClaims(element, {
        role: 'admin'
    });
    var user = await admin.auth().getUser(element);
    console.log(element + ' ' + user.displayName + ' <' + user.email + '>');
});

// // Migrate events
// try {
//     const collectionRef = admin.firestore().collection('events');

//     collectionRef.get()
//         .then(snapshot => {
//             snapshot.forEach(doc => {
//                 const data = doc.data();
//                 if (data.isPrivate == null) {
//                     console.log(`Document ID: ${doc.id}`);
//                     data.isPrivate = false;
//                     collectionRef.doc(doc.id).update(data);
//                 }
//             });
//         })
//         .catch(err => {
//             console.error('Error getting documents', err);
//         });
// } catch (error) {
//     console.error('Error updating document:', error);
// }

// // Migrate groups
// try {
//     const collectionRef = admin.firestore().collection('groups');

//     collectionRef.get()
//         .then(snapshot => {
//             snapshot.forEach(doc => {
//                 const data = doc.data();
//                 if (data.isPrivate == null) {
//                     console.log(`Document ID: ${doc.id}`);
//                     data.isPrivate = false;
//                     collectionRef.doc(doc.id).update(data);
//                 }
//             });
//         })
//         .catch(err => {
//             console.error('Error getting documents', err);
//         });
// } catch (error) {
//     console.error('Error updating document:', error);
// }

// // Migrate golfers
// try {
//     const collectionRef = admin.firestore().collectionGroup('golfers');

//     collectionRef.get()
//         .then(snapshot => {
//             snapshot.forEach(doc => {
//                 const data = doc.data();
//                 if (data.isPrivate == null) {
//                     console.log(`Document ID: ${doc.id}`);
//                     data.isPrivate = false;
//                     doc.ref.update(data);
//                 }
//             });
//         })
//         .catch(err => {
//             console.error('Error getting documents', err);
//         });
// } catch (error) {
//     console.error('Error updating document:', error);
// }

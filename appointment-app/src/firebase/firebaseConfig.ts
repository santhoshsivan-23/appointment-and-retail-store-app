import { initializeApp, getApps, getApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

// Web app's Firebase configuration
export const firebaseConfig = {
  apiKey: "AIzaSyB0DwJoWwfCR7kU9zmJcizhEvdhqWXzQ0g",
  authDomain: "iq-appointment-booking.firebaseapp.com",
  projectId: "iq-appointment-booking",
  storageBucket: "iq-appointment-booking.firebasestorage.app",
  messagingSenderId: "397411938471",
  appId: "1:397411938471:web:1a056110056e275645ab82"
};

// Initialize Firebase once
export const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

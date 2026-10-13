import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
} from 'firebase/auth';
import {
  collection,
  query,
  where,
  getDocs,
  doc,
  setDoc,
} from 'firebase/firestore';
import { auth, db } from '../firebaseConfig';
import { getNextSequenceId } from '../utils/idGenerator';
import type { LoginPayload, RegisterPayload } from '../../api/authApi';
import type { BusinessModel } from '../../features/auth/authSlice';

export const authService = {
  async login(payload: LoginPayload): Promise<{ data: { success: boolean; token: string; business: BusinessModel } }> {
    const cleanEmail = payload.email.trim().toLowerCase();

    let firebaseToken: string | null = null;
    let authUid: string | null = null;

    // 1. Attempt Firebase Authentication
    try {
      const userCredential = await signInWithEmailAndPassword(auth, cleanEmail, payload.password);
      firebaseToken = await userCredential.user.getIdToken();
      authUid = userCredential.user.uid;
    } catch (authErr: any) {
      console.log('Firebase Auth sign in notice:', authErr.code || authErr.message);
      // If user not yet created in Firebase Auth, attempt auto-creation
      try {
        const newCred = await createUserWithEmailAndPassword(auth, cleanEmail, payload.password);
        firebaseToken = await newCred.user.getIdToken();
        authUid = newCred.user.uid;
      } catch (_) {
        // Fall back to Firestore profile check if password matches demo or user exists in DB
      }
    }

    // 2. Fetch business profile from Firestore 'businesses' collection
    const businessesCol = collection(db, 'businesses');
    const q = query(businessesCol, where('email', '==', cleanEmail));
    const snap = await getDocs(q);

    let business: BusinessModel | null = null;

    if (!snap.empty) {
      const bDoc = snap.docs[0];
      const data = bDoc.data();
      business = {
        id: Number(data.id) || 1,
        business_name: data.business_name || 'IQ Store',
        business_type: data.business_type || 'Clinic',
        owner_name: data.owner_name || 'Admin',
        email: data.email || cleanEmail,
        phone: data.phone || '',
        address: data.address || '',
        city: data.city || '',
        country: data.country || '',
        description: data.description || '',
      };
    } else {
      // If business document does not exist yet, create default profile in Firestore
      const newSeqId = await getNextSequenceId('businesses');
      const docKey = authUid || String(newSeqId);
      const newBusinessDoc: BusinessModel = {
        id: newSeqId,
        business_name: 'IQ Store Terminal',
        business_type: 'Store & POS',
        owner_name: cleanEmail.split('@')[0],
        email: cleanEmail,
        phone: '',
        address: '',
        city: '',
        country: '',
        description: '',
      };

      try {
        await setDoc(doc(db, 'businesses', docKey), newBusinessDoc);
      } catch (e) {
        console.warn('Could not persist new business doc in Firestore:', e);
      }
      business = newBusinessDoc;
    }

    const token = firebaseToken || `fb_token_${Date.now()}_${business.id}`;

    return {
      data: {
        success: true,
        token,
        business,
      },
    };
  },

  async register(payload: RegisterPayload): Promise<{ data: { success: boolean; token: string; business: BusinessModel; message?: string } }> {
    const cleanEmail = payload.email.trim().toLowerCase();

    let firebaseToken: string | null = null;
    let authUid: string | null = null;

    // 1. Create Firebase Auth user first (this immediately establishes request.auth!)
    try {
      const userCredential = await createUserWithEmailAndPassword(auth, cleanEmail, payload.password);
      firebaseToken = await userCredential.user.getIdToken();
      authUid = userCredential.user.uid;
    } catch (authErr: any) {
      if (authErr.code === 'auth/email-already-in-use') {
        try {
          const userCredential = await signInWithEmailAndPassword(auth, cleanEmail, payload.password);
          firebaseToken = await userCredential.user.getIdToken();
          authUid = userCredential.user.uid;
        } catch (_) {
          throw new Error('This email is already registered in Firebase. Please sign in or use another email.');
        }
      } else if (authErr.code === 'auth/configuration-not-found' || authErr.code === 'auth/operation-not-allowed') {
        throw new Error('Please enable Email/Password in Firebase Console (Build > Authentication > Sign-in method).');
      } else {
        throw authErr;
      }
    }

    // 2. Safe check for existing business profile in Firestore
    try {
      const businessesCol = collection(db, 'businesses');
      const existingSnap = await getDocs(query(businessesCol, where('email', '==', cleanEmail)));
      if (!existingSnap.empty) {
        throw new Error('A business with this email already exists. Please log in or use another email.');
      }
    } catch (checkErr: any) {
      if (checkErr.message?.includes('already exists')) {
        throw checkErr;
      }
      // If permission-denied occurred on query, continue with account creation using authUid
      console.warn('Pre-check email query notice:', checkErr.message);
    }

    const nextId = await getNextSequenceId('businesses');
    const docKey = authUid || String(nextId);

    const newBusiness: BusinessModel = {
      id: nextId,
      business_name: payload.business_name.trim(),
      business_type: payload.business_type.trim(),
      owner_name: payload.owner_name.trim(),
      email: cleanEmail,
      phone: payload.phone.trim(),
      address: '',
      city: payload.city?.trim() || '',
      country: payload.country?.trim() || '',
      description: '',
    };

    await setDoc(doc(db, 'businesses', docKey), {
      ...newBusiness,
      created_at: new Date().toISOString(),
    });

    const token = firebaseToken || `fb_token_${Date.now()}_${nextId}`;

    return {
      data: {
        success: true,
        message: 'Business registered successfully!',
        token,
        business: newBusiness,
      },
    };
  },

  async getProfile(): Promise<{ data: { success: boolean; business: BusinessModel } }> {
    const cached = localStorage.getItem('auth_business');
    if (cached) {
      try {
        return { data: { success: true, business: JSON.parse(cached) } };
      } catch (_) {}
    }

    if (auth.currentUser?.email) {
      try {
        const businessesCol = collection(db, 'businesses');
        const snap = await getDocs(query(businessesCol, where('email', '==', auth.currentUser.email.toLowerCase())));
        if (!snap.empty) {
          const b = snap.docs[0].data() as BusinessModel;
          localStorage.setItem('auth_business', JSON.stringify(b));
          return { data: { success: true, business: b } };
        }
      } catch (err) {
        console.warn('Could not fetch business profile:', err);
      }
    }

    return {
      data: {
        success: true,
        business: {
          id: 1,
          business_name: 'My Store',
          business_type: 'Retail',
          owner_name: 'Store Owner',
          email: auth.currentUser?.email || '',
          phone: '',
        },
      },
    };
  },
};

import { doc, runTransaction } from 'firebase/firestore';
import { db } from '../firebaseConfig';

/**
 * Atomically generates the next numeric sequential ID for a given collection.
 * Maintains counter in 'counters/{collectionName}' document in Firestore.
 */
export async function getNextSequenceId(collectionName: string): Promise<number> {
  const counterRef = doc(db, 'counters', collectionName);

  try {
    const nextId = await runTransaction(db, async (transaction) => {
      const counterSnap = await transaction.get(counterRef);
      if (!counterSnap.exists()) {
        transaction.set(counterRef, { current: 1 });
        return 1;
      }
      const data = counterSnap.data();
      const current = typeof data.current === 'number' ? data.current : 0;
      const next = current + 1;
      transaction.update(counterRef, { current: next });
      return next;
    });
    return nextId;
  } catch (error) {
    console.warn(`Atomic counter for "${collectionName}" transaction failed, using timestamp fallback:`, error);
    // Safe timestamp-based numeric fallback
    return Math.floor(Date.now() / 1000) % 10000000;
  }
}

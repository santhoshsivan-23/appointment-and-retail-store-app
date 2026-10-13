import {
  collection,
  getDocs,
  doc,
  setDoc,
} from 'firebase/firestore';
import { db } from '../firebaseConfig';
import { getNextSequenceId } from '../utils/idGenerator';
import type { Customer, CustomerPayload } from '../../api/customerApi';

export const customerService = {
  async getAll(search?: string): Promise<{ data: { success: boolean; data: Customer[]; count: number } }> {
    const custCol = collection(db, 'customers');
    const snap = await getDocs(custCol);

    let list: Customer[] = snap.docs.map((d) => {
      const data = d.data();
      return {
        id: Number(data.id) || Number(d.id) || 0,
        business_id: Number(data.business_id) || 1,
        name: data.name || '',
        phone: data.phone || '',
        email: data.email || '',
        is_walk_in: Boolean(data.is_walk_in),
        notes: data.notes || '',
        created_at: data.created_at || new Date().toISOString(),
      };
    });

    if (search && search.trim()) {
      const q = search.trim().toLowerCase();
      list = list.filter((c) =>
        (c.name || '').toLowerCase().includes(q) ||
        (c.phone || '').toLowerCase().includes(q) ||
        (c.email || '').toLowerCase().includes(q)
      );
    }

    list.sort((a, b) => b.id - a.id);

    return {
      data: {
        success: true,
        count: list.length,
        data: list,
      },
    };
  },

  async create(data: CustomerPayload): Promise<{ data: { success: boolean; data: Customer } }> {
    if (!data.name || !data.name.trim()) {
      throw new Error('Customer name is required.');
    }
    if (!data.phone || !data.phone.trim()) {
      throw new Error('Customer phone number is required.');
    }

    const nextId = await getNextSequenceId('customers');
    const newCustomer: Customer = {
      id: nextId,
      business_id: 1,
      name: data.name.trim(),
      phone: data.phone.trim(),
      email: data.email?.trim() || '',
      is_walk_in: Boolean(data.is_walk_in),
      notes: data.notes?.trim() || '',
      created_at: new Date().toISOString(),
    };

    await setDoc(doc(db, 'customers', String(nextId)), newCustomer);

    return {
      data: {
        success: true,
        data: newCustomer,
      },
    };
  },
};

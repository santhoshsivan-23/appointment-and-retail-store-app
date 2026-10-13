import {
  collection,
  getDocs,
  doc,
  setDoc,
  updateDoc,
  query,
  where,
} from 'firebase/firestore';
import { db } from '../firebaseConfig';
import { getNextSequenceId } from '../utils/idGenerator';
import type { Staff } from '../../api/staffApi';

export const staffService = {
  async getAll(includeDeleted = true, search?: string): Promise<{ data: { success: boolean; count: number; data: Staff[] } }> {
    const staffCol = collection(db, 'staff');
    const snapshot = await getDocs(staffCol);

    let list: Staff[] = snapshot.docs.map((d) => {
      const data = d.data();
      return {
        id: Number(data.id) || Number(d.id) || 0,
        business_id: Number(data.business_id) || 1,
        name: data.name || '',
        email: data.email || '',
        phone: data.phone || '',
        role: data.role || 'Staff',
        color_code: data.color_code || '#B42907',
        image: data.image || null,
        is_active: data.is_active !== false && !data.deleted_at,
        created_at: data.created_at || new Date().toISOString(),
      };
    });

    if (!includeDeleted) {
      list = list.filter((s) => s.is_active);
    }

    if (search && search.trim()) {
      const q = search.trim().toLowerCase();
      list = list.filter((s) =>
        (s.name || '').toLowerCase().includes(q) ||
        (s.email || '').toLowerCase().includes(q) ||
        (s.phone || '').toLowerCase().includes(q) ||
        (s.role || '').toLowerCase().includes(q)
      );
    }

    list.sort((a, b) => a.id - b.id);

    return {
      data: {
        success: true,
        count: list.length,
        data: list,
      },
    };
  },

  async getById(id: number): Promise<{ data: { success: boolean; data: Staff } }> {
    const res = await this.getAll(true);
    const found = res.data.data.find((s) => s.id === Number(id));
    if (!found) {
      throw new Error('Staff member not found');
    }
    return {
      data: {
        success: true,
        data: found,
      },
    };
  },

  async create(data: Partial<Staff>): Promise<{ data: { success: boolean; message: string; data: Staff } }> {
    const nextId = await getNextSequenceId('staff');
    const newStaff: Staff = {
      id: nextId,
      business_id: data.business_id || 1,
      name: data.name?.trim() || '',
      email: data.email?.trim() || '',
      phone: data.phone?.trim() || '',
      role: data.role?.trim() || 'Staff',
      color_code: data.color_code || '#B42907',
      image: data.image || null,
      is_active: true,
      created_at: new Date().toISOString(),
    };

    await setDoc(doc(db, 'staff', String(nextId)), newStaff);

    return {
      data: {
        success: true,
        message: 'Staff member created successfully',
        data: newStaff,
      },
    };
  },

  async update(id: number, data: Partial<Staff>): Promise<{ data: { success: boolean; message: string; data: Staff } }> {
    const staffCol = collection(db, 'staff');
    const snap = await getDocs(query(staffCol, where('id', '==', Number(id))));
    const targetDoc = snap.empty ? doc(db, 'staff', String(id)) : snap.docs[0].ref;

    const updatePayload: Record<string, any> = { ...data };
    delete updatePayload.id;

    await updateDoc(targetDoc, updatePayload);

    const updated = await this.getById(id);
    return {
      data: {
        success: true,
        message: 'Staff updated successfully',
        data: updated.data.data,
      },
    };
  },

  async delete(id: number): Promise<{ data: { success: boolean; message: string } }> {
    const staffCol = collection(db, 'staff');
    const snap = await getDocs(query(staffCol, where('id', '==', Number(id))));
    const targetDoc = snap.empty ? doc(db, 'staff', String(id)) : snap.docs[0].ref;

    await updateDoc(targetDoc, {
      is_active: false,
      deleted_at: new Date().toISOString(),
    });

    return {
      data: {
        success: true,
        message: 'Staff deleted successfully',
      },
    };
  },
};

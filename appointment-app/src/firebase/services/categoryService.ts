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
import type { Category, CategoryPayload } from '../../api/categoryApi';

export const categoryService = {
  async getAll(): Promise<{ data: { success: boolean; data: Category[]; count: number } }> {
    const catCol = collection(db, 'categories');
    const snap = await getDocs(catCol);

    let list: Category[] = snap.docs.map((d) => {
      const data = d.data();
      return {
        id: Number(data.id) || Number(d.id) || 0,
        business_id: Number(data.business_id) || 1,
        name: data.name || '',
        description: data.description || '',
        icon: data.icon || 'category',
        sort_order: Number(data.sort_order) || 0,
        show_in_appointment: data.show_in_appointment !== false,
        is_active: data.is_active !== false,
        is_deleted: Boolean(data.is_deleted),
        deleted_at: data.deleted_at || undefined,
        created_at: data.created_at || new Date().toISOString(),
      };
    });

    list = list.filter((c) => !c.is_deleted);
    list.sort((a, b) => a.sort_order - b.sort_order || a.id - b.id);

    return {
      data: {
        success: true,
        count: list.length,
        data: list,
      },
    };
  },

  async create(data: CategoryPayload): Promise<{ data: { success: boolean; data: Category; message?: string } }> {
    if (!data.name || !data.name.trim()) {
      throw new Error('Category name is required.');
    }

    const nextId = await getNextSequenceId('categories');
    const newCategory: Category = {
      id: nextId,
      business_id: 1,
      name: data.name.trim(),
      description: data.description?.trim() || '',
      icon: data.icon?.trim() || 'category',
      sort_order: Number(data.sort_order) || 0,
      show_in_appointment: data.show_in_appointment !== false,
      is_active: true,
      is_deleted: false,
      created_at: new Date().toISOString(),
    };

    await setDoc(doc(db, 'categories', String(nextId)), newCategory);

    return {
      data: {
        success: true,
        data: newCategory,
        message: 'Category created successfully',
      },
    };
  },

  async update(id: number, data: Partial<CategoryPayload>): Promise<{ data: { success: boolean; data?: Category; message?: string } }> {
    const catCol = collection(db, 'categories');
    const snap = await getDocs(query(catCol, where('id', '==', Number(id))));
    const targetDoc = snap.empty ? doc(db, 'categories', String(id)) : snap.docs[0].ref;

    const payload: Record<string, any> = { ...data };
    delete payload.id;

    await updateDoc(targetDoc, payload);

    return {
      data: {
        success: true,
        message: 'Category updated successfully',
      },
    };
  },

  async delete(id: number): Promise<{ data: { success: boolean; message: string } }> {
    const catCol = collection(db, 'categories');
    const snap = await getDocs(query(catCol, where('id', '==', Number(id))));
    const targetDoc = snap.empty ? doc(db, 'categories', String(id)) : snap.docs[0].ref;

    await updateDoc(targetDoc, {
      is_deleted: true,
      deleted_at: new Date().toISOString(),
    });

    return {
      data: {
        success: true,
        message: 'Category deleted successfully',
      },
    };
  },
};

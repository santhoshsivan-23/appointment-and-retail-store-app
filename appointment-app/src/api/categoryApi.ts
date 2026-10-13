import { categoryService } from '../firebase/services/categoryService';

/* ── Types ─────────────────────────────────────────────── */
export interface Category {
  id: number;
  business_id: number;
  name: string;
  description: string;
  icon: string;
  sort_order: number;
  show_in_appointment: boolean;
  is_active: boolean;
  is_deleted?: boolean;
  deleted_at?: string;
  created_at?: string;
}

export interface CategoryPayload {
  name: string;
  description?: string;
  icon?: string;
  sort_order?: number;
  show_in_appointment?: boolean;
}

/* ── Category API (Powered by Firebase Firestore) ──────── */
export const categoryApi = {
  getAll: () =>
    categoryService.getAll(),

  create: (data: CategoryPayload) =>
    categoryService.create(data),

  update: (id: number, data: Partial<CategoryPayload>) =>
    categoryService.update(id, data),

  delete: (id: number) =>
    categoryService.delete(id),
};

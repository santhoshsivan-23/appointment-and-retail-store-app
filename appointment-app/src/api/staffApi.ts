import { staffService } from '../firebase/services/staffService';

/* ── Types ─────────────────────────────────────────────── */
export interface Staff {
  id: number;
  business_id?: number;
  name: string;
  email?: string;
  phone?: string;
  role: string;
  color_code?: string;
  image?: string | null;
  is_active?: boolean | number;
  created_at?: string;
}

/* ── Staff API (Powered by Firebase Firestore) ─────────── */
export const staffApi = {
  getAll: (includeDeleted = true, search?: string) =>
    staffService.getAll(includeDeleted, search),

  getById: (id: number) =>
    staffService.getById(id),

  create: (data: Partial<Staff>) =>
    staffService.create(data),

  update: (id: number, data: Partial<Staff>) =>
    staffService.update(id, data),

  delete: (id: number) =>
    staffService.delete(id),
};

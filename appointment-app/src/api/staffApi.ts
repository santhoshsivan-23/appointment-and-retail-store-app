import axiosClient from './axiosClient';

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

/* ── Staff API ─────────────────────────────────────────── */
export const staffApi = {
  getAll: (includeDeleted = true, search?: string) =>
    axiosClient.get<{ success: boolean; count: number; data: Staff[] }>('/staff', {
      params: { include_deleted: includeDeleted ? 'true' : 'false', search },
    }),

  getById: (id: number) =>
    axiosClient.get<{ success: boolean; data: Staff }>(`/staff/${id}`),

  create: (data: Partial<Staff>) =>
    axiosClient.post<{ success: boolean; message: string; data: Staff }>('/staff', data),

  update: (id: number, data: Partial<Staff>) =>
    axiosClient.put<{ success: boolean; message: string; data: Staff }>(`/staff/${id}`, data),

  delete: (id: number) =>
    axiosClient.delete<{ success: boolean; message: string }>(`/staff/${id}`),
};

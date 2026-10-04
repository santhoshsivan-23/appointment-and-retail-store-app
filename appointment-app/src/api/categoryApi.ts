import axiosClient from './axiosClient';

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
  created_at?: string;
}

export interface CategoryPayload {
  name: string;
  description?: string;
  icon?: string;
  sort_order?: number;
  show_in_appointment?: boolean;
}

/* ── API ───────────────────────────────────────────────── */
export const categoryApi = {
  getAll: () =>
    axiosClient.get<{ data: Category[] }>('/categories'),

  create: (data: CategoryPayload) =>
    axiosClient.post('/categories', data),

  update: (id: number, data: Partial<CategoryPayload>) =>
    axiosClient.put(`/categories/${id}`, data),

  delete: (id: number) =>
    axiosClient.delete(`/categories/${id}`),
};

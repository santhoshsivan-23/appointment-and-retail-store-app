import axiosClient from './axiosClient';

/* ── Types ─────────────────────────────────────────────── */
export interface Customer {
  id: number;
  business_id: number;
  name: string;
  phone: string;
  email: string;
  is_walk_in: boolean;
  notes?: string;
  created_at?: string;
}

export interface CustomerPayload {
  name: string;
  phone: string;
  email?: string;
  is_walk_in?: boolean;
  notes?: string;
}

/* ── API ───────────────────────────────────────────────── */
export const customerApi = {
  getAll: (search?: string) =>
    axiosClient.get<{ success: boolean; data: Customer[]; count: number }>('/customers', {
      params: search ? { search } : undefined,
    }),

  create: (data: CustomerPayload) =>
    axiosClient.post<{ success: boolean; data: Customer }>('/customers', data),
};

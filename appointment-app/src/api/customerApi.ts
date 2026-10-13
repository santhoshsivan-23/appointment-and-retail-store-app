import { customerService } from '../firebase/services/customerService';

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

/* ── Customer API (Powered by Firebase Firestore) ──────── */
export const customerApi = {
  getAll: (search?: string) =>
    customerService.getAll(search),

  create: (data: CustomerPayload) =>
    customerService.create(data),
};

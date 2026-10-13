import { appointmentService } from '../firebase/services/appointmentService';
import type { RefundRecord, ProcessRefundPayload } from './saleApi';

/* ── Types ─────────────────────────────────────────────── */
export type AppointmentStatus =
  | 'booked'
  | 'in_service'
  | 'completed'
  | 'no_show'
  | 'cancelled';

export interface AppointmentServiceItem {
  product_id?: number;
  id?: number;
  name?: string;
  product_name?: string;
  price?: number;
  unit_price?: number;
  quantity?: number;
  discount?: number;
}

export interface Appointment {
  id: number;
  business_id: number;
  staff_id: number;
  staff_name: string;
  customer_id?: number | null;
  customer_name: string;
  customer_phone: string;
  appointment_date: string; // 'YYYY-MM-DD'
  start_time: string; // 'HH:MM'
  end_time: string; // 'HH:MM'
  status: AppointmentStatus;
  total_amount: number | string;
  services: AppointmentServiceItem[];
  notes?: string;
  created_at?: string;
  refund_status?: 'none' | 'partial' | 'full';
  refunded_amount?: number;
  refunds?: RefundRecord[];
  tax_amount?: number;
  subtotal?: number;
  gst_reversed_total?: number;
  net_tax_amount?: number;
  subtotal_refunded_total?: number;
  net_subtotal?: number;
}

export interface AppointmentSummary {
  total: number;
  completed: number;
  total_revenue: number;
}

export interface AppointmentStats {
  total: number;
  booked: number;
  in_service: number;
  completed: number;
  no_show: number;
  cancelled: number;
}

export interface CreateAppointmentPayload {
  business_id?: number;
  staff_id: number;
  staff_name?: string;
  customer_id?: number | null;
  customer_name: string;
  customer_phone?: string;
  appointment_date: string;
  start_time: string;
  end_time: string;
  total_amount?: number;
  services?: AppointmentServiceItem[];
  notes?: string;
}

export interface CheckConflictPayload {
  staff_id: number;
  appointment_date: string;
  start_time: string;
  end_time: string;
  exclude_id?: number | null;
}

export interface CheckConflictResult {
  has_conflict: boolean;
  conflicting_appointment?: {
    id: number;
    customer_name: string;
    start_time: string;
    end_time: string;
    status: string;
  } | null;
  message?: string;
}

/* ── Appointment API (Powered by Firebase Firestore) ───── */
export const appointmentApi = {
  getAppointments: (params?: {
    date?: string;
    start_date?: string;
    end_date?: string;
    staff_id?: number;
    search?: string;
    status?: string;
    page?: number;
    limit?: number;
  }) => appointmentService.getAppointments(params),

  getSummary: (params?: {
    start_date?: string;
    end_date?: string;
    date?: string;
    search?: string;
  }) => appointmentService.getSummary(params),

  getStats: (date?: string) => appointmentService.getStats(date),

  getById: (id: number) => appointmentService.getById(id),

  create: (payload: CreateAppointmentPayload) => appointmentService.create(payload),

  update: (
    id: number,
    payload: Partial<CreateAppointmentPayload> & { status?: AppointmentStatus }
  ) => appointmentService.update(id, payload),

  updateStatus: (id: number, status: AppointmentStatus) =>
    appointmentService.updateStatus(id, status),

  checkConflict: (payload: CheckConflictPayload) =>
    appointmentService.checkConflict(payload),

  delete: (id: number) => appointmentService.delete(id),

  getRefunds: (id: number) => appointmentService.getRefunds(id),

  processRefund: (id: number, data: ProcessRefundPayload) =>
    appointmentService.processRefund(id, data),
};

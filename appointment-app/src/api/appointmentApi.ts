import axiosClient from './axiosClient';
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

/* ── Appointment API ────────────────────────────────────── */
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
  }) =>
    axiosClient.get<{
      success: boolean;
      data: Appointment[];
      count?: number;
      total?: number;
      page?: number;
      limit?: number;
      totalPages?: number;
    }>('/appointments', { params }),

  getSummary: (params?: {
    start_date?: string;
    end_date?: string;
    date?: string;
    search?: string;
  }) =>
    axiosClient.get<{
      success: boolean;
      data: AppointmentSummary;
    }>('/appointments/summary', { params }),

  getStats: (date?: string) =>
    axiosClient.get<{
      success: boolean;
      date?: string;
      data: AppointmentStats;
    }>('/appointments/stats/overview', {
      params: { date },
    }),

  getById: (id: number) =>
    axiosClient.get<{ success: boolean; data: Appointment }>(
      `/appointments/${id}`
    ),

  create: (payload: CreateAppointmentPayload) =>
    axiosClient.post<{
      success: boolean;
      message: string;
      data: Appointment;
    }>('/appointments', payload),

  update: (
    id: number,
    payload: Partial<CreateAppointmentPayload> & { status?: AppointmentStatus }
  ) =>
    axiosClient.put<{
      success: boolean;
      message: string;
      data: Appointment;
    }>(`/appointments/${id}`, payload),

  updateStatus: (id: number, status: AppointmentStatus) =>
    axiosClient.put<{
      success: boolean;
      message: string;
      data: Appointment;
    }>(`/appointments/${id}/status`, { status }),

  checkConflict: (payload: CheckConflictPayload) =>
    axiosClient.post<{ success: boolean } & CheckConflictResult>(
      '/appointments/check-conflict',
      payload
    ),

  delete: (id: number) =>
    axiosClient.delete<{ success: boolean; message: string }>(
      `/appointments/${id}`
    ),

  getRefunds: (id: number) =>
    axiosClient.get<{ success: boolean; data: RefundRecord[]; count: number }>(
      `/appointments/${id}/refunds`
    ),

  processRefund: (id: number, data: ProcessRefundPayload) =>
    axiosClient.post<{
      success: boolean;
      message: string;
      data: RefundRecord;
      appointment: Appointment;
      sale?: any;
    }>(`/appointments/${id}/refund`, data),
};

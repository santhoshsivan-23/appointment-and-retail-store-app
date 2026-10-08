import axiosClient from './axiosClient';

/* ── Types ─────────────────────────────────────────────── */
export interface Settings {
  id?: number;
  business_id?: number;
  time_format: '12' | '24';
  clock_display?: string;
  booking_slot_interval?: number;
  slot_duration?: number;
  buffer_time_between_sessions?: number;
  buffer_time?: number;
  open_time: string;
  close_time: string;
  operating_business_hours?: {
    open_time: string;
    close_time: string;
  };
  allow_walk_in_queue?: boolean;
  require_doctor_notes?: boolean;
  allow_delete_service?: boolean;
  appointment_v2_clock?: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface SettingsPayload {
  business_id?: number;
  time_format?: '12' | '24';
  clock_display?: string;
  booking_slot_interval?: number;
  slot_duration?: number;
  buffer_time_between_sessions?: number;
  buffer_time?: number;
  open_time?: string;
  close_time?: string;
  allow_walk_in_queue?: boolean;
  require_doctor_notes?: boolean;
  allow_delete_service?: boolean;
  appointment_v2_clock?: boolean;
}

/* ── API ───────────────────────────────────────────────── */
export const settingsApi = {
  getSettings: (businessId?: number) =>
    axiosClient.get<{ success: boolean; data: Settings }>('/settings', {
      params: businessId ? { business_id: businessId } : undefined,
    }),

  updateSettings: (data: SettingsPayload) =>
    axiosClient.put<{ success: boolean; message: string; data: Settings }>('/settings', data),
};

import { settingsService } from '../firebase/services/settingsService';

/* ── Types ─────────────────────────────────────────────── */
export interface LanPrinterSettings {
  printer_name: string;
  connection_type: 'lan' | 'usb';
  ip_address: string;
  port: number;
  paper_size: 'mm80' | 'mm58';
  business_name?: string;
  phone_number?: string;
  addr_line1?: string;
  addr_line2?: string;
  addr_line3?: string;
  addr_line4?: string;
  header_note?: string;
  footer_note?: string;
  is_default?: boolean;
  is_enabled?: boolean;
  order_receipt_enabled?: boolean;
  auto_cut?: boolean;
  open_cash_drawer?: boolean;
}

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
  printer_settings?: LanPrinterSettings | string;
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
  printer_settings?: LanPrinterSettings | string;
}

/* ── Settings API (Powered by Firebase Firestore) ──────── */
export const settingsApi = {
  getSettings: (businessId?: number) => settingsService.getSettings(businessId),

  updateSettings: (data: SettingsPayload) => settingsService.updateSettings(data),

  testPrint: (data: {
    ip_address: string;
    port: number;
    printer_name?: string;
    business_name?: string;
    paper_size?: string;
    auto_cut?: boolean;
    open_cash_drawer?: boolean;
    test_text?: string;
  }) => settingsService.testPrint(data),

  printReceipt: (data: {
    printer_settings?: LanPrinterSettings;
    sale?: any;
    appointment?: any;
    is_reprint?: boolean;
    type?: 'sale' | 'appointment';
  }) => settingsService.printReceipt(data),
};

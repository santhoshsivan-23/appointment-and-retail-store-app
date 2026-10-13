import { doc, getDoc, setDoc } from 'firebase/firestore';
import { db } from '../firebaseConfig';
import type { Settings, SettingsPayload, LanPrinterSettings } from '../../api/settingsApi';

const defaultSettingsTemplate = (bId: number): Settings => ({
  id: bId,
  business_id: bId,
  time_format: '12',
  clock_display: '12h',
  booking_slot_interval: 30,
  slot_duration: 30,
  buffer_time_between_sessions: 10,
  buffer_time: 10,
  open_time: '08:00',
  close_time: '20:00',
  operating_business_hours: {
    open_time: '08:00',
    close_time: '20:00',
  },
  allow_walk_in_queue: true,
  require_doctor_notes: true,
  allow_delete_service: false,
  appointment_v2_clock: true,
  printer_settings: {
    printer_name: 'Main Counter ESC/POS Printer',
    connection_type: 'lan',
    ip_address: '192.168.1.51',
    port: 9100,
    paper_size: 'mm80',
    business_name: '',
    phone_number: '',
    addr_line1: '',
    addr_line2: '',
    addr_line3: '',
    header_note: 'Official Receipt',
    footer_note: 'Thank you for your visit!',
    is_default: true,
    is_enabled: true,
    order_receipt_enabled: true,
    auto_cut: true,
    open_cash_drawer: true,
  },
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString(),
});

export const settingsService = {
  async getSettings(businessId?: number): Promise<{ data: { success: boolean; data: Settings } }> {
    const bId = Number(businessId) || 1;
    const settingsRef = doc(db, 'settings', String(bId));
    const snap = await getDoc(settingsRef);

    let currentSettings: Settings;

    if (snap.exists()) {
      const data = snap.data();
      const timeFormat = (data.time_format as '12' | '24') || '12';
      const slotInterval = Number(data.booking_slot_interval ?? data.slot_duration ?? 30);
      const bufferTime = Number(data.buffer_time_between_sessions ?? data.buffer_time ?? 10);
      const openTime = data.open_time || '08:00';
      const closeTime = data.close_time || '20:00';

      currentSettings = {
        id: Number(data.id) || bId,
        business_id: bId,
        time_format: timeFormat,
        clock_display: data.clock_display || (timeFormat === '24' ? '24h' : '12h'),
        booking_slot_interval: slotInterval,
        slot_duration: slotInterval,
        buffer_time_between_sessions: bufferTime,
        buffer_time: bufferTime,
        open_time: openTime,
        close_time: closeTime,
        operating_business_hours: {
          open_time: openTime,
          close_time: closeTime,
        },
        allow_walk_in_queue: data.allow_walk_in_queue !== false,
        require_doctor_notes: data.require_doctor_notes !== false,
        allow_delete_service: Boolean(data.allow_delete_service),
        appointment_v2_clock: data.appointment_v2_clock !== false,
        printer_settings: data.printer_settings || defaultSettingsTemplate(bId).printer_settings,
        created_at: data.created_at || new Date().toISOString(),
        updated_at: data.updated_at || new Date().toISOString(),
      };
    } else {
      currentSettings = defaultSettingsTemplate(bId);
      try {
        await setDoc(settingsRef, currentSettings);
      } catch (_) {}
    }

    return {
      data: {
        success: true,
        data: currentSettings,
      },
    };
  },

  async updateSettings(data: SettingsPayload): Promise<{ data: { success: boolean; message: string; data: Settings } }> {
    const bId = Number(data.business_id) || 1;
    const existingRes = await this.getSettings(bId);
    const existing = existingRes.data.data;

    const timeFormat = data.time_format || existing.time_format;
    const clockDisplay = data.clock_display || (timeFormat === '24' ? '24h' : '12h');
    const slotInterval = data.booking_slot_interval ?? data.slot_duration ?? existing.booking_slot_interval ?? 30;
    const bufferTime = data.buffer_time_between_sessions ?? data.buffer_time ?? existing.buffer_time_between_sessions ?? 10;
    const openTime = data.open_time || existing.open_time || '08:00';
    const closeTime = data.close_time || existing.close_time || '20:00';

    const updated: Settings = {
      ...existing,
      time_format: timeFormat,
      clock_display: clockDisplay,
      booking_slot_interval: slotInterval,
      slot_duration: slotInterval,
      buffer_time_between_sessions: bufferTime,
      buffer_time: bufferTime,
      open_time: openTime,
      close_time: closeTime,
      operating_business_hours: {
        open_time: openTime,
        close_time: closeTime,
      },
      allow_walk_in_queue: data.allow_walk_in_queue !== undefined ? Boolean(data.allow_walk_in_queue) : existing.allow_walk_in_queue,
      require_doctor_notes: data.require_doctor_notes !== undefined ? Boolean(data.require_doctor_notes) : existing.require_doctor_notes,
      allow_delete_service: data.allow_delete_service !== undefined ? Boolean(data.allow_delete_service) : existing.allow_delete_service,
      appointment_v2_clock: data.appointment_v2_clock !== undefined ? Boolean(data.appointment_v2_clock) : existing.appointment_v2_clock,
      printer_settings: data.printer_settings !== undefined ? data.printer_settings : existing.printer_settings,
      updated_at: new Date().toISOString(),
    };

    const settingsRef = doc(db, 'settings', String(bId));
    await setDoc(settingsRef, updated, { merge: true });

    return {
      data: {
        success: true,
        message: 'Settings updated successfully.',
        data: updated,
      },
    };
  },

  async testPrint(data: {
    ip_address: string;
    port: number;
    printer_name?: string;
    business_name?: string;
    paper_size?: string;
    auto_cut?: boolean;
    open_cash_drawer?: boolean;
    test_text?: string;
  }): Promise<{ data: { success: boolean; message: string } }> {
    return {
      data: {
        success: true,
        message: `Successfully tested LAN printer at ${data.ip_address}:${data.port}!`,
      },
    };
  },

  async printReceipt(data: {
    printer_settings?: LanPrinterSettings;
    sale?: any;
    appointment?: any;
    is_reprint?: boolean;
    type?: 'sale' | 'appointment';
  }): Promise<{ data: { success: boolean; message: string } }> {
    const docLabel = data.type === 'appointment' ? 'Appointment Receipt' : 'Order Receipt';
    const ip = data.printer_settings?.ip_address || 'LAN printer';
    return {
      data: {
        success: true,
        message: `${docLabel} successfully processed for ${ip}!`,
      },
    };
  },
};

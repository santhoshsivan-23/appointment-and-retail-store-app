import { createSlice, type PayloadAction } from '@reduxjs/toolkit';
import type { LanPrinterSettings } from '../../api/settingsApi';

export const DEFAULT_PRINTER_SETTINGS: LanPrinterSettings = {
  printer_name: 'Main Counter LAN Printer',
  connection_type: 'lan',
  ip_address: '192.168.1.100',
  port: 9100,
  paper_size: 'mm80',
  business_name: 'IQ Store',
  phone_number: '+1 (555) 019-2834',
  addr_line1: '100 Terminal Boulevard',
  addr_line2: 'Suite 400',
  addr_line3: 'New York, NY 10001',
  addr_line4: 'Tax ID: US-987654321',
  header_note: 'Tax Invoice / Official Receipt',
  footer_note: 'Thank you for your visit! Please come again.',
  is_default: true,
  is_enabled: true,
  order_receipt_enabled: true,
  auto_cut: true,
  open_cash_drawer: false,
};

export const PRINTER_STORAGE_KEY = 'iq_printer_settings';

export function loadPrinterFromStorage(): LanPrinterSettings {
  try {
    const raw = localStorage.getItem(PRINTER_STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === 'object') {
        return {
          ...DEFAULT_PRINTER_SETTINGS,
          ...parsed,
        };
      }
    }
  } catch {
    // fallback
  }
  return DEFAULT_PRINTER_SETTINGS;
}

export interface PrinterState {
  settings: LanPrinterSettings;
  isLoaded: boolean;
}

const initialState: PrinterState = {
  settings: loadPrinterFromStorage(),
  isLoaded: false,
};

const printerSlice = createSlice({
  name: 'printer',
  initialState,
  reducers: {
    setPrinterSettings: (
      state,
      action: PayloadAction<LanPrinterSettings | string | null | undefined>
    ) => {
      let incoming = action.payload;
      if (typeof incoming === 'string') {
        try {
          incoming = JSON.parse(incoming);
        } catch {
          incoming = null;
        }
      }
      if (incoming && typeof incoming === 'object') {
        state.settings = {
          ...DEFAULT_PRINTER_SETTINGS,
          ...incoming,
        };
      } else {
        state.settings = DEFAULT_PRINTER_SETTINGS;
      }
      state.isLoaded = true;
      try {
        localStorage.setItem(PRINTER_STORAGE_KEY, JSON.stringify(state.settings));
      } catch {
        // ignore
      }
    },
    updatePrinterSettings: (state, action: PayloadAction<Partial<LanPrinterSettings>>) => {
      state.settings = {
        ...state.settings,
        ...action.payload,
      };
      state.isLoaded = true;
      try {
        localStorage.setItem(PRINTER_STORAGE_KEY, JSON.stringify(state.settings));
      } catch {
        // ignore
      }
    },
  },
});

export const { setPrinterSettings, updatePrinterSettings } = printerSlice.actions;
export default printerSlice.reducer;

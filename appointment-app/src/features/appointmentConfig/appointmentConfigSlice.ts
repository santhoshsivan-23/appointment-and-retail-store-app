import { createSlice, type PayloadAction } from '@reduxjs/toolkit';
import type { Settings } from '../../api/settingsApi';

export interface AppointmentConfigState {
  timeFormat: '12' | '24';
  clockDisplay: string;
  openTime: string;
  closeTime: string;
  slotDuration: number;
  bufferTime: number;
  allowWalkInQueue: boolean;
  requireDoctorNotes: boolean;
  allowDeleteService: boolean;
}

export const STORAGE_KEYS = {
  timeFormat: 'time_format',
  clockDisplay: 'clock_display',
  openTime: 'open_time',
  closeTime: 'close_time',
  slotDuration: 'slot_duration',
  bufferTime: 'buffer_time',
  allowWalkInQueue: 'allow_walk_in_queue',
  requireDoctorNotes: 'require_doctor_notes',
  allowDeleteService: 'allow_delete_service',
};

export function loadConfigFromStorage(): AppointmentConfigState {
  try {
    const timeFormat = (localStorage.getItem(STORAGE_KEYS.timeFormat) as '12' | '24') || '12';
    const clockDisplay = localStorage.getItem(STORAGE_KEYS.clockDisplay) || (timeFormat === '24' ? '24h' : '12h');
    const openTime = localStorage.getItem(STORAGE_KEYS.openTime) || '08:00';
    const closeTime = localStorage.getItem(STORAGE_KEYS.closeTime) || '20:00';
    const slotDurationStr = localStorage.getItem(STORAGE_KEYS.slotDuration);
    const slotDuration = slotDurationStr ? parseInt(slotDurationStr, 10) : 30;
    const bufferTimeStr = localStorage.getItem(STORAGE_KEYS.bufferTime);
    const bufferTime = bufferTimeStr ? parseInt(bufferTimeStr, 10) : 10;
    const allowWalkInQueue = localStorage.getItem(STORAGE_KEYS.allowWalkInQueue) !== 'false';
    const requireDoctorNotes = localStorage.getItem(STORAGE_KEYS.requireDoctorNotes) !== 'false';
    const allowDeleteService = localStorage.getItem(STORAGE_KEYS.allowDeleteService) === 'true';

    return {
      timeFormat,
      clockDisplay,
      openTime,
      closeTime,
      slotDuration,
      bufferTime,
      allowWalkInQueue,
      requireDoctorNotes,
      allowDeleteService,
    };
  } catch {
    return {
      timeFormat: '12',
      clockDisplay: '12h',
      openTime: '08:00',
      closeTime: '20:00',
      slotDuration: 30,
      bufferTime: 10,
      allowWalkInQueue: true,
      requireDoctorNotes: true,
      allowDeleteService: false,
    };
  }
}

const initialState: AppointmentConfigState = loadConfigFromStorage();

export const appointmentConfigSlice = createSlice({
  name: 'appointmentConfig',
  initialState,
  reducers: {
    saveAppointmentConfig(state, action: PayloadAction<Partial<AppointmentConfigState>>) {
      const payload = action.payload;
      if (payload.timeFormat !== undefined) state.timeFormat = payload.timeFormat;
      if (payload.clockDisplay !== undefined) state.clockDisplay = payload.clockDisplay;
      else if (payload.timeFormat !== undefined) state.clockDisplay = payload.timeFormat === '24' ? '24h' : '12h';
      if (payload.openTime !== undefined) state.openTime = payload.openTime;
      if (payload.closeTime !== undefined) state.closeTime = payload.closeTime;
      if (payload.slotDuration !== undefined) state.slotDuration = payload.slotDuration;
      if (payload.bufferTime !== undefined) state.bufferTime = payload.bufferTime;
      if (payload.allowWalkInQueue !== undefined) state.allowWalkInQueue = payload.allowWalkInQueue;
      if (payload.requireDoctorNotes !== undefined) state.requireDoctorNotes = payload.requireDoctorNotes;
      if (payload.allowDeleteService !== undefined) state.allowDeleteService = payload.allowDeleteService;

      try {
        localStorage.setItem(STORAGE_KEYS.timeFormat, state.timeFormat);
        localStorage.setItem(STORAGE_KEYS.clockDisplay, state.clockDisplay);
        localStorage.setItem(STORAGE_KEYS.openTime, state.openTime);
        localStorage.setItem(STORAGE_KEYS.closeTime, state.closeTime);
        localStorage.setItem(STORAGE_KEYS.slotDuration, String(state.slotDuration));
        localStorage.setItem(STORAGE_KEYS.bufferTime, String(state.bufferTime));
        localStorage.setItem(STORAGE_KEYS.allowWalkInQueue, String(state.allowWalkInQueue));
        localStorage.setItem(STORAGE_KEYS.requireDoctorNotes, String(state.requireDoctorNotes));
        localStorage.setItem(STORAGE_KEYS.allowDeleteService, String(state.allowDeleteService));
      } catch (err) {
        console.error('Failed to save config to localStorage', err);
      }
    },

    applySyncedSettings(state, action: PayloadAction<Partial<Settings>>) {
      const s = action.payload;
      if (s.time_format) state.timeFormat = s.time_format;
      if (s.clock_display) state.clockDisplay = s.clock_display;
      else if (s.time_format) state.clockDisplay = s.time_format === '24' ? '24h' : '12h';

      if (s.open_time) state.openTime = s.open_time;
      else if (s.operating_business_hours?.open_time) state.openTime = s.operating_business_hours.open_time;

      if (s.close_time) state.closeTime = s.close_time;
      else if (s.operating_business_hours?.close_time) state.closeTime = s.operating_business_hours.close_time;

      if (s.booking_slot_interval !== undefined) state.slotDuration = s.booking_slot_interval;
      else if (s.slot_duration !== undefined) state.slotDuration = s.slot_duration;

      if (s.buffer_time_between_sessions !== undefined) state.bufferTime = s.buffer_time_between_sessions;
      else if (s.buffer_time !== undefined) state.bufferTime = s.buffer_time;

      if (s.allow_walk_in_queue !== undefined) state.allowWalkInQueue = Boolean(s.allow_walk_in_queue);
      if (s.require_doctor_notes !== undefined) state.requireDoctorNotes = Boolean(s.require_doctor_notes);
      if (s.allow_delete_service !== undefined) state.allowDeleteService = Boolean(s.allow_delete_service);

      try {
        localStorage.setItem(STORAGE_KEYS.timeFormat, state.timeFormat);
        localStorage.setItem(STORAGE_KEYS.clockDisplay, state.clockDisplay);
        localStorage.setItem(STORAGE_KEYS.openTime, state.openTime);
        localStorage.setItem(STORAGE_KEYS.closeTime, state.closeTime);
        localStorage.setItem(STORAGE_KEYS.slotDuration, String(state.slotDuration));
        localStorage.setItem(STORAGE_KEYS.bufferTime, String(state.bufferTime));
        localStorage.setItem(STORAGE_KEYS.allowWalkInQueue, String(state.allowWalkInQueue));
        localStorage.setItem(STORAGE_KEYS.requireDoctorNotes, String(state.requireDoctorNotes));
        localStorage.setItem(STORAGE_KEYS.allowDeleteService, String(state.allowDeleteService));
      } catch (err) {
        console.error('Failed to save synced settings to localStorage', err);
      }
    },

    setTimeFormat(state, action: PayloadAction<'12' | '24'>) {
      state.timeFormat = action.payload;
      state.clockDisplay = action.payload === '24' ? '24h' : '12h';
      localStorage.setItem(STORAGE_KEYS.timeFormat, action.payload);
      localStorage.setItem(STORAGE_KEYS.clockDisplay, state.clockDisplay);
    },
  },
});

export const { saveAppointmentConfig, applySyncedSettings, setTimeFormat } =
  appointmentConfigSlice.actions;
export default appointmentConfigSlice.reducer;

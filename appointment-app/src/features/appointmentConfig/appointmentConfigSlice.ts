import { createSlice, type PayloadAction } from '@reduxjs/toolkit';

export interface AppointmentConfigState {
  timeFormat: '12' | '24';
  openTime: string;
  closeTime: string;
  slotDuration: number;
  bufferTime: number;
  allowWalkInQueue: boolean;
  requireDoctorNotes: boolean;
  allowDeleteService: boolean;
}

const STORAGE_KEYS = {
  timeFormat: 'time_format',
  openTime: 'open_time',
  closeTime: 'close_time',
  slotDuration: 'slot_duration',
  bufferTime: 'buffer_time',
  allowWalkInQueue: 'allow_walk_in_queue',
  requireDoctorNotes: 'require_doctor_notes',
  allowDeleteService: 'allow_delete_service',
};

function loadConfigFromStorage(): AppointmentConfigState {
  try {
    const timeFormat = (localStorage.getItem(STORAGE_KEYS.timeFormat) as '12' | '24') || '12';
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
    saveAppointmentConfig(state, action: PayloadAction<AppointmentConfigState>) {
      const payload = action.payload;
      state.timeFormat = payload.timeFormat;
      state.openTime = payload.openTime;
      state.closeTime = payload.closeTime;
      state.slotDuration = payload.slotDuration;
      state.bufferTime = payload.bufferTime;
      state.allowWalkInQueue = payload.allowWalkInQueue;
      state.requireDoctorNotes = payload.requireDoctorNotes;
      state.allowDeleteService = payload.allowDeleteService;

      try {
        localStorage.setItem(STORAGE_KEYS.timeFormat, payload.timeFormat);
        localStorage.setItem(STORAGE_KEYS.openTime, payload.openTime);
        localStorage.setItem(STORAGE_KEYS.closeTime, payload.closeTime);
        localStorage.setItem(STORAGE_KEYS.slotDuration, String(payload.slotDuration));
        localStorage.setItem(STORAGE_KEYS.bufferTime, String(payload.bufferTime));
        localStorage.setItem(STORAGE_KEYS.allowWalkInQueue, String(payload.allowWalkInQueue));
        localStorage.setItem(STORAGE_KEYS.requireDoctorNotes, String(payload.requireDoctorNotes));
        localStorage.setItem(STORAGE_KEYS.allowDeleteService, String(payload.allowDeleteService));
      } catch (err) {
        console.error('Failed to save config to localStorage', err);
      }
    },
    setTimeFormat(state, action: PayloadAction<'12' | '24'>) {
      state.timeFormat = action.payload;
      localStorage.setItem(STORAGE_KEYS.timeFormat, action.payload);
    },
  },
});

export const { saveAppointmentConfig, setTimeFormat } = appointmentConfigSlice.actions;
export default appointmentConfigSlice.reducer;

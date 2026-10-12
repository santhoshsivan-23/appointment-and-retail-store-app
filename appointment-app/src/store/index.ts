import { configureStore } from '@reduxjs/toolkit';
import authReducer from '../features/auth/authSlice';
import appointmentConfigReducer from '../features/appointmentConfig/appointmentConfigSlice';
import printerReducer from '../features/printer/printerSlice';

export const store = configureStore({
  reducer: {
    auth: authReducer,
    appointmentConfig: appointmentConfigReducer,
    printer: printerReducer,
  },
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;

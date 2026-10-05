import { configureStore } from '@reduxjs/toolkit';
import authReducer from '../features/auth/authSlice';
import appointmentConfigReducer from '../features/appointmentConfig/appointmentConfigSlice';

export const store = configureStore({
  reducer: {
    auth: authReducer,
    appointmentConfig: appointmentConfigReducer,
  },
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;

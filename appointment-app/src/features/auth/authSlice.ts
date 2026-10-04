import { createSlice, type PayloadAction } from '@reduxjs/toolkit';

export interface BusinessModel {
  id: number;
  business_name: string;
  business_type: string;
  owner_name: string;
  email: string;
  phone: string;
  address?: string;
  city?: string;
  country?: string;
  description?: string;
}

interface AuthState {
  token: string | null;
  business: BusinessModel | null;
  isAuthenticated: boolean;
  timeFormat: '12' | '24';
  isSidebarExpanded: boolean;
}

function loadFromStorage(): Partial<AuthState> {
  try {
    const token = localStorage.getItem('auth_token');
    const businessStr = localStorage.getItem('auth_business');
    const business = businessStr ? JSON.parse(businessStr) : null;
    return {
      token,
      business,
      isAuthenticated: !!token && !!business,
    };
  } catch {
    return {};
  }
}

const persisted = loadFromStorage();

const initialState: AuthState = {
  token: persisted.token ?? null,
  business: persisted.business ?? null,
  isAuthenticated: persisted.isAuthenticated ?? false,
  timeFormat: '12',
  isSidebarExpanded: true,
};

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    loginSuccess(state, action: PayloadAction<{ token: string; business: BusinessModel }>) {
      state.token = action.payload.token;
      state.business = action.payload.business;
      state.isAuthenticated = true;
      localStorage.setItem('auth_token', action.payload.token);
      localStorage.setItem('auth_business', JSON.stringify(action.payload.business));
    },
    registerSuccess(state, action: PayloadAction<{ token: string; business: BusinessModel }>) {
      state.token = action.payload.token;
      state.business = action.payload.business;
      state.isAuthenticated = true;
      localStorage.setItem('auth_token', action.payload.token);
      localStorage.setItem('auth_business', JSON.stringify(action.payload.business));
    },
    logout(state) {
      state.token = null;
      state.business = null;
      state.isAuthenticated = false;
      localStorage.removeItem('auth_token');
      localStorage.removeItem('auth_business');
    },
    toggleSidebar(state) {
      state.isSidebarExpanded = !state.isSidebarExpanded;
    },
    setSidebarExpanded(state, action: PayloadAction<boolean>) {
      state.isSidebarExpanded = action.payload;
    },
    setTimeFormat(state, action: PayloadAction<'12' | '24'>) {
      state.timeFormat = action.payload;
    },
  },
});

export const {
  loginSuccess,
  registerSuccess,
  logout,
  toggleSidebar,
  setSidebarExpanded,
  setTimeFormat,
} = authSlice.actions;

export default authSlice.reducer;

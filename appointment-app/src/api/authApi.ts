import { authService } from '../firebase/services/authService';

export interface LoginPayload {
  email: string;
  password: string;
}

export interface RegisterPayload {
  business_name: string;
  business_type: string;
  owner_name: string;
  email: string;
  phone: string;
  password: string;
  city?: string;
  country?: string;
}

export const authApi = {
  login: (data: LoginPayload) => authService.login(data),
  register: (data: RegisterPayload) => authService.register(data),
  getProfile: () => authService.getProfile(),
};

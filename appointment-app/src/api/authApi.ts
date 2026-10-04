import axiosClient from './axiosClient';

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
  login: (data: LoginPayload) => axiosClient.post('/auth/login', data),
  register: (data: RegisterPayload) => axiosClient.post('/auth/register', data),
  getProfile: () => axiosClient.get('/auth/me'),
};

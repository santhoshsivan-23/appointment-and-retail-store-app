import axiosClient from './axiosClient';

/* ── Types ─────────────────────────────────────────────── */
export interface SaleItem {
  product_id?: number;
  product_name: string;
  unit_price: number;
  quantity: number;
  discount: number;
  line_total: number;
}

export interface Sale {
  id: number;
  business_id: number;
  appointment_id: number | null;
  customer_id: number | null;
  customer_name: string;
  customer_phone: string;
  staff_id: number | null;
  staff_name: string;
  subtotal: number;
  item_discount_total: number;
  overall_discount: number;
  tax_amount: number;
  total_amount: number;
  payment_method: string;
  amount_tendered: number;
  change_amount: number;
  items: SaleItem[];
  notes: string;
  created_at?: string;
}

export interface CreateSalePayload {
  business_id?: number;
  appointment_id?: number | null;
  customer_id?: number | null;
  customer_name?: string;
  customer_phone?: string;
  staff_id?: number | null;
  staff_name?: string;
  subtotal: number;
  item_discount_total: number;
  overall_discount: number;
  tax_amount: number;
  total_amount: number;
  payment_method: string;
  amount_tendered: number;
  change_amount: number;
  items: SaleItem[];
  notes?: string;
}

export interface SaleQueryParams {
  appointment_id?: number;
  customer_id?: number;
  search?: string;
}

/* ── Helper functions matching Flutter SaleModel ───────── */
export function formatReceiptNumber(id: number, createdAt?: string): string {
  const dt = createdAt ? new Date(createdAt) : new Date();
  const yyyy = dt.getFullYear();
  const mm = String(dt.getMonth() + 1).padStart(2, '0');
  const dd = String(dt.getDate()).padStart(2, '0');
  const idStr = String(id).padStart(4, '0');
  return `#REC-${yyyy}${mm}${dd}-${idStr}`;
}

export function getPaymentMethodLabel(method: string): string {
  switch (method.toLowerCase()) {
    case 'cash':
      return 'CASH';
    case 'card':
      return 'CARD';
    case 'qr':
      return 'QR CODE';
    case 'other':
      return 'OTHER';
    default:
      return method.toUpperCase();
  }
}

/* ── API ───────────────────────────────────────────────── */
export const saleApi = {
  getAll: (params?: SaleQueryParams) =>
    axiosClient.get<{ success: boolean; data: Sale[]; count: number }>('/sales', {
      params,
    }),

  getById: (id: number) =>
    axiosClient.get<{ success: boolean; data: Sale }>(`/sales/${id}`),

  create: (data: CreateSalePayload) =>
    axiosClient.post<{ success: boolean; data: Sale; message: string }>('/sales', data),
};

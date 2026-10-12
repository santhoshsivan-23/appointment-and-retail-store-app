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

export interface RefundItem {
  product_id?: number;
  product_name: string;
  unit_price: number;
  quantity: number;
  original_quantity?: number;
  previously_refunded?: number;
  remaining_quantity?: number;
  line_discount_reversed?: number;
  overall_discount_reversed?: number;
  total_discount_reversed?: number;
  gst_reversed?: number;
  refund_amount: number;
}

export interface RefundRecord {
  id: number;
  refund_receipt_number: string;
  business_id?: number;
  sale_id?: number | null;
  appointment_id?: number | null;
  refund_type: 'partial' | 'full';
  subtotal_refunded: number;
  discount_reversed_total: number;
  gst_reversed_total: number;
  total_refund_amount: number;
  refund_method: string;
  reason?: string;
  notes?: string;
  items: RefundItem[];
  created_at: string;
}

export interface ProcessRefundPayload {
  items: Array<{
    product_id?: number;
    product_name: string;
    quantity: number;
  }>;
  reason?: string;
  notes?: string;
  refund_method?: string;
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
  refund_status?: 'none' | 'partial' | 'full';
  refunded_amount?: number;
  refunds?: RefundRecord[];
  gst_reversed_total?: number;
  net_tax_amount?: number;
  subtotal_refunded_total?: number;
  net_subtotal?: number;
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
  include_appointments?: string | boolean;
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

  getRefunds: (saleId: number) =>
    axiosClient.get<{ success: boolean; data: RefundRecord[]; count: number }>(
      `/sales/${saleId}/refunds`
    ),

  processRefund: (saleId: number, data: ProcessRefundPayload) =>
    axiosClient.post<{
      success: boolean;
      message: string;
      data: RefundRecord;
      sale: Sale;
    }>(`/sales/${saleId}/refund`, data),
};

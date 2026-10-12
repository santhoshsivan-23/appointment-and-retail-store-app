import axiosClient from './axiosClient';

/* ── Types ─────────────────────────────────────────────── */
export interface ComboItem {
  product_id: number;
  quantity: number;
  name: string;
}

export interface Product {
  id: number;
  business_id: number;
  category_id: number | null;
  name: string;
  sku: string;
  product_type: 'normal' | 'modifier' | 'combo';
  price: number;
  description: string;
  modifiers: number[];
  combo_items: ComboItem[];
  is_active: boolean;
  is_deleted?: boolean;
  deleted_at?: string;
  created_at?: string;
}

export interface ProductPayload {
  name: string;
  product_type?: string;
  price?: number;
  sku?: string;
  category_id?: number | null;
  description?: string;
  modifiers?: number[];
  combo_items?: ComboItem[];
}

export interface ProductQueryParams {
  category_id?: number;
  product_type?: string;
  search?: string;
}

export interface PaginationMeta {
  page: number;
  current_page: number;
  limit: number;
  page_size: number;
  total: number;
  totalPages: number;
  has_more: boolean;
  hasMore: boolean;
}

export interface PaginatedProductsResponse {
  success: boolean;
  data: Product[];
  pagination: PaginationMeta;
}

export interface ProductPaginationParams {
  page?: number;
  limit?: number;
  category_id?: number | string | null;
  product_type?: string;
  search?: string;
}

/* ── API ───────────────────────────────────────────────── */
export const productApi = {
  getAll: (params?: ProductQueryParams) =>
    axiosClient.get<{ data: Product[] }>('/products', { params }),

  getPaginated: (params?: ProductPaginationParams) =>
    axiosClient.get<PaginatedProductsResponse>('/products/cart-paginated', { params }),

  search: (keyword: string) =>
    axiosClient.get<{ success: boolean; count: number; data: Product[] }>('/products/search', {
      params: { q: keyword },
    }),

  create: (data: ProductPayload) =>
    axiosClient.post('/products', data),

  update: (id: number, data: Partial<ProductPayload>) =>
    axiosClient.put(`/products/${id}`, data),

  delete: (id: number) =>
    axiosClient.delete(`/products/${id}`),
};

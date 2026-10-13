import {
  collection,
  getDocs,
  doc,
  setDoc,
  updateDoc,
  query,
  where,
} from 'firebase/firestore';
import { db } from '../firebaseConfig';
import { getNextSequenceId } from '../utils/idGenerator';
import type {
  Product,
  ProductPayload,
  ProductQueryParams,
  ProductPaginationParams,
  PaginatedProductsResponse,
  PaginationMeta,
} from '../../api/productApi';

export const productService = {
  async getAll(params?: ProductQueryParams): Promise<{ data: { success: boolean; count: number; data: Product[] } }> {
    const prodCol = collection(db, 'products');
    const snap = await getDocs(prodCol);

    let list: Product[] = snap.docs.map((d) => {
      const data = d.data();
      return {
        id: Number(data.id) || Number(d.id) || 0,
        business_id: Number(data.business_id) || 1,
        category_id: data.category_id !== null && data.category_id !== undefined ? Number(data.category_id) : null,
        name: data.name || '',
        sku: data.sku || '',
        product_type: data.product_type || 'normal',
        price: Number(data.price) || 0,
        description: data.description || '',
        modifiers: Array.isArray(data.modifiers) ? data.modifiers : [],
        combo_items: Array.isArray(data.combo_items) ? data.combo_items : [],
        is_active: data.is_active !== false,
        is_deleted: Boolean(data.is_deleted),
        deleted_at: data.deleted_at || undefined,
        created_at: data.created_at || new Date().toISOString(),
      };
    });

    list = list.filter((p) => !p.is_deleted && p.is_active);

    if (params?.category_id && params.category_id !== ('all' as any) && params.category_id !== ('null' as any)) {
      list = list.filter((p) => String(p.category_id) === String(params.category_id));
    }

    if (params?.product_type) {
      list = list.filter((p) => p.product_type === params.product_type);
    }

    if (params?.search && params.search.trim()) {
      const s = params.search.trim().toLowerCase();
      list = list.filter(
        (p) =>
          (p.name || '').toLowerCase().includes(s) ||
          (p.sku || '').toLowerCase().includes(s) ||
          (p.description || '').toLowerCase().includes(s)
      );
    }

    list.sort((a, b) => b.id - a.id);

    return {
      data: {
        success: true,
        count: list.length,
        data: list,
      },
    };
  },

  async getPaginated(params?: ProductPaginationParams): Promise<{ data: PaginatedProductsResponse }> {
    const p = Math.max(1, Number(params?.page) || 1);
    const l = Math.max(1, Number(params?.limit) || 20);

    const fullRes = await this.getAll({
      category_id: params?.category_id ? Number(params.category_id) : undefined,
      product_type: params?.product_type,
      search: params?.search,
    });

    const allProducts = fullRes.data.data;
    const total = allProducts.length;
    const totalPages = Math.ceil(total / l) || 1;
    const offset = (p - 1) * l;
    const sliced = allProducts.slice(offset, offset + l);
    const hasMore = p < totalPages;

    const paginationMeta: PaginationMeta = {
      page: p,
      current_page: p,
      limit: l,
      page_size: l,
      total,
      totalPages,
      has_more: hasMore,
      hasMore,
    };

    return {
      data: {
        success: true,
        data: sliced,
        pagination: paginationMeta,
      },
    };
  },

  async search(keyword: string): Promise<{ data: { success: boolean; count: number; data: Product[] } }> {
    const fullRes = await this.getAll({ search: keyword });
    return fullRes;
  },

  async create(data: ProductPayload): Promise<{ data: { success: boolean; data: Product; message?: string } }> {
    if (!data.name || !data.name.trim()) {
      throw new Error('Product name is required.');
    }

    const nextId = await getNextSequenceId('products');
    const newProduct: Product = {
      id: nextId,
      business_id: 1,
      category_id: data.category_id ? Number(data.category_id) : null,
      name: data.name.trim(),
      sku: data.sku?.trim() || '',
      product_type: (data.product_type as any) || 'normal',
      price: Number(data.price) || 0,
      description: data.description?.trim() || '',
      modifiers: data.modifiers || [],
      combo_items: data.combo_items || [],
      is_active: true,
      is_deleted: false,
      created_at: new Date().toISOString(),
    };

    await setDoc(doc(db, 'products', String(nextId)), newProduct);

    return {
      data: {
        success: true,
        data: newProduct,
        message: 'Product created successfully',
      },
    };
  },

  async update(id: number, data: Partial<ProductPayload>): Promise<{ data: { success: boolean; data?: Product; message?: string } }> {
    const prodCol = collection(db, 'products');
    const snap = await getDocs(query(prodCol, where('id', '==', Number(id))));
    const targetDoc = snap.empty ? doc(db, 'products', String(id)) : snap.docs[0].ref;

    const payload: Record<string, any> = { ...data };
    delete payload.id;
    if (payload.price !== undefined) payload.price = Number(payload.price) || 0;
    if (payload.category_id !== undefined) {
      payload.category_id = payload.category_id ? Number(payload.category_id) : null;
    }

    await updateDoc(targetDoc, payload);

    return {
      data: {
        success: true,
        message: 'Product updated successfully',
      },
    };
  },

  async delete(id: number): Promise<{ data: { success: boolean; message: string } }> {
    const prodCol = collection(db, 'products');
    const snap = await getDocs(query(prodCol, where('id', '==', Number(id))));
    const targetDoc = snap.empty ? doc(db, 'products', String(id)) : snap.docs[0].ref;

    await updateDoc(targetDoc, {
      is_deleted: true,
      deleted_at: new Date().toISOString(),
    });

    return {
      data: {
        success: true,
        message: 'Product deleted successfully',
      },
    };
  },
};

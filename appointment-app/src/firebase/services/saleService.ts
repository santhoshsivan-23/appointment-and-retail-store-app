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
import { calculateRefundDetails } from '../utils/refundEngine';
import { staffService } from './staffService';
import { appointmentService } from './appointmentService';
import type {
  Sale,
  CreateSalePayload,
  SaleSummary,
  SaleQueryParams,
  RefundRecord,
  ProcessRefundPayload,
} from '../../api/saleApi';

export const saleService = {
  async getRefunds(saleId: number): Promise<{ data: { success: boolean; count: number; data: RefundRecord[] } }> {
    const refundsCol = collection(db, 'refunds');
    const snap = await getDocs(query(refundsCol, where('sale_id', '==', Number(saleId))));

    const list: RefundRecord[] = snap.docs.map((d) => {
      const data = d.data();
      return {
        id: Number(data.id) || Number(d.id) || 0,
        refund_receipt_number: data.refund_receipt_number || `#REF-${d.id}`,
        business_id: Number(data.business_id) || 1,
        sale_id: Number(data.sale_id) || Number(saleId),
        appointment_id: data.appointment_id ? Number(data.appointment_id) : null,
        refund_type: data.refund_type || 'partial',
        subtotal_refunded: Number(data.subtotal_refunded) || 0,
        discount_reversed_total: Number(data.discount_reversed_total) || 0,
        gst_reversed_total: Number(data.gst_reversed_total) || 0,
        total_refund_amount: Number(data.total_refund_amount) || 0,
        refund_method: data.refund_method || 'cash',
        reason: data.reason || '',
        notes: data.notes || '',
        items: Array.isArray(data.items) ? data.items : [],
        created_at: data.created_at || new Date().toISOString(),
      };
    });

    list.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());

    return {
      data: {
        success: true,
        count: list.length,
        data: list,
      },
    };
  },

  async getAll(params?: SaleQueryParams): Promise<{
    data: {
      success: boolean;
      data: Sale[];
      count: number;
      total?: number;
      page?: number;
      limit?: number;
      totalPages?: number;
    };
  }> {
    const salesCol = collection(db, 'sales');
    const snap = await getDocs(salesCol);

    // Fetch refunds for sales in-memory mapping
    const refundsCol = collection(db, 'refunds');
    const refSnap = await getDocs(refundsCol);
    const refundsBySale: Record<number, RefundRecord[]> = {};

    refSnap.docs.forEach((d) => {
      const data = d.data();
      const sId = Number(data.sale_id);
      if (sId) {
        if (!refundsBySale[sId]) refundsBySale[sId] = [];
        refundsBySale[sId].push({
          id: Number(data.id) || Number(d.id) || 0,
          refund_receipt_number: data.refund_receipt_number || '',
          business_id: Number(data.business_id) || 1,
          sale_id: sId,
          appointment_id: data.appointment_id ? Number(data.appointment_id) : null,
          refund_type: data.refund_type || 'partial',
          subtotal_refunded: Number(data.subtotal_refunded) || 0,
          discount_reversed_total: Number(data.discount_reversed_total) || 0,
          gst_reversed_total: Number(data.gst_reversed_total) || 0,
          total_refund_amount: Number(data.total_refund_amount) || 0,
          refund_method: data.refund_method || 'cash',
          reason: data.reason || '',
          notes: data.notes || '',
          items: Array.isArray(data.items) ? data.items : [],
          created_at: data.created_at || new Date().toISOString(),
        });
      }
    });

    let list: Sale[] = snap.docs.map((d) => {
      const data = d.data();
      const id = Number(data.id) || Number(d.id) || 0;
      const sRefunds = refundsBySale[id] || [];
      const totalRefunded = sRefunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
      const totalGstRefunded = sRefunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);
      const totalSubtotalRefunded = sRefunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);
      const origTax = Number(data.tax_amount) || 0;
      const origSubtotal = Number(data.subtotal) || 0;

      return {
        id,
        business_id: Number(data.business_id) || 1,
        appointment_id: data.appointment_id ? Number(data.appointment_id) : null,
        customer_id: data.customer_id ? Number(data.customer_id) : null,
        customer_name: data.customer_name || '',
        customer_phone: data.customer_phone || '',
        staff_id: data.staff_id ? Number(data.staff_id) : null,
        staff_name: data.staff_name || '',
        subtotal: Number(data.subtotal) || 0,
        item_discount_total: Number(data.item_discount_total) || 0,
        overall_discount: Number(data.overall_discount) || 0,
        tax_amount: Number(data.tax_amount) || 0,
        total_amount: Number(data.total_amount) || 0,
        payment_method: data.payment_method || 'cash',
        amount_tendered: Number(data.amount_tendered) || 0,
        change_amount: Number(data.change_amount) || 0,
        items: Array.isArray(data.items) ? data.items : [],
        notes: data.notes || '',
        created_at: data.created_at || new Date().toISOString(),
        refunds: sRefunds,
        refunded_amount: Number(data.refunded_amount) || totalRefunded,
        refund_status: data.refund_status || (sRefunds.length > 0 ? (totalRefunded >= Number(data.total_amount) ? 'full' : 'partial') : 'none'),
        gst_reversed_total: totalGstRefunded,
        net_tax_amount: Math.max(0, Math.round((origTax - totalGstRefunded) * 100) / 100),
        subtotal_refunded_total: totalSubtotalRefunded,
        net_subtotal: Math.max(0, Math.round((origSubtotal - totalSubtotalRefunded) * 100) / 100),
      };
    });

    // Check include_appointments parameter
    const includeAppts =
      params?.include_appointments === 'true' ||
      params?.include_appointments === true;
    if (!includeAppts) {
      list = list.filter((s) => !s.appointment_id || s.appointment_id === 0);
    }

    if (params?.appointment_id) {
      list = list.filter((s) => s.appointment_id === Number(params.appointment_id));
    }

    if (params?.customer_id) {
      list = list.filter((s) => s.customer_id === Number(params.customer_id));
    }

    if (params?.payment_method && params.payment_method !== 'all') {
      list = list.filter(
        (s) => s.payment_method.toLowerCase() === params.payment_method?.toLowerCase()
      );
    }

    const startDate = params?.start_date ? String(params.start_date).slice(0, 10) : null;
    const endDate = params?.end_date ? String(params.end_date).slice(0, 10) : null;

    if (startDate && endDate) {
      list = list.filter((s) => {
        const d = String(s.created_at || '').slice(0, 10);
        return d >= startDate && d <= endDate;
      });
    } else if (startDate) {
      list = list.filter((s) => String(s.created_at || '').slice(0, 10) >= startDate);
    } else if (endDate) {
      list = list.filter((s) => String(s.created_at || '').slice(0, 10) <= endDate);
    }

    if (params?.search && params.search.trim()) {
      const q = params.search.trim().toLowerCase();
      list = list.filter(
        (s) =>
          (s.customer_name || '').toLowerCase().includes(q) ||
          (s.customer_phone || '').toLowerCase().includes(q) ||
          (s.staff_name || '').toLowerCase().includes(q)
      );
    }

    list.sort((a, b) => new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime());

    const totalCount = list.length;
    if (params?.page && params?.limit) {
      const p = Math.max(1, Number(params.page));
      const l = Math.max(1, Number(params.limit));
      const offset = (p - 1) * l;
      const sliced = list.slice(offset, offset + l);
      return {
        data: {
          success: true,
          data: sliced,
          count: sliced.length,
          total: totalCount,
          page: p,
          limit: l,
          totalPages: Math.max(1, Math.ceil(totalCount / l)),
        },
      };
    }

    return {
      data: {
        success: true,
        count: list.length,
        data: list,
      },
    };
  },

  async getSummary(params?: {
    start_date?: string;
    end_date?: string;
    search?: string;
    payment_method?: string;
    include_appointments?: string | boolean;
  }): Promise<{ data: { success: boolean; data: SaleSummary } }> {
    const res = await this.getAll({
      start_date: params?.start_date,
      end_date: params?.end_date,
      search: params?.search,
      payment_method: params?.payment_method,
      include_appointments: params?.include_appointments,
    });

    const list = res.data.data;
    const total = list.length;
    const completed = total;
    const totalRevenue = list.reduce((sum, s) => sum + (Number(s.total_amount) || 0), 0);

    return {
      data: {
        success: true,
        data: {
          total,
          completed,
          total_revenue: Math.round(totalRevenue * 100) / 100,
        },
      },
    };
  },

  async getById(id: number): Promise<{ data: { success: boolean; data: Sale } }> {
    const res = await this.getAll({ include_appointments: true });
    const s = res.data.data.find((item) => item.id === Number(id));
    if (!s) {
      throw new Error('Sale not found.');
    }
    return {
      data: {
        success: true,
        data: s,
      },
    };
  },

  async create(data: CreateSalePayload): Promise<{ data: { success: boolean; data: Sale; message: string } }> {
    let resolvedStaffName = data.staff_name || '';
    if (!resolvedStaffName && data.staff_id) {
      try {
        const staffRes = await staffService.getById(data.staff_id);
        if (staffRes.data?.data) resolvedStaffName = staffRes.data.data.name;
      } catch (_) {}
    }

    const nextId = await getNextSequenceId('sales');
    const newSale: Sale = {
      id: nextId,
      business_id: data.business_id || 1,
      appointment_id: data.appointment_id || null,
      customer_id: data.customer_id || null,
      customer_name: data.customer_name || '',
      customer_phone: data.customer_phone || '',
      staff_id: data.staff_id || null,
      staff_name: resolvedStaffName,
      subtotal: Number(data.subtotal) || 0,
      item_discount_total: Number(data.item_discount_total) || 0,
      overall_discount: Number(data.overall_discount) || 0,
      tax_amount: Number(data.tax_amount) || 0,
      total_amount: Number(data.total_amount) || 0,
      payment_method: data.payment_method || 'cash',
      amount_tendered: Number(data.amount_tendered) || 0,
      change_amount: Number(data.change_amount) || 0,
      items: data.items || [],
      notes: data.notes || '',
      refund_status: 'none',
      refunded_amount: 0,
      refunds: [],
      created_at: new Date().toISOString(),
    };

    await setDoc(doc(db, 'sales', String(nextId)), newSale);

    // Auto-transition linked appointment to 'completed'
    if (data.appointment_id) {
      try {
        const apptRes = await appointmentService.getById(data.appointment_id);
        const appt = apptRes.data.data;
        if (appt && (appt.status === 'in_service' || appt.status === 'booked')) {
          await appointmentService.update(data.appointment_id, {
            status: 'completed',
            total_amount: Number(data.total_amount) || Number(appt.total_amount) || 0,
          });
        }
      } catch (e) {
        console.warn('Could not auto-transition linked appointment in Firestore:', e);
      }
    }

    return {
      data: {
        success: true,
        message: 'Sale recorded successfully!',
        data: newSale,
      },
    };
  },

  async processRefund(
    saleId: number,
    data: ProcessRefundPayload
  ): Promise<{
    data: {
      success: boolean;
      message: string;
      data: RefundRecord;
      sale: Sale;
    };
  }> {
    const saleRes = await this.getById(saleId);
    const sale = saleRes.data.data;

    const existingRefundsRes = await this.getRefunds(saleId);
    const existingRefunds = existingRefundsRes.data.data;

    const calc = calculateRefundDetails(sale, data.items, existingRefunds);

    const now = new Date();
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    const randomSuffix = Math.floor(1000 + Math.random() * 9000);
    const refundReceiptNumber = `#REF-${yyyy}${mm}${dd}-${sale.id}-${randomSuffix}`;

    const prevRefunded = existingRefunds.reduce((sum, rf) => sum + (Number(rf.total_refund_amount) || 0), 0);
    const newRefundedAmount = Math.round((prevRefunded + calc.total_refund_amount) * 100) / 100;
    const newStatus = calc.is_fully_refunded ? 'full' : 'partial';

    const nextRefId = await getNextSequenceId('refunds');
    const refundRecord: RefundRecord = {
      id: nextRefId,
      refund_receipt_number: refundReceiptNumber,
      business_id: sale.business_id || 1,
      sale_id: sale.id,
      appointment_id: sale.appointment_id || null,
      refund_type: calc.refund_type,
      subtotal_refunded: calc.subtotal_refunded,
      discount_reversed_total: calc.discount_reversed_total,
      gst_reversed_total: calc.gst_reversed_total,
      total_refund_amount: calc.total_refund_amount,
      refund_method: data.refund_method || sale.payment_method || 'cash',
      reason: data.reason || '',
      notes: data.notes || '',
      items: calc.items,
      created_at: now.toISOString(),
    };

    await setDoc(doc(db, 'refunds', String(nextRefId)), refundRecord);

    const salesCol = collection(db, 'sales');
    const snap = await getDocs(query(salesCol, where('id', '==', Number(sale.id))));
    const targetDoc = snap.empty ? doc(db, 'sales', String(sale.id)) : snap.docs[0].ref;

    await updateDoc(targetDoc, {
      refund_status: newStatus,
      refunded_amount: newRefundedAmount,
    });

    if (sale.appointment_id) {
      try {
        await appointmentService.update(sale.appointment_id, {
          refund_status: newStatus,
          refunded_amount: newRefundedAmount,
        } as any);
      } catch (_) {}
    }

    const updatedSale = await this.getById(sale.id);

    return {
      data: {
        success: true,
        message: 'Refund processed successfully!',
        data: refundRecord,
        sale: updatedSale.data.data,
      },
    };
  },
};

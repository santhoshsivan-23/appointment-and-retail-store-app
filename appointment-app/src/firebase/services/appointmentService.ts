import {
  collection,
  getDocs,
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
} from 'firebase/firestore';
import { db } from '../firebaseConfig';
import { getNextSequenceId } from '../utils/idGenerator';
import { calculateRefundDetails } from '../utils/refundEngine';
import { staffService } from './staffService';
import type {
  Appointment,
  AppointmentStatus,
  AppointmentSummary,
  AppointmentStats,
  CreateAppointmentPayload,
  CheckConflictPayload,
  CheckConflictResult,
} from '../../api/appointmentApi';
import type { RefundRecord, ProcessRefundPayload } from '../../api/saleApi';

function timeToMinutes(t?: string): number {
  if (!t) return 0;
  const parts = t.split(':');
  return (parseInt(parts[0], 10) || 0) * 60 + (parseInt(parts[1], 10) || 0);
}

export const appointmentService = {
  async getRefunds(id: number): Promise<{ data: { success: boolean; data: RefundRecord[]; count: number } }> {
    const refundsCol = collection(db, 'refunds');
    const snap = await getDocs(query(refundsCol, where('appointment_id', '==', Number(id))));

    const list: RefundRecord[] = snap.docs.map((d) => {
      const data = d.data();
      return {
        id: Number(data.id) || Number(d.id) || 0,
        refund_receipt_number: data.refund_receipt_number || `#REF-${d.id}`,
        business_id: Number(data.business_id) || 1,
        sale_id: data.sale_id ? Number(data.sale_id) : null,
        appointment_id: Number(data.appointment_id) || Number(id),
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

  async getAppointments(params?: {
    date?: string;
    start_date?: string;
    end_date?: string;
    staff_id?: number;
    search?: string;
    status?: string;
    page?: number;
    limit?: number;
  }): Promise<{
    data: {
      success: boolean;
      data: Appointment[];
      count: number;
      total?: number;
      page?: number;
      limit?: number;
      totalPages?: number;
    };
  }> {
    const apptsCol = collection(db, 'appointments');
    const snap = await getDocs(apptsCol);

    // Fetch all refunds once to optimize in-memory joins
    const refundsCol = collection(db, 'refunds');
    const refSnap = await getDocs(refundsCol);
    const refundsByAppt: Record<number, RefundRecord[]> = {};

    refSnap.docs.forEach((d) => {
      const data = d.data();
      const apptId = Number(data.appointment_id);
      if (apptId) {
        if (!refundsByAppt[apptId]) refundsByAppt[apptId] = [];
        refundsByAppt[apptId].push({
          id: Number(data.id) || Number(d.id) || 0,
          refund_receipt_number: data.refund_receipt_number || '',
          business_id: Number(data.business_id) || 1,
          sale_id: data.sale_id ? Number(data.sale_id) : null,
          appointment_id: apptId,
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

    let list: Appointment[] = snap.docs.map((d) => {
      const data = d.data();
      const id = Number(data.id) || Number(d.id) || 0;
      const aRefunds = refundsByAppt[id] || [];
      const totalRefunded = aRefunds.reduce((acc, rf) => acc + (Number(rf.total_refund_amount) || 0), 0);
      const totalGstRefunded = aRefunds.reduce((acc, rf) => acc + (Number(rf.gst_reversed_total) || 0), 0);
      const totalSubtotalRefunded = aRefunds.reduce((acc, rf) => acc + (Number(rf.subtotal_refunded) || 0), 0);
      const origTax = Number(data.tax_amount) || 0;
      const origSubtotal = Number(data.subtotal) || Number(data.total_amount) || 0;

      return {
        id,
        business_id: Number(data.business_id) || 1,
        staff_id: Number(data.staff_id) || 0,
        staff_name: data.staff_name || '',
        customer_id: data.customer_id !== null && data.customer_id !== undefined ? Number(data.customer_id) : null,
        customer_name: data.customer_name || '',
        customer_phone: data.customer_phone || '',
        appointment_date: String(data.appointment_date || '').slice(0, 10),
        start_time: data.start_time || '',
        end_time: data.end_time || '',
        status: (data.status as AppointmentStatus) || 'booked',
        total_amount: Number(data.total_amount) || 0,
        services: Array.isArray(data.services) ? data.services : [],
        notes: data.notes || '',
        created_at: data.created_at || new Date().toISOString(),
        refunds: aRefunds,
        refunded_amount: Number(data.refunded_amount) || totalRefunded,
        refund_status: data.refund_status || (aRefunds.length > 0 ? (totalRefunded >= Number(data.total_amount) ? 'full' : 'partial') : 'none'),
        gst_reversed_total: totalGstRefunded,
        net_tax_amount: Math.max(0, Math.round((origTax - totalGstRefunded) * 100) / 100),
        subtotal_refunded_total: totalSubtotalRefunded,
        net_subtotal: Math.max(0, Math.round((origSubtotal - totalSubtotalRefunded) * 100) / 100),
      };
    });

    const filterDate = params?.date ? String(params.date).slice(0, 10) : null;
    const startDate = params?.start_date ? String(params.start_date).slice(0, 10) : null;
    const endDate = params?.end_date ? String(params.end_date).slice(0, 10) : null;

    if (startDate && endDate) {
      list = list.filter((a) => a.appointment_date >= startDate && a.appointment_date <= endDate);
    } else if (startDate) {
      list = list.filter((a) => a.appointment_date >= startDate);
    } else if (endDate) {
      list = list.filter((a) => a.appointment_date <= endDate);
    } else if (filterDate) {
      list = list.filter((a) => a.appointment_date === filterDate);
    }

    if (params?.staff_id) {
      list = list.filter((a) => a.staff_id === Number(params.staff_id));
    }

    if (params?.status && params.status !== 'all') {
      list = list.filter((a) => a.status.toLowerCase() === params.status?.toLowerCase());
    }

    if (params?.search && params.search.trim()) {
      const q = params.search.trim().toLowerCase();
      list = list.filter((a) =>
        (a.customer_name || '').toLowerCase().includes(q) ||
        (a.customer_phone || '').toLowerCase().includes(q) ||
        (a.staff_name || '').toLowerCase().includes(q)
      );
    }

    // Sort order: if single date, sort by start_time ascending. Else, sort by date desc then start_time desc
    if (filterDate && !endDate) {
      list.sort((a, b) => (a.start_time || '').localeCompare(b.start_time || ''));
    } else {
      list.sort((a, b) => {
        const dCmp = (b.appointment_date || '').localeCompare(a.appointment_date || '');
        if (dCmp !== 0) return dCmp;
        return (b.start_time || '').localeCompare(a.start_time || '');
      });
    }

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
    date?: string;
    search?: string;
  }): Promise<{ data: { success: boolean; data: AppointmentSummary } }> {
    const res = await this.getAppointments({
      start_date: params?.start_date,
      end_date: params?.end_date,
      date: params?.date,
      search: params?.search,
    });

    const list = res.data.data;
    const total = list.length;
    const completedList = list.filter((a) => {
      const st = a.status.toLowerCase();
      return st === 'completed' || st === 'performed';
    });
    const completed = completedList.length;
    const totalRevenue = completedList.reduce((sum, a) => sum + (Number(a.total_amount) || 0), 0);

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

  async getStats(date?: string): Promise<{ data: { success: boolean; date?: string; data: AppointmentStats } }> {
    const res = await this.getAppointments({ date });
    const appts = res.data.data;

    const stats: AppointmentStats = {
      total: appts.length,
      booked: 0,
      in_service: 0,
      completed: 0,
      no_show: 0,
      cancelled: 0,
    };

    for (const a of appts) {
      const s = (a.status || '').toLowerCase().trim();
      if (s === 'booked') {
        stats.booked++;
      } else if (s === 'in_service' || s === 'inservice' || s === 'in-service') {
        stats.in_service++;
      } else if (s === 'completed') {
        stats.completed++;
      } else if (s === 'no_show' || s === 'noshow' || s === 'no-show') {
        stats.no_show++;
      } else if (s === 'cancelled' || s === 'canceled') {
        stats.cancelled++;
      }
    }

    return {
      data: {
        success: true,
        date,
        data: stats,
      },
    };
  },

  async getById(id: number): Promise<{ data: { success: boolean; data: Appointment } }> {
    const res = await this.getAppointments();
    const appt = res.data.data.find((a) => a.id === Number(id));
    if (!appt) {
      throw new Error('Appointment not found.');
    }
    return {
      data: {
        success: true,
        data: appt,
      },
    };
  },

  async checkConflict(payload: CheckConflictPayload): Promise<{ data: { success: boolean } & CheckConflictResult }> {
    const newStart = timeToMinutes(payload.start_time);
    const newEnd = timeToMinutes(payload.end_time);

    const res = await this.getAppointments({
      date: payload.appointment_date,
      staff_id: payload.staff_id,
    });

    const activeAppts = res.data.data.filter((a) => {
      if (payload.exclude_id && String(a.id) === String(payload.exclude_id)) return false;
      return ['booked', 'in_service', 'completed'].includes(a.status);
    });

    for (const a of activeAppts) {
      const aStart = timeToMinutes(a.start_time);
      const aEnd = timeToMinutes(a.end_time);
      if (newStart < aEnd && aStart < newEnd) {
        return {
          data: {
            success: true,
            has_conflict: true,
            conflicting_appointment: {
              id: a.id,
              customer_name: a.customer_name,
              start_time: a.start_time,
              end_time: a.end_time,
              status: a.status,
            },
            message: `Staff member is already booked from ${a.start_time} to ${a.end_time}.`,
          },
        };
      }
    }

    return {
      data: {
        success: true,
        has_conflict: false,
      },
    };
  },

  async create(payload: CreateAppointmentPayload): Promise<{ data: { success: boolean; message: string; data: Appointment } }> {
    let resolvedStaffName = payload.staff_name || '';
    if (!resolvedStaffName && payload.staff_id) {
      try {
        const staffRes = await staffService.getById(payload.staff_id);
        if (staffRes.data?.data) resolvedStaffName = staffRes.data.data.name;
      } catch (_) {}
    }

    const nextId = await getNextSequenceId('appointments');
    const newAppt: Appointment = {
      id: nextId,
      business_id: payload.business_id || 1,
      staff_id: payload.staff_id,
      staff_name: resolvedStaffName,
      customer_id: payload.customer_id || null,
      customer_name: payload.customer_name || '',
      customer_phone: payload.customer_phone || '',
      appointment_date: String(payload.appointment_date).slice(0, 10),
      start_time: payload.start_time,
      end_time: payload.end_time,
      status: 'booked',
      total_amount: Number(payload.total_amount) || 0,
      services: payload.services || [],
      notes: payload.notes || '',
      refund_status: 'none',
      refunded_amount: 0,
      refunds: [],
      created_at: new Date().toISOString(),
    };

    await setDoc(doc(db, 'appointments', String(nextId)), newAppt);

    return {
      data: {
        success: true,
        message: 'Appointment created successfully!',
        data: newAppt,
      },
    };
  },

  async update(
    id: number,
    payload: Partial<CreateAppointmentPayload> & { status?: AppointmentStatus }
  ): Promise<{ data: { success: boolean; message: string; data: Appointment } }> {
    const apptsCol = collection(db, 'appointments');
    const snap = await getDocs(query(apptsCol, where('id', '==', Number(id))));
    const targetDoc = snap.empty ? doc(db, 'appointments', String(id)) : snap.docs[0].ref;

    const updateData: Record<string, any> = { ...payload };
    delete updateData.id;
    if (updateData.total_amount !== undefined) {
      updateData.total_amount = Number(updateData.total_amount) || 0;
    }

    await updateDoc(targetDoc, updateData);
    const updated = await this.getById(id);

    return {
      data: {
        success: true,
        message: 'Appointment updated successfully!',
        data: updated.data.data,
      },
    };
  },

  async updateStatus(
    id: number,
    status: AppointmentStatus
  ): Promise<{ data: { success: boolean; message: string; data: Appointment } }> {
    return this.update(id, { status });
  },

  async delete(id: number): Promise<{ data: { success: boolean; message: string } }> {
    const apptsCol = collection(db, 'appointments');
    const snap = await getDocs(query(apptsCol, where('id', '==', Number(id))));
    const targetDoc = snap.empty ? doc(db, 'appointments', String(id)) : snap.docs[0].ref;

    await deleteDoc(targetDoc);

    return {
      data: {
        success: true,
        message: 'Appointment deleted.',
      },
    };
  },

  async processRefund(
    id: number,
    data: ProcessRefundPayload
  ): Promise<{
    data: {
      success: boolean;
      message: string;
      data: RefundRecord;
      appointment: Appointment;
      sale?: any;
    };
  }> {
    const apptRes = await this.getById(id);
    const appt = apptRes.data.data;

    const existingRefundsRes = await this.getRefunds(id);
    const existingRefunds = existingRefundsRes.data.data;

    const calc = calculateRefundDetails(appt, data.items, existingRefunds);

    const now = new Date();
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    const randomSuffix = Math.floor(1000 + Math.random() * 9000);
    const refundReceiptNumber = `#REF-${yyyy}${mm}${dd}-APT-${appt.id}-${randomSuffix}`;

    const prevRefunded = existingRefunds.reduce((sum, rf) => sum + (Number(rf.total_refund_amount) || 0), 0);
    const newRefundedAmount = Math.round((prevRefunded + calc.total_refund_amount) * 100) / 100;
    const newStatus = calc.is_fully_refunded ? 'full' : 'partial';

    const nextRefId = await getNextSequenceId('refunds');
    const refundRecord: RefundRecord = {
      id: nextRefId,
      refund_receipt_number: refundReceiptNumber,
      business_id: appt.business_id || 1,
      sale_id: null,
      appointment_id: appt.id,
      refund_type: calc.refund_type,
      subtotal_refunded: calc.subtotal_refunded,
      discount_reversed_total: calc.discount_reversed_total,
      gst_reversed_total: calc.gst_reversed_total,
      total_refund_amount: calc.total_refund_amount,
      refund_method: data.refund_method || 'cash',
      reason: data.reason || '',
      notes: data.notes || '',
      items: calc.items,
      created_at: now.toISOString(),
    };

    await setDoc(doc(db, 'refunds', String(nextRefId)), refundRecord);

    await this.update(appt.id, {
      refund_status: newStatus,
      refunded_amount: newRefundedAmount,
    } as any);

    const updatedAppt = await this.getById(appt.id);

    return {
      data: {
        success: true,
        message: 'Refund processed successfully!',
        data: refundRecord,
        appointment: updatedAppt.data.data,
      },
    };
  },
};

import { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import { toast } from 'react-toastify';
import {
  Calendar as CalendarIcon,
  ChevronLeft,
  ChevronRight,
  RefreshCw,
  Search,
  X,
  Plus,
  Clock,
  User,
  Phone,
  Play,
  Pause,
  Trash2,
  AlertCircle,
  Lock,
  Timer,
  Check,
  RotateCcw,
  CalendarCheck,
  CalendarX,
  UserX,
  Store,
  Eye,
  EyeOff,
  UserCheck,
} from 'lucide-react';
import { useAppSelector } from '../store/hooks';
import {
  appointmentApi,
  type Appointment,
  type AppointmentStatus,
  type AppointmentStats,
} from '../api/appointmentApi';
import { staffApi, type Staff } from '../api/staffApi';
import { categoryApi, type Category } from '../api/categoryApi';
import { productApi, type Product } from '../api/productApi';
import { customerApi, type Customer } from '../api/customerApi';
import '../styles/appointment.css';

/* ── Constants ───────────────────────────────────────────────────────────── */
const STAFF_COLORS = [
  '#7C3AED', // Purple
  '#F59E0B', // Amber
  '#E11D48', // Rose
  '#0EA5E9', // Sky
  '#10B981', // Emerald
  '#8B5CF6', // Violet
  '#EF4444', // Red
  '#06B6D4', // Cyan
];

const WEEKDAYS_LONG = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];
const MONTHS_SHORT = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const MONTHS_FULL = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const SLOT_HEIGHT = 56; // 30-min slot = 56px

/* ── Time Math & Formatting Helpers ──────────────────────────────────────── */
export function timeToMinutes(time24: string): number {
  if (!time24) return 0;
  const trimmed = time24.trim();
  const parts = trimmed.split(':');
  if (parts.length >= 2) {
    const h = parseInt(parts[0] || '0', 10) || 0;
    const m = parseInt(parts[1] || '0', 10) || 0;
    return h * 60 + m;
  } else if (trimmed.length === 4) {
    const h = parseInt(trimmed.substring(0, 2), 10) || 0;
    const m = parseInt(trimmed.substring(2), 10) || 0;
    return h * 60 + m;
  }
  return 0;
}

export function minutesToTime24(totalMinutes: number): string {
  const h = Math.floor(totalMinutes / 60) % 24;
  const m = totalMinutes % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

export function addMinutesTo24h(time24: string, minutesToAdd: number): string {
  const mins = timeToMinutes(time24) + minutesToAdd;
  return minutesToTime24(mins);
}

export function split24To12(time24: string): { time: string; period: 'AM' | 'PM' } {
  let h = 9;
  let m = 0;
  if (time24) {
    const trimmed = time24.trim();
    const parts = trimmed.split(':');
    if (parts.length >= 2) {
      h = parseInt(parts[0] || '9', 10) || 0;
      m = parseInt(parts[1] || '0', 10) || 0;
    } else if (trimmed.length === 4) {
      h = parseInt(trimmed.substring(0, 2), 10) || 0;
      m = parseInt(trimmed.substring(2), 10) || 0;
    }
  }
  const period: 'AM' | 'PM' = h >= 12 ? 'PM' : 'AM';
  let h12 = h % 12;
  if (h12 === 0) h12 = 12;
  return {
    time: `${String(h12).padStart(2, '0')}:${String(m).padStart(2, '0')}`,
    period,
  };
}

export function convert12To24(time12: string, period: string): string {
  let h = 9;
  let m = 0;
  if (time12) {
    const parts = time12.split(':');
    h = parseInt(parts[0] || '9', 10) || 0;
    m = parseInt(parts[1] || '0', 10) || 0;
  }
  if (period.toUpperCase() === 'AM') {
    if (h === 12) h = 0;
  } else {
    if (h < 12) h += 12;
  }
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

export function formatSlotLabel(time24: string, timeFormat: '12' | '24'): string {
  if (timeFormat === '12') {
    const split = split24To12(time24);
    return `${split.time} ${split.period}`;
  }
  return time24;
}

export function formatApptTimeRange(
  startTime: string,
  endTime: string,
  timeFormat: '12' | '24'
): string {
  if (timeFormat === '12') {
    const s = split24To12(startTime);
    const e = split24To12(endTime);
    return `${s.time} ${s.period} - ${e.time} ${e.period}`;
  }
  return `${startTime} - ${endTime}`;
}

export function isSlotOutsideBusiness(
  time24: string,
  openTime: string,
  closeTime: string
): boolean {
  const slotM = timeToMinutes(time24);
  const openM = timeToMinutes(openTime);
  const closeM = timeToMinutes(closeTime);
  return slotM < openM || slotM >= closeM;
}

export function formatDateYMD(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function formatDateLong(d: Date): string {
  return `${WEEKDAYS_LONG[d.getDay()]}, ${d.getDate()} ${
    MONTHS_SHORT[d.getMonth()]
  } ${d.getFullYear()}`;
}

const fmtMoney = (val: number | string | null | undefined): string => {
  if (val === null || val === undefined) return '0.00';
  const num = typeof val === 'number' ? val : parseFloat(String(val));
  return isNaN(num) ? '0.00' : num.toFixed(2);
};

/* ── Props ───────────────────────────────────────────────────────────────── */
interface AppointmentViewProps {
  onStartService?: (
    customer: Customer,
    products: Product[],
    appointment?: Appointment
  ) => void;
}

/* ==========================================================================
   COMPONENT: AppointmentView
   ========================================================================== */
export default function AppointmentView({ onStartService }: AppointmentViewProps) {
  // Redux configuration
  const config = useAppSelector((s) => s.appointmentConfig);
  const timeFormat = config.timeFormat || '12';
  const openTime = config.openTime || '08:00';
  const closeTime = config.closeTime || '20:00';
  const configuredSlotDuration = config.slotDuration || 30;
  const allowDeleteService = config.allowDeleteService || false;

  // Data states
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [staffList, setStaffList] = useState<Staff[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  // Overview stats & status filter
  const [overviewStats, setOverviewStats] = useState<AppointmentStats>({
    total: 0,
    booked: 0,
    in_service: 0,
    completed: 0,
    no_show: 0,
    cancelled: 0,
  });
  const [selectedStatusFilter, setSelectedStatusFilter] = useState<
    AppointmentStatus | null
  >(null);

  // Calendar & Date navigation state
  const [selectedDate, setSelectedDate] = useState<Date>(new Date());
  const [calendarMonth, setCalendarMonth] = useState<Date>(
    new Date(new Date().getFullYear(), new Date().getMonth(), 1)
  );
  const [selectedStaffFilter, setSelectedStaffFilter] = useState<number | null>(
    null
  );
  const [isCalendarHidden, setIsCalendarHidden] = useState<boolean>(false);

  // Top Customer search bar query & overlay dropdown
  const [customerSearchQuery, setCustomerSearchQuery] = useState<string>('');
  const [isCustomerSearchFocused, setIsCustomerSearchFocused] =
    useState<boolean>(false);

  // Synchronized scrolling refs
  const headerScrollRef = useRef<HTMLDivElement>(null);
  const bodyScrollRef = useRef<HTMLDivElement>(null);
  const currentTimeBadgeRef = useRef<HTMLDivElement>(null);
  const isSyncingScrollRef = useRef<boolean>(false);
  const hasInitialScrolledRef = useRef<boolean>(false);

  // Live Current Time Runner (updates every 1s)
  const [currentTime, setCurrentTime] = useState<Date>(new Date());

  // Drag and Drop state
  const [draggingApptId, setDraggingApptId] = useState<number | null>(null);
  const [dragOverTarget, setDragOverTarget] = useState<{
    staffId: number;
    slot: string;
  } | null>(null);

  // Active Modals state
  const [modalNewApptOpen, setModalNewApptOpen] = useState<boolean>(false);
  const [modalNewApptPreset, setModalNewApptPreset] = useState<{
    staff?: Staff;
    startTime?: string;
    endTime?: string;
    date?: Date;
  } | null>(null);

  const [modalDetailsAppt, setModalDetailsAppt] = useState<Appointment | null>(
    null
  );
  const [modalRescheduleAppt, setModalRescheduleAppt] =
    useState<Appointment | null>(null);
  const [modalStaffInfo, setModalStaffInfo] = useState<{
    staff: Staff;
    color: string;
  } | null>(null);
  const [deleteConfirmAppt, setDeleteConfirmAppt] =
    useState<Appointment | null>(null);

  /* ── 1. Live Time Runner ───────────────────────────────────────────────── */
  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date());
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  /* ── 2. Data Loader ────────────────────────────────────────────────────── */
  const loadData = useCallback(async () => {
    setIsLoading(true);
    try {
      const dateStr = formatDateYMD(selectedDate);
      const [apptsRes, staffRes, catsRes, prodsRes, statsRes] =
        await Promise.all([
          appointmentApi.getAppointments({ date: dateStr }),
          staffApi.getAll(true),
          categoryApi.getAll(),
          productApi.getAll(),
          appointmentApi.getStats(dateStr),
        ]);

      const rawAppts = apptsRes.data.data || [];
      const loadedAppts: Appointment[] = rawAppts.map((a: any) => {
        let svcs: any[] = [];
        if (Array.isArray(a.services)) {
          svcs = a.services;
        } else if (typeof a.services === 'string' && a.services.trim().length > 0) {
          try {
            const parsed = JSON.parse(a.services);
            if (Array.isArray(parsed)) svcs = parsed;
          } catch (_) {}
        }
        const cleanDate =
          typeof a.appointment_date === 'string'
            ? a.appointment_date.split('T')[0].trim()
            : '';
        return {
          ...a,
          appointment_date: cleanDate,
          services: svcs,
        };
      });
      const allStaff = staffRes.data.data || [];

      // Ensure all active staff or staff who have appointments on this date are present
      const staffMap = new Map<number, Staff>();
      allStaff.forEach((s) => staffMap.set(s.id, s));

      const resolvedStaff: Staff[] = [];
      allStaff.forEach((s) => {
        const isActive = s.is_active === true || s.is_active === 1;
        if (isActive) {
          resolvedStaff.push(s);
        }
      });

      loadedAppts.forEach((a) => {
        if (!resolvedStaff.some((s) => s.id === a.staff_id)) {
          if (staffMap.has(a.staff_id)) {
            resolvedStaff.push(staffMap.get(a.staff_id)!);
          } else {
            resolvedStaff.push({
              id: a.staff_id,
              business_id: a.business_id,
              name: a.staff_name || `Staff #${a.staff_id}`,
              role: 'Staff',
              is_active: false,
            });
          }
        }
      });

      setAppointments(loadedAppts);
      setStaffList(resolvedStaff);
      setCategories(catsRes.data.data || []);
      setProducts(prodsRes.data.data || []);
      if (statsRes.data.data) {
        setOverviewStats(statsRes.data.data);
      }
    } catch (err: any) {
      console.error('Failed to load appointments data:', err);
      toast.error('Failed to load appointment schedule');
    } finally {
      setIsLoading(false);
    }
  }, [selectedDate]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  /* ── 3. Grid Bounds Calculation ────────────────────────────────────────── */
  const { gridStartHour, gridEndHour, timeSlots } = useMemo(() => {
    let openH = 8;
    let closeH = 20;
    const openParts = openTime.split(':');
    if (openParts.length > 0) openH = parseInt(openParts[0] || '8', 10) || 8;
    const closeParts = closeTime.split(':');
    if (closeParts.length > 0) {
      const ch = parseInt(closeParts[0] || '20', 10) || 20;
      const cm = parseInt(closeParts[1] || '0', 10) || 0;
      closeH = cm > 0 ? ch + 1 : ch;
    }

    let minHour = openH;
    let maxHour = closeH;
    appointments.forEach((a) => {
      const startH = Math.floor(timeToMinutes(a.start_time) / 60);
      const endH = Math.ceil(timeToMinutes(a.end_time) / 60);
      if (startH < minHour) minHour = startH;
      if (endH > maxHour) maxHour = endH;
    });

    const startH = Math.max(0, Math.min(minHour, 23));
    const endH = Math.min(24, Math.max(maxHour, startH + 1));

    const slots: string[] = [];
    for (let h = startH; h < endH; h++) {
      slots.push(`${String(h).padStart(2, '0')}:00`);
      slots.push(`${String(h).padStart(2, '0')}:30`);
    }

    return { gridStartHour: startH, gridEndHour: endH, timeSlots: slots };
  }, [openTime, closeTime, appointments]);

  const gridBaseMinutes = gridStartHour * 60;
  const gridTotalHeight = timeSlots.length * SLOT_HEIGHT;

  /* ── 5. Display Filter Calculations ────────────────────────────────────── */
  const displayedStaff = useMemo(() => {
    if (selectedStaffFilter !== null) {
      return staffList.filter((s) => s.id === selectedStaffFilter);
    }
    return staffList;
  }, [staffList, selectedStaffFilter]);

  const staffColWidth = Math.max(
    220,
    Math.floor(100 / Math.max(1, displayedStaff.length))
  );

  /* ── 4. Scroll Sync & Current Time Badge Position ──────────────────────── */
  const updateCurrentTimeBadgePosition = useCallback(() => {
    if (bodyScrollRef.current && currentTimeBadgeRef.current) {
      const scrollX = bodyScrollRef.current.scrollLeft;
      const visibleStaffWidth = Math.max(
        0,
        bodyScrollRef.current.clientWidth - 84
      );
      const totalStaffWidth = displayedStaff.length * staffColWidth;
      const badgeWidth = timeFormat === '12' ? 122 : 98;

      const badgeX = Math.min(
        Math.max(scrollX + 6, scrollX + visibleStaffWidth - badgeWidth - 14),
        Math.max(totalStaffWidth - badgeWidth - 8, scrollX + 6)
      );

      currentTimeBadgeRef.current.style.left = `${badgeX}px`;
    }
  }, [displayedStaff.length, staffColWidth, timeFormat]);

  const handleBodyScroll = () => {
    if (isSyncingScrollRef.current) return;
    if (bodyScrollRef.current) {
      isSyncingScrollRef.current = true;
      if (headerScrollRef.current) {
        headerScrollRef.current.scrollLeft = bodyScrollRef.current.scrollLeft;
      }
      updateCurrentTimeBadgePosition();
      isSyncingScrollRef.current = false;
    }
  };

  const handleHeaderScroll = () => {
    if (isSyncingScrollRef.current) return;
    if (headerScrollRef.current && bodyScrollRef.current) {
      isSyncingScrollRef.current = true;
      bodyScrollRef.current.scrollLeft = headerScrollRef.current.scrollLeft;
      isSyncingScrollRef.current = false;
    }
  };

  // Keep badge in sync when calendar is toggled or window resized
  useEffect(() => {
    updateCurrentTimeBadgePosition();
    const timer = setTimeout(updateCurrentTimeBadgePosition, 320);
    return () => clearTimeout(timer);
  }, [isCalendarHidden, updateCurrentTimeBadgePosition]);

  useEffect(() => {
    window.addEventListener('resize', updateCurrentTimeBadgePosition);
    return () =>
      window.removeEventListener('resize', updateCurrentTimeBadgePosition);
  }, [updateCurrentTimeBadgePosition]);

  // Initial scroll to current time on load
  useEffect(() => {
    if (isLoading || hasInitialScrolledRef.current) return;
    if (bodyScrollRef.current) {
      const now = new Date();
      const isToday =
        selectedDate.getFullYear() === now.getFullYear() &&
        selectedDate.getMonth() === now.getMonth() &&
        selectedDate.getDate() === now.getDate();
      if (isToday) {
        const nowMinutes = now.getHours() * 60 + now.getMinutes();
        const top = ((nowMinutes - gridBaseMinutes) / 30) * SLOT_HEIGHT;
        bodyScrollRef.current.scrollTop = Math.max(0, top - 120);
      }
      hasInitialScrolledRef.current = true;
      updateCurrentTimeBadgePosition();
    }
  }, [isLoading, selectedDate, gridBaseMinutes, updateCurrentTimeBadgePosition]);

  const staffColor = (index: number) => STAFF_COLORS[index % STAFF_COLORS.length];

  const appointmentsForStaff = (staffId: number) => {
    let list = appointments.filter((a) => a.staff_id === staffId);
    if (selectedStatusFilter !== null) {
      list = list.filter((a) => a.status === selectedStatusFilter);
    }
    return list;
  };

  const countForStaff = (staffId: number) => {
    return appointments.filter((a) => a.staff_id === staffId).length;
  };

  /* ── 6. Header Date Nav Actions ────────────────────────────────────────── */
  const goToday = () => {
    const today = new Date();
    setSelectedDate(today);
    setCalendarMonth(new Date(today.getFullYear(), today.getMonth(), 1));
  };

  const goPrevDay = () => {
    const prev = new Date(selectedDate);
    prev.setDate(prev.getDate() - 1);
    setSelectedDate(prev);
    setCalendarMonth(new Date(prev.getFullYear(), prev.getMonth(), 1));
  };

  const goNextDay = () => {
    const next = new Date(selectedDate);
    next.setDate(next.getDate() + 1);
    setSelectedDate(next);
    setCalendarMonth(new Date(next.getFullYear(), next.getMonth(), 1));
  };

  /* ── 7. Top Customer Search Results Overlay ────────────────────────────── */
  const searchResults = useMemo(() => {
    if (!customerSearchQuery.trim()) return [];
    const q = customerSearchQuery.trim().toLowerCase();
    return appointments.filter(
      (a) =>
        (a.customer_name && a.customer_name.toLowerCase().includes(q)) ||
        (a.customer_phone && a.customer_phone.toLowerCase().includes(q))
    );
  }, [appointments, customerSearchQuery]);

  /* ── 8. Drag and Drop Rescheduling ─────────────────────────────────────── */
  const isSlotBlockedForDrag = (
    draggedAppt: Appointment,
    targetStaff: Staff,
    slotTime: string
  ): boolean => {
    const slotStartM = timeToMinutes(slotTime);
    const duration =
      timeToMinutes(draggedAppt.end_time) -
      timeToMinutes(draggedAppt.start_time);
    const effDuration = duration > 0 ? duration : configuredSlotDuration;
    const slotEndM = slotStartM + effDuration;

    // Block outside business hours
    if (isSlotOutsideBusiness(slotTime, openTime, closeTime)) return true;
    if (slotEndM > timeToMinutes(closeTime)) return true;

    // Overlap check on this staff
    return appointments.some((a) => {
      if (a.id === draggedAppt.id || a.staff_id !== targetStaff.id) return false;
      if (a.status === 'cancelled' || a.status === 'no_show') return false;
      const aStart = timeToMinutes(a.start_time);
      const aEnd = timeToMinutes(a.end_time);
      return slotStartM < aEnd && aStart < slotEndM;
    });
  };

  const handleDragDropReschedule = async (
    draggedAppt: Appointment,
    targetStaff: Staff,
    targetSlot: string
  ) => {
    setDraggingApptId(null);
    setDragOverTarget(null);

    // Only allow for booked or in_service
    if (draggedAppt.status !== 'booked' && draggedAppt.status !== 'in_service') {
      return;
    }

    const duration =
      timeToMinutes(draggedAppt.end_time) -
      timeToMinutes(draggedAppt.start_time);
    const effDuration = duration > 0 ? duration : configuredSlotDuration;
    const newEndTime = addMinutesTo24h(targetSlot, effDuration);

    const isSameStaff = draggedAppt.staff_id === targetStaff.id;
    const isSameTime = draggedAppt.start_time === targetSlot;
    if (isSameStaff && isSameTime) return;

    if (isSlotBlockedForDrag(draggedAppt, targetStaff, targetSlot)) {
      toast.error(
        `Cannot reschedule to ${formatSlotLabel(
          targetSlot,
          timeFormat
        )}: Slot is occupied or outside business hours.`
      );
      return;
    }

    const dateStr = formatDateYMD(selectedDate);
    const originalAppt = { ...draggedAppt };

    // Optimistic UI Update
    setAppointments((prev) =>
      prev.map((a) =>
        a.id === draggedAppt.id
          ? {
              ...a,
              staff_id: targetStaff.id,
              staff_name: targetStaff.name,
              appointment_date: dateStr,
              start_time: targetSlot,
              end_time: newEndTime,
            }
          : a
      )
    );

    try {
      await appointmentApi.update(draggedAppt.id, {
        staff_id: targetStaff.id,
        staff_name: targetStaff.name,
        appointment_date: dateStr,
        start_time: targetSlot,
        end_time: newEndTime,
      });

      const sLabel = formatSlotLabel(targetSlot, timeFormat);
      const eLabel = formatSlotLabel(newEndTime, timeFormat);
      const changeDesc = isSameStaff
        ? `time to ${sLabel} - ${eLabel}`
        : `to ${targetStaff.name} at ${sLabel} - ${eLabel}`;
      toast.success(`Rescheduled "${draggedAppt.customer_name}" ${changeDesc}`);

      // Silent refresh
      const [refreshed, stats] = await Promise.all([
        appointmentApi.getAppointments({ date: dateStr }),
        appointmentApi.getStats(dateStr),
      ]);
      setAppointments(refreshed.data.data || []);
      if (stats.data.data) setOverviewStats(stats.data.data);
    } catch {
      // Rollback
      setAppointments((prev) =>
        prev.map((a) => (a.id === draggedAppt.id ? originalAppt : a))
      );
      toast.error('Failed to reschedule appointment on server.');
    }
  };

  /* ── 9. Service Flow Link to Cart POS ─────────────────────────────────── */
  const continueServiceInCart = (appt: Appointment) => {
    if (!onStartService) {
      toast.info('POS Cart connection ready');
      return;
    }

    const customerObj: Customer = {
      id: appt.customer_id || 0,
      business_id: appt.business_id,
      name: appt.customer_name || 'Walk-in Customer',
      phone: appt.customer_phone || '',
      email: '',
      is_walk_in: !appt.customer_id,
    };

    const productsList: Product[] = [];
    (appt.services || []).forEach((s) => {
      const pid = s.product_id || s.id;
      const price = typeof s.price === 'number' ? s.price : parseFloat(String(s.price || 0));
      const sName = s.name || s.product_name || 'Service';
      const existing = products.find(
        (p) => (pid && p.id === pid) || p.name.trim().toLowerCase() === sName.trim().toLowerCase()
      );

      const prodToAdd: Product = existing
        ? { ...existing, price: price > 0 ? price : existing.price }
        : {
            id: pid || Math.floor(Math.random() * 900000) + 10000,
            business_id: appt.business_id,
            category_id: 1,
            name: sName,
            sku: `SRV-${pid || 1}`,
            product_type: 'normal',
            price: price,
            description: '',
            modifiers: [],
            combo_items: [],
            is_active: true,
          };

      const qty = s.quantity && s.quantity > 0 ? s.quantity : 1;
      for (let i = 0; i < qty; i++) {
        productsList.push(prodToAdd);
      }
    });

    onStartService(customerObj, productsList, appt);
  };

  /* ── 10. Month Calendar Generator ──────────────────────────────────────── */
  const calendarDays = useMemo(() => {
    const firstDay = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), 1);
    const startOffset = firstDay.getDay(); // 0 for Sunday
    const startDate = new Date(firstDay);
    startDate.setDate(startDate.getDate() - startOffset);

    const days: Date[] = [];
    for (let i = 0; i < 42; i++) {
      const d = new Date(startDate);
      d.setDate(startDate.getDate() + i);
      days.push(d);
    }
    if (days[35].getMonth() !== calendarMonth.getMonth()) {
      return days.slice(0, 35);
    }
    return days;
  }, [calendarMonth]);

  const prevMonth = () => {
    setCalendarMonth(
      new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() - 1, 1)
    );
  };

  const nextMonth = () => {
    setCalendarMonth(
      new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + 1, 1)
    );
  };

  /* ── 11. Live Current Time Indicator Rendering Math ────────────────────── */
  const renderCurrentTimeIndicator = () => {
    const isToday =
      selectedDate.getFullYear() === currentTime.getFullYear() &&
      selectedDate.getMonth() === currentTime.getMonth() &&
      selectedDate.getDate() === currentTime.getDate();

    const nowMinutes =
      currentTime.getHours() * 60 +
      currentTime.getMinutes() +
      currentTime.getSeconds() / 60;

    if (
      !isToday ||
      nowMinutes < gridBaseMinutes ||
      nowMinutes > gridEndHour * 60
    ) {
      return null;
    }

    const top = ((nowMinutes - gridBaseMinutes) / 30) * SLOT_HEIGHT;
    const hour12 =
      currentTime.getHours() === 0
        ? 12
        : currentTime.getHours() > 12
        ? currentTime.getHours() - 12
        : currentTime.getHours();
    const ampm = currentTime.getHours() >= 12 ? 'PM' : 'AM';
    const timeDigits =
      timeFormat === '24'
        ? `${String(currentTime.getHours()).padStart(2, '0')}:${String(
            currentTime.getMinutes()
          ).padStart(2, '0')}:${String(currentTime.getSeconds()).padStart(2, '0')}`
        : `${String(hour12).padStart(2, '0')}:${String(
            currentTime.getMinutes()
          ).padStart(2, '0')}:${String(currentTime.getSeconds()).padStart(2, '0')}`;

    const initialBadgeX = Math.max(
      6,
      (bodyScrollRef.current
        ? bodyScrollRef.current.scrollLeft +
          bodyScrollRef.current.clientWidth -
          84
        : 700) -
        (timeFormat === '12' ? 122 : 98) -
        14
    );

    return (
      <div
        className="current-time-indicator"
        style={{ top: `${top - 6}px` }}
      >
        <div className="current-time-line" />
        <div className="current-time-anchor" />
        <div
          ref={currentTimeBadgeRef}
          className="current-time-badge"
          style={{ left: `${initialBadgeX}px` }}
        >
          <Clock size={12} />
          <span>{timeDigits}</span>
          {timeFormat === '12' && (
            <span className="current-time-badge__ampm">{ampm}</span>
          )}
        </div>
      </div>
    );
  };

  /* ── Render ────────────────────────────────────────────────────────────── */
  if (isLoading) {
    return (
      <div className="appointment-loading">
        <div className="appointment-loading__spinner" />
        <span>Loading appointment schedule...</span>
      </div>
    );
  }

  return (
    <div className="appointment-view">
      {/* ── 1. Top Header ───────────────────────────────────────────────── */}
      <header className="appointment-header">
        <div className="appointment-header__left">
          <button
            type="button"
            className="appointment-header__btn appointment-header__btn--today"
            onClick={goToday}
          >
            Today
          </button>

          <div className="appointment-header__arrows">
            <button
              type="button"
              className="appointment-header__arrow-btn"
              onClick={goPrevDay}
              title="Previous Day"
            >
              <ChevronLeft size={16} />
            </button>
            <button
              type="button"
              className="appointment-header__arrow-btn"
              onClick={goNextDay}
              title="Next Day"
            >
              <ChevronRight size={16} />
            </button>
          </div>

          <label className="appointment-header__date-btn" title="Pick Date">
            <CalendarIcon size={14} className="appointment-header__date-icon" />
            <span>{formatDateLong(selectedDate)}</span>
            <input
              type="date"
              className="appointment-header__date-input-hidden"
              value={formatDateYMD(selectedDate)}
              onChange={(e) => {
                if (e.target.value) {
                  const [y, m, d] = e.target.value.split('-').map(Number);
                  const picked = new Date(y, m - 1, d);
                  setSelectedDate(picked);
                  setCalendarMonth(new Date(y, m - 1, 1));
                }
              }}
            />
          </label>

          <div className="appointment-header__divider" />

          <button
            type="button"
            className="appointment-header__btn appointment-header__btn--refresh"
            onClick={loadData}
          >
            <RefreshCw size={14} />
            <span>Refresh</span>
          </button>
        </div>

        {/* Customer Search Bar in Header */}
        <div className="appointment-search-wrapper">
          <div className="appointment-search-input-box">
            <Search size={15} className="appointment-search-icon" />
            <input
              type="text"
              className="appointment-search-input"
              placeholder="Search customer name or phone..."
              value={customerSearchQuery}
              onChange={(e) => setCustomerSearchQuery(e.target.value)}
              onFocus={() => setIsCustomerSearchFocused(true)}
              onBlur={() => setTimeout(() => setIsCustomerSearchFocused(false), 200)}
            />
            {customerSearchQuery && (
              <button
                type="button"
                className="appointment-search-clear"
                onClick={() => setCustomerSearchQuery('')}
              >
                <X size={14} />
              </button>
            )}
          </div>

          {/* Autocomplete Overlay */}
          {customerSearchQuery.trim() && isCustomerSearchFocused && (
            <div className="appointment-search-dropdown">
              <div className="appointment-search-dropdown__header">
                <User size={13} />
                <span>
                  {searchResults.length} appointment
                  {searchResults.length === 1 ? '' : 's'} found
                </span>
              </div>
              <div className="appointment-search-dropdown__list">
                {searchResults.length === 0 ? (
                  <div className="appointment-search-dropdown__empty">
                    <span>No matching appointments found</span>
                  </div>
                ) : (
                  searchResults.map((appt) => (
                    <div
                      key={appt.id}
                      className="appointment-search-item"
                      onClick={() => {
                        setCustomerSearchQuery('');
                        setModalDetailsAppt(appt);
                      }}
                    >
                      <div className="appointment-search-avatar">
                        {appt.customer_name ? appt.customer_name[0].toUpperCase() : '?'}
                      </div>
                      <div className="appointment-search-item__info">
                        <div className="appointment-search-item__name">
                          {appt.customer_name}
                        </div>
                        <div className="appointment-search-item__phone">
                          {appt.customer_phone || 'No phone'}
                        </div>
                      </div>
                      <div className="appointment-search-item__tag">
                        {appt.services && appt.services[0]
                          ? appt.services[0].name || appt.services[0].product_name || 'Service'
                          : 'General'}
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          )}
        </div>

        {/* New Appointment Primary Button */}
        <button
          type="button"
          className="appointment-header__btn appointment-header__btn--new"
          onClick={() => {
            setModalNewApptPreset(null);
            setModalNewApptOpen(true);
          }}
        >
          <Plus size={16} />
          <span>New Appointment</span>
        </button>
      </header>

      {/* ── 2. Staff Pills Filter Bar ───────────────────────────────────── */}
      <div className="appointment-staff-bar">
        <span className="appointment-staff-bar__label">Filter Staff:</span>
        <div className="appointment-staff-bar__pills">
          {/* All Staff Pill */}
          <div
            className={`staff-pill ${
              selectedStaffFilter === null
                ? 'staff-pill--all-active'
                : 'staff-pill--all-inactive'
            }`}
            onClick={() => setSelectedStaffFilter(null)}
          >
            {selectedStaffFilter === null && <Check size={13} />}
            <span>All Staff</span>
            <span
              className="staff-pill__badge"
              style={{
                backgroundColor:
                  selectedStaffFilter === null ? '#334155' : '#e2e8f0',
                color: selectedStaffFilter === null ? '#ffffff' : '#334155',
              }}
            >
              {appointments.length}
            </span>
          </div>

          {/* Individual Staff Pills */}
          {staffList.map((s, idx) => {
            const col = staffColor(idx);
            const count = countForStaff(s.id);
            const isSel = selectedStaffFilter === s.id;
            return (
              <div
                key={s.id}
                className="staff-pill"
                style={{
                  backgroundColor: isSel
                    ? `${col}26` // 15% opacity
                    : `${col}10`, // 6% opacity
                  borderColor: isSel ? col : `${col}40`,
                  color: isSel ? col : '#334155',
                }}
                onClick={() =>
                  setSelectedStaffFilter(isSel ? null : s.id)
                }
              >
                <div
                  className="staff-pill__dot"
                  style={{ backgroundColor: col }}
                />
                <span>{s.name}</span>
                <span
                  className="staff-pill__badge"
                  style={{
                    backgroundColor: `${col}20`,
                    color: col,
                  }}
                >
                  {count}
                </span>
              </div>
            );
          })}

          {/* Toggle Right Calendar Button */}
          <div
            className={`staff-pill staff-pill--toggle-cal ${
              isCalendarHidden ? 'staff-pill--toggle-cal-active' : ''
            }`}
            onClick={() => setIsCalendarHidden(!isCalendarHidden)}
          >
            {isCalendarHidden ? <Eye size={14} /> : <EyeOff size={14} />}
            <span>{isCalendarHidden ? 'Show Calendar' : 'Hide Calendar'}</span>
          </div>
        </div>
      </div>

      {/* ── 3. Main Split View: Left Timetable + Right Calendar ─────────── */}
      <div className="appointment-body">
        {/* Left: Timetable Area */}
        <div
          className="appointment-timetable"
          style={{ width: isCalendarHidden ? '100%' : '70%' }}
        >
          {/* Pinned Top Staff Headers Row */}
          <div className="timetable-header-row">
            {/* Pinned TIME corner box */}
            <div className="timetable-time-corner">
              <Clock size={13} />
              <span>TIME</span>
            </div>

            {/* Scrollable staff headers */}
            <div
              className="timetable-staff-headers-scroll"
              ref={headerScrollRef}
              onScroll={handleHeaderScroll}
            >
              {displayedStaff.map((s, idx) => {
                const col = staffColor(idx);
                const count = countForStaff(s.id);
                return (
                  <div
                    key={s.id}
                    className="timetable-staff-header-card"
                    style={{ width: `${staffColWidth}px` }}
                    onClick={() =>
                      setModalStaffInfo({ staff: s, color: col })
                    }
                    title="Click for staff details"
                  >
                    <div
                      className="timetable-staff-avatar-wrap"
                      style={{ backgroundColor: col }}
                    >
                      {s.name ? s.name[0].toUpperCase() : 'S'}
                      <div className="timetable-staff-avatar-dot" />
                    </div>
                    <div className="timetable-staff-header-info">
                      <span className="timetable-staff-name">{s.name}</span>
                      <span className="timetable-staff-slots-count">
                        {count} slot{count === 1 ? '' : 's'}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Scrollable Timetable Body */}
          <div
            className="timetable-body-scroll"
            ref={bodyScrollRef}
            onScroll={handleBodyScroll}
          >
            {/* Left Pinned Sticky Time Column */}
            <div
              className="timetable-time-column"
              style={{ height: `${gridTotalHeight}px` }}
            >
              {timeSlots.map((slot) => {
                const outside = isSlotOutsideBusiness(slot, openTime, closeTime);
                return (
                  <div
                    key={slot}
                    className={`timetable-time-slot ${
                      outside ? 'timetable-time-slot--outside' : ''
                    }`}
                  >
                    {formatSlotLabel(slot, timeFormat)}
                  </div>
                );
              })}
            </div>

            {/* Staff Lanes Stack */}
            <div
              className="timetable-lanes-stack"
              style={{
                height: `${gridTotalHeight}px`,
                minWidth: `${displayedStaff.length * staffColWidth}px`,
              }}
            >
                {/* Staff Lanes */}
                {displayedStaff.map((s) => {
                  const staffAppts = appointmentsForStaff(s.id);

                  // Sort appointments so cancelled/no_show render behind active ones
                  const sortedAppts = [...staffAppts].sort((a, b) => {
                    const aInact =
                      a.status === 'cancelled' || a.status === 'no_show' ? 0 : 1;
                    const bInact =
                      b.status === 'cancelled' || b.status === 'no_show' ? 0 : 1;
                    if (aInact !== bInact) return aInact - bInact;
                    return (
                      timeToMinutes(a.start_time) - timeToMinutes(b.start_time)
                    );
                  });

                  return (
                    <div
                      key={s.id}
                      className="timetable-staff-lane"
                      style={{
                        width: `${staffColWidth}px`,
                        height: `${gridTotalHeight}px`,
                      }}
                    >
                      {/* Slot cells */}
                      {timeSlots.map((slot) => {
                        const outside = isSlotOutsideBusiness(
                          slot,
                          openTime,
                          closeTime
                        );
                        const isHoverTarget =
                          dragOverTarget?.staffId === s.id &&
                          dragOverTarget?.slot === slot;
                        const draggedAppt = appointments.find(
                          (a) => a.id === draggingApptId
                        );
                        const isBlocked =
                          draggedAppt &&
                          isSlotBlockedForDrag(draggedAppt, s, slot);

                        return (
                          <div
                            key={slot}
                            className={`timetable-lane-slot ${
                              outside ? 'timetable-lane-slot--outside' : ''
                            } ${
                              isHoverTarget
                                ? isBlocked
                                  ? 'timetable-lane-slot--drop-blocked'
                                  : 'timetable-lane-slot--drop-target'
                                : ''
                            }`}
                            onClick={() => {
                              if (outside) {
                                toast.warning(
                                  `Time slot ${formatSlotLabel(
                                    slot,
                                    timeFormat
                                  )} is outside business hours (${formatSlotLabel(
                                    openTime,
                                    timeFormat
                                  )} - ${formatSlotLabel(closeTime, timeFormat)}).`
                                );
                                return;
                              }
                              // Open new appointment modal preselected
                              const endSlot = addMinutesTo24h(
                                slot,
                                configuredSlotDuration
                              );
                              setModalNewApptPreset({
                                staff: s,
                                startTime: slot,
                                endTime: endSlot,
                                date: selectedDate,
                              });
                              setModalNewApptOpen(true);
                            }}
                            onDragOver={(e) => {
                              e.preventDefault();
                              if (
                                dragOverTarget?.staffId !== s.id ||
                                dragOverTarget?.slot !== slot
                              ) {
                                setDragOverTarget({ staffId: s.id, slot });
                              }
                            }}
                            onDragLeave={() => {
                              if (
                                dragOverTarget?.staffId === s.id &&
                                dragOverTarget?.slot === slot
                              ) {
                                setDragOverTarget(null);
                              }
                            }}
                            onDrop={(e) => {
                              e.preventDefault();
                              const apptIdStr = e.dataTransfer.getData('text/plain');
                              const apptId = parseInt(apptIdStr, 10);
                              const targetAppt = appointments.find(
                                (a) => a.id === apptId
                              );
                              if (targetAppt) {
                                handleDragDropReschedule(targetAppt, s, slot);
                              }
                            }}
                          >
                            {outside && (
                              <Lock size={12} className="timetable-slot-lock" />
                            )}
                            {isHoverTarget && (
                              <div
                                className={`timetable-slot-drop-badge ${
                                  isBlocked
                                    ? 'timetable-slot-drop-badge--blocked'
                                    : 'timetable-slot-drop-badge--valid'
                                }`}
                              >
                                {isBlocked ? (
                                  <>
                                    <AlertCircle size={11} />
                                    <span>Not Allowed</span>
                                  </>
                                ) : (
                                  <>
                                    <Clock size={11} />
                                    <span>
                                      Drop at {formatSlotLabel(slot, timeFormat)}
                                    </span>
                                  </>
                                )}
                              </div>
                            )}
                          </div>
                        );
                      })}

                      {/* Appointment Cards */}
                      {sortedAppts.map((appt) => {
                        const startM = timeToMinutes(appt.start_time);
                        const endM = timeToMinutes(appt.end_time);
                        const top =
                          ((startM - gridBaseMinutes) / 30) * SLOT_HEIGHT;
                        const durationM = endM - startM;
                        const height = Math.max(
                          32,
                          (durationM / 30) * SLOT_HEIGHT - 4
                        );

                        const canDrag =
                          appt.status === 'booked' ||
                          appt.status === 'in_service';
                        const serviceSummary =
                          appt.services && appt.services.length > 0
                            ? appt.services
                                .map(
                                  (sv) =>
                                    sv.name || sv.product_name || 'Service'
                                )
                                .join(', ')
                            : 'General Consultation / Service';

                        return (
                          <div
                            key={appt.id}
                            className={`appointment-card appointment-card--${
                              appt.status
                            } ${
                              draggingApptId === appt.id
                                ? 'appointment-card--dragging'
                                : ''
                            }`}
                            style={{
                              top: `${top + 2}px`,
                              height: `${height}px`,
                            }}
                            draggable={canDrag}
                            onDragStart={(e) => {
                              if (!canDrag) return;
                              setDraggingApptId(appt.id);
                              e.dataTransfer.setData(
                                'text/plain',
                                String(appt.id)
                              );
                              e.dataTransfer.effectAllowed = 'move';
                            }}
                            onDragEnd={() => {
                              setDraggingApptId(null);
                              setDragOverTarget(null);
                            }}
                            onClick={() => setModalDetailsAppt(appt)}
                          >
                            <div className="appointment-card__top">
                              <div className="appointment-card__time">
                                <Clock size={11} />
                                <span>
                                  {formatApptTimeRange(
                                    appt.start_time,
                                    appt.end_time,
                                    timeFormat
                                  )}
                                </span>
                              </div>
                              <div
                                className="appointment-card__badge"
                                onClick={(e) => {
                                  if (appt.status === 'in_service') {
                                    e.stopPropagation();
                                    continueServiceInCart(appt);
                                  }
                                }}
                                title={
                                  appt.status === 'in_service'
                                    ? 'Click to Continue in POS Cart'
                                    : undefined
                                }
                              >
                                {appt.status === 'in_service' && (
                                  <Play size={9} />
                                )}
                                <span>
                                  {appt.status === 'in_service'
                                    ? 'IN SERVICE'
                                    : appt.status.toUpperCase().replace('_', ' ')}
                                </span>
                              </div>
                            </div>

                            {height > 46 && (
                              <div className="appointment-card__title">
                                {appt.customer_name || 'Customer'}
                              </div>
                            )}

                            {height > 66 && (
                              <div className="appointment-card__notes">
                                {serviceSummary}
                              </div>
                            )}

                            {height > 88 && (
                              <div className="appointment-card__bottom">
                                <span>{appt.customer_phone || ''}</span>
                                {appt.total_amount &&
                                  parseFloat(String(appt.total_amount)) > 0 && (
                                    <span>${fmtMoney(appt.total_amount)}</span>
                                  )}
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  );
                })}

                {/* Live Current Time Red Line Indicator */}
                {renderCurrentTimeIndicator()}
              </div>
          </div>
        </div>

        {/* Right: Collapsible Calendar & Booking Overview */}
        {!isCalendarHidden && (
          <aside className="appointment-right-panel">
            {/* Month Calendar Widget */}
            <div className="month-calendar">
              <div className="month-calendar__header">
                <span className="month-calendar__title">
                  {MONTHS_FULL[calendarMonth.getMonth()]}{' '}
                  {calendarMonth.getFullYear()}
                </span>
                <div className="month-calendar__controls">
                  <button
                    type="button"
                    className="month-calendar__icon-btn"
                    onClick={prevMonth}
                    title="Previous Month"
                  >
                    <ChevronLeft size={18} />
                  </button>
                  <button
                    type="button"
                    className="month-calendar__icon-btn"
                    onClick={nextMonth}
                    title="Next Month"
                  >
                    <ChevronRight size={18} />
                  </button>
                  <button
                    type="button"
                    className="month-calendar__icon-btn"
                    onClick={() => setIsCalendarHidden(true)}
                    title="Hide Calendar"
                  >
                    <X size={16} />
                  </button>
                </div>
              </div>

              {/* Weekday headers: S M T W T F S */}
              <div className="month-calendar__weekdays">
                {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((w, idx) => (
                  <span key={idx} className="month-calendar__weekday">
                    {w}
                  </span>
                ))}
              </div>

              {/* Days Grid */}
              <div className="month-calendar__grid">
                {calendarDays.map((day, idx) => {
                  const isCurrentMonth =
                    day.getMonth() === calendarMonth.getMonth();
                  const isSelected =
                    day.getFullYear() === selectedDate.getFullYear() &&
                    day.getMonth() === selectedDate.getMonth() &&
                    day.getDate() === selectedDate.getDate();
                  const isToday =
                    day.getFullYear() === new Date().getFullYear() &&
                    day.getMonth() === new Date().getMonth() &&
                    day.getDate() === new Date().getDate();

                  return (
                    <div
                      key={idx}
                      className={`month-calendar__day ${
                        !isCurrentMonth ? 'month-calendar__day--other-month' : ''
                      } ${isToday ? 'month-calendar__day--today' : ''} ${
                        isSelected ? 'month-calendar__day--selected' : ''
                      }`}
                      onClick={() => {
                        setSelectedDate(day);
                        setCalendarMonth(
                          new Date(day.getFullYear(), day.getMonth(), 1)
                        );
                      }}
                    >
                      {day.getDate()}
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="panel-divider" />

            {/* OVERVIEW Header */}
            <div className="overview-header">
              <span className="overview-title">OVERVIEW</span>
              <span className="overview-total-badge">
                {overviewStats.total || appointments.length} total
              </span>
            </div>

            {/* Status Cards (Interactive filter toggle) */}
            <div className="status-cards-list">
              {[
                {
                  key: 'booked' as AppointmentStatus,
                  label: 'Booked',
                  count: overviewStats.booked || 0,
                  dotColor: '#2563EB',
                  bgColor: '#F8FAFC',
                  borderColor: '#E2E8F0',
                },
                {
                  key: 'in_service' as AppointmentStatus,
                  label: 'In service',
                  count: overviewStats.in_service || 0,
                  dotColor: '#F59E0B',
                  bgColor: '#FFFBEB',
                  borderColor: '#FEF3C7',
                },
                {
                  key: 'completed' as AppointmentStatus,
                  label: 'Completed',
                  count: overviewStats.completed || 0,
                  dotColor: '#10B981',
                  bgColor: '#F0FDF4',
                  borderColor: '#DCFCE7',
                },
                {
                  key: 'no_show' as AppointmentStatus,
                  label: 'No-show',
                  count: overviewStats.no_show || 0,
                  dotColor: '#F43F5E',
                  bgColor: '#FFF1F2',
                  borderColor: '#FFE4E6',
                },
                {
                  key: 'cancelled' as AppointmentStatus,
                  label: 'Cancelled',
                  count: overviewStats.cancelled || 0,
                  dotColor: '#64748B',
                  bgColor: '#F8FAFC',
                  borderColor: '#E2E8F0',
                },
              ].map((card) => {
                const isActive = selectedStatusFilter === card.key;
                return (
                  <div
                    key={card.key}
                    className={`status-card ${
                      isActive ? 'status-card--active' : ''
                    }`}
                    style={{
                      backgroundColor: card.bgColor,
                      borderColor: isActive ? card.dotColor : card.borderColor,
                    }}
                    onClick={() =>
                      setSelectedStatusFilter(isActive ? null : card.key)
                    }
                  >
                    <div className="status-card__left">
                      <div
                        className="status-card__dot"
                        style={{ backgroundColor: card.dotColor }}
                      />
                      <span className="status-card__label">{card.label}</span>
                    </div>
                    <div
                      className="status-card__count"
                      style={{
                        borderColor: isActive
                          ? card.dotColor
                          : card.borderColor,
                      }}
                    >
                      {card.count}
                    </div>
                  </div>
                );
              })}
            </div>
          </aside>
        )}
      </div>

      {/* ── 4. MODALS ───────────────────────────────────────────────────── */}

      {/* Modal 1: Book New Appointment */}
      {modalNewApptOpen && (
        <NewAppointmentModal
          preset={modalNewApptPreset}
          staffList={staffList}
          categories={categories}
          products={products}
          timeFormat={timeFormat}
          openTime={openTime}
          closeTime={closeTime}
          slotDuration={configuredSlotDuration}
          onClose={() => {
            setModalNewApptOpen(false);
            setModalNewApptPreset(null);
          }}
          onSuccess={() => {
            setModalNewApptOpen(false);
            setModalNewApptPreset(null);
            loadData();
          }}
        />
      )}

      {/* Modal 2: Appointment Details & Actions */}
      {modalDetailsAppt && (
        <AppointmentDetailsModal
          appt={modalDetailsAppt}
          timeFormat={timeFormat}
          allowDeleteService={allowDeleteService}
          onClose={() => setModalDetailsAppt(null)}
          onStartService={() => {
            setModalDetailsAppt(null);
            continueServiceInCart(modalDetailsAppt);
          }}
          onOpenReschedule={() => {
            const current = modalDetailsAppt;
            setModalDetailsAppt(null);
            setModalRescheduleAppt(current);
          }}
          onStatusChange={async (newStatus) => {
            try {
              await appointmentApi.updateStatus(modalDetailsAppt.id, newStatus);
              toast.success(`Appointment status updated to ${newStatus}`);
              setModalDetailsAppt(null);
              loadData();
            } catch {
              toast.error('Failed to update status');
            }
          }}
          onDeleteClick={() => {
            const current = modalDetailsAppt;
            setModalDetailsAppt(null);
            setDeleteConfirmAppt(current);
          }}
          onReload={loadData}
        />
      )}

      {/* Modal 3: Exact Reschedule Modal */}
      {modalRescheduleAppt && (
        <ExactRescheduleModal
          appt={modalRescheduleAppt}
          staffList={staffList}
          timeFormat={timeFormat}
          onClose={() => setModalRescheduleAppt(null)}
          onSuccess={() => {
            setModalRescheduleAppt(null);
            loadData();
          }}
        />
      )}

      {/* Modal 4: Staff Info Modal */}
      {modalStaffInfo && (
        <StaffInfoModal
          staff={modalStaffInfo.staff}
          color={modalStaffInfo.color}
          appointments={appointments}
          onClose={() => setModalStaffInfo(null)}
          onViewSchedule={() => {
            setSelectedStaffFilter(modalStaffInfo.staff.id);
            setModalStaffInfo(null);
          }}
        />
      )}

      {/* Modal 5: Delete Confirmation Modal */}
      {deleteConfirmAppt && (
        <div
          className="appt-modal-overlay"
          onClick={() => setDeleteConfirmAppt(null)}
        >
          <div
            className="appt-modal appt-modal--details"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="appt-modal__header">
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  color: '#e11d48',
                }}
              >
                <Trash2 size={20} />
                <span className="appt-modal__title">Delete Appointment</span>
              </div>
              <button
                type="button"
                className="appt-modal__close-btn"
                onClick={() => setDeleteConfirmAppt(null)}
              >
                <X size={18} />
              </button>
            </div>
            <div className="appt-modal__body">
              <p style={{ fontSize: '13.5px', color: '#334155', lineHeight: 1.5 }}>
                Are you sure you want to delete the appointment for{' '}
                <strong>"{deleteConfirmAppt.customer_name}"</strong>? This
                action cannot be undone.
              </p>
            </div>
            <div className="appt-modal__footer">
              <button
                type="button"
                className="appt-btn-cancel"
                onClick={() => setDeleteConfirmAppt(null)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="appt-btn-primary"
                style={{ backgroundColor: '#e11d48' }}
                onClick={async () => {
                  try {
                    await appointmentApi.delete(deleteConfirmAppt.id);
                    toast.success('Appointment deleted successfully');
                    setDeleteConfirmAppt(null);
                    loadData();
                  } catch {
                    toast.error('Failed to delete appointment');
                  }
                }}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/* ==========================================================================
   SUB-MODAL: NewAppointmentModal
   ========================================================================== */
interface NewAppointmentModalProps {
  preset?: {
    staff?: Staff;
    startTime?: string;
    endTime?: string;
    date?: Date;
  } | null;
  staffList: Staff[];
  categories: Category[];
  products: Product[];
  timeFormat: '12' | '24';
  openTime: string;
  closeTime: string;
  slotDuration: number;
  onClose: () => void;
  onSuccess: () => void;
}

function NewAppointmentModal({
  preset,
  staffList,
  categories,
  products,
  timeFormat,
  openTime,
  closeTime,
  slotDuration,
  onClose,
  onSuccess,
}: NewAppointmentModalProps) {
  // Staff Selection
  const defaultStaff =
    preset?.staff ||
    staffList.find((s) => s.is_active === true || s.is_active === 1) ||
    staffList[0];
  const [selectedStaffId, setSelectedStaffId] = useState<number>(
    defaultStaff ? defaultStaff.id : 0
  );

  // Customer or Walk-in
  const [isWalkIn, setIsWalkIn] = useState<boolean>(false);
  const [walkInName, setWalkInName] = useState<string>('');
  const [walkInPhone, setWalkInPhone] = useState<string>('');

  const [customerSearch, setCustomerSearch] = useState<string>('');
  const [customerResults, setCustomerResults] = useState<Customer[]>([]);
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null);
  const [isSearchingCustomers, setIsSearchingCustomers] =
    useState<boolean>(false);

  // Date
  const [apptDate, setApptDate] = useState<string>(
    formatDateYMD(preset?.date || new Date())
  );

  // Time Inputs (with 12h AM/PM support)
  const initialStart24 = preset?.startTime || '09:00';
  const initialEnd24 =
    preset?.endTime || addMinutesTo24h(initialStart24, slotDuration);

  const startSplit = split24To12(initialStart24);
  const endSplit = split24To12(initialEnd24);

  const [startTimeInput, setStartTimeInput] = useState<string>(
    timeFormat === '12' ? startSplit.time : initialStart24
  );
  const [startPeriod, setStartPeriod] = useState<'AM' | 'PM'>(startSplit.period);

  const [endTimeInput, setEndTimeInput] = useState<string>(
    timeFormat === '12' ? endSplit.time : initialEnd24
  );
  const [endPeriod, setEndPeriod] = useState<'AM' | 'PM'>(endSplit.period);

  const calculatedDuration = useMemo(() => {
    try {
      const s24 =
        timeFormat === '12'
          ? convert12To24(startTimeInput.trim(), startPeriod)
          : startTimeInput.trim();
      const e24 =
        timeFormat === '12'
          ? convert12To24(endTimeInput.trim(), endPeriod)
          : endTimeInput.trim();
      const sM = timeToMinutes(s24);
      const eM = timeToMinutes(e24);
      if (eM > sM) {
        const diff = eM - sM;
        if (diff >= 60) {
          const hrs = Math.floor(diff / 60);
          const mins = diff % 60;
          return mins > 0 ? `${hrs}h ${mins}m` : `${hrs} hr${hrs > 1 ? 's' : ''}`;
        }
        return `${diff} mins`;
      }
    } catch (_) {}
    return null;
  }, [startTimeInput, startPeriod, endTimeInput, endPeriod, timeFormat]);

  // Services & Categories Selection
  const [selectedCategoryId, setSelectedCategoryId] = useState<number | null>(
    null
  );
  const [selectedProducts, setSelectedProducts] = useState<Product[]>([]);
  const [notes, setNotes] = useState<string>('');

  // Conflict / Validation Error Alert
  const [errorBanner, setErrorBanner] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);

  // Allowed categories: show_in_appointment !== false
  const allowedCategories = useMemo(
    () => categories.filter((c) => c.show_in_appointment !== false),
    [categories]
  );
  const allowedCatIds = useMemo(
    () => new Set(allowedCategories.map((c) => c.id)),
    [allowedCategories]
  );

  const filteredProducts = useMemo(() => {
    return products.filter((p) => {
      if (p.is_active === false || (p as any).is_active === 0) return false;
      if (!p.category_id || !allowedCatIds.has(p.category_id)) return false;
      if (selectedCategoryId !== null && p.category_id !== selectedCategoryId)
        return false;
      return true;
    });
  }, [products, allowedCatIds, selectedCategoryId]);

  const totalPrice = useMemo(() => {
    return selectedProducts.reduce((sum, p) => sum + (p.price || 0), 0);
  }, [selectedProducts]);

  // Debounced Customer Search
  useEffect(() => {
    if (!customerSearch.trim() || selectedCustomer) {
      setCustomerResults([]);
      return;
    }
    const timer = setTimeout(async () => {
      setIsSearchingCustomers(true);
      try {
        const res = await customerApi.getAll(customerSearch.trim());
        setCustomerResults(res.data.data || []);
      } catch {
        setCustomerResults([]);
      } finally {
        setIsSearchingCustomers(false);
      }
    }, 250);
    return () => clearTimeout(timer);
  }, [customerSearch, selectedCustomer]);

  const handleConfirmBooking = async () => {
    setErrorBanner(null);

    if (!selectedStaffId) {
      setErrorBanner('Please select a staff member.');
      return;
    }

    if (!isWalkIn && !selectedCustomer) {
      setErrorBanner('Please search and select a customer, or switch to Walk-in.');
      return;
    }

    if (isWalkIn && !walkInName.trim()) {
      setErrorBanner('Please enter a name for the walk-in customer.');
      return;
    }

    // Validate time
    const start24 =
      timeFormat === '12'
        ? convert12To24(startTimeInput.trim(), startPeriod)
        : startTimeInput.trim();
    const end24 =
      timeFormat === '12'
        ? convert12To24(endTimeInput.trim(), endPeriod)
        : endTimeInput.trim();

    const startM = timeToMinutes(start24);
    const endM = timeToMinutes(end24);
    const openM = timeToMinutes(openTime);
    const closeM = timeToMinutes(closeTime);

    if (endM <= startM) {
      setErrorBanner('End time must be later than start time.');
      return;
    }

    if (endM - startM < 15) {
      setErrorBanner('Appointment duration must be at least 15 minutes.');
      return;
    }

    if (startM < openM) {
      setErrorBanner(
        `Start time (${formatSlotLabel(
          start24,
          timeFormat
        )}) is before business opening time (${formatSlotLabel(
          openTime,
          timeFormat
        )}).`
      );
      return;
    }

    if (endM > closeM) {
      setErrorBanner(
        `End time (${formatSlotLabel(
          end24,
          timeFormat
        )}) exceeds business closing time (${formatSlotLabel(
          closeTime,
          timeFormat
        )}).`
      );
      return;
    }

    setIsSubmitting(true);
    try {
      // 1. Conflict Check
      const conflictRes = await appointmentApi.checkConflict({
        staff_id: selectedStaffId,
        appointment_date: apptDate,
        start_time: start24,
        end_time: end24,
      });

      if (conflictRes.data.has_conflict) {
        const conf = conflictRes.data.conflicting_appointment;
        const range = conf ? ` (${conf.start_time} - ${conf.end_time})` : '';
        const targetStaff = staffList.find((s) => s.id === selectedStaffId);
        setErrorBanner(
          `Collision: ${targetStaff?.name || 'Staff'} is already booked${range}.`
        );
        setIsSubmitting(false);
        return;
      }

      // 2. Submit Create Appointment
      const targetStaff = staffList.find((s) => s.id === selectedStaffId);
      const custName = isWalkIn ? walkInName.trim() : selectedCustomer?.name || '';
      const custPhone = isWalkIn
        ? walkInPhone.trim()
        : selectedCustomer?.phone || '';

      await appointmentApi.create({
        staff_id: selectedStaffId,
        staff_name: targetStaff?.name || '',
        customer_id: isWalkIn ? null : selectedCustomer?.id,
        customer_name: custName,
        customer_phone: custPhone,
        appointment_date: apptDate,
        start_time: start24,
        end_time: end24,
        total_amount: totalPrice,
        notes: notes.trim(),
        services: selectedProducts.map((p) => ({
          product_id: p.id,
          name: p.name,
          price: p.price,
          quantity: 1,
        })),
      });

      toast.success(
        `Booked appointment for ${custName} with ${
          targetStaff?.name || 'Staff'
        } at ${formatSlotLabel(start24, timeFormat)} - ${formatSlotLabel(
          end24,
          timeFormat
        )}`
      );
      onSuccess();
    } catch (err: any) {
      console.error('Failed to create appointment:', err);
      setErrorBanner(
        err?.response?.data?.message || 'Failed to create appointment'
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="appt-modal-overlay" onClick={onClose}>
      <div
        className="appt-modal appt-modal--new"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="appt-modal__header">
          <span className="appt-modal__title">Book New Appointment</span>
          <button
            type="button"
            className="appt-modal__close-btn"
            onClick={onClose}
          >
            <X size={20} />
          </button>
        </div>

        <div className="appt-modal__body">
          <div className="appt-form-columns">
            {/* LEFT COLUMN: Staff, Customer, Date, Time */}
            <div className="appt-form-col-left">
              {/* Staff Member */}
              <div className="appt-form-group">
                <label className="appt-form-label">Staff Member</label>
                <select
                  className="appt-form-select"
                  value={selectedStaffId}
                  onChange={(e) => {
                    setSelectedStaffId(Number(e.target.value));
                    setErrorBanner(null);
                  }}
                >
                  {staffList.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name} ({s.role || 'Staff'})
                    </option>
                  ))}
                </select>
              </div>

              {/* Customer Selector with Walk-in Toggle */}
              <div className="appt-form-group">
                <div className="appt-form-label">
                  <span>Customer</span>
                  <label
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      cursor: 'pointer',
                    }}
                  >
                    <span style={{ fontSize: '11px', color: '#64748b' }}>
                      Walk-in
                    </span>
                    <input
                      type="checkbox"
                      checked={isWalkIn}
                      onChange={(e) => {
                        setIsWalkIn(e.target.checked);
                        setErrorBanner(null);
                      }}
                      style={{ accentColor: '#e11d48' }}
                    />
                  </label>
                </div>

                {isWalkIn ? (
                  <div
                    style={{
                      display: 'flex',
                      flexDirection: 'column',
                      gap: '8px',
                    }}
                  >
                    <input
                      type="text"
                      className="appt-form-input"
                      placeholder="Walk-in Customer Name"
                      value={walkInName}
                      onChange={(e) => setWalkInName(e.target.value)}
                    />
                    <input
                      type="text"
                      className="appt-form-input"
                      placeholder="Phone Number (Optional)"
                      value={walkInPhone}
                      onChange={(e) => setWalkInPhone(e.target.value)}
                    />
                  </div>
                ) : (
                  <div style={{ position: 'relative' }}>
                    <div style={{ position: 'relative' }}>
                      <input
                        type="text"
                        className="appt-form-input"
                        placeholder="Search customer by name or phone..."
                        value={
                          selectedCustomer
                            ? selectedCustomer.name
                            : customerSearch
                        }
                        onChange={(e) => {
                          setSelectedCustomer(null);
                          setCustomerSearch(e.target.value);
                          setErrorBanner(null);
                        }}
                      />
                      {customerSearch && !selectedCustomer && (
                        <button
                          type="button"
                          className="appointment-search-clear"
                          style={{
                            position: 'absolute',
                            right: '8px',
                            top: '10px',
                          }}
                          onClick={() => setCustomerSearch('')}
                        >
                          <X size={14} />
                        </button>
                      )}
                    </div>

                    {/* Customer Dropdown Results */}
                    {!selectedCustomer && customerSearch.trim() && (
                      <div
                        className="appointment-search-dropdown"
                        style={{ width: '100%' }}
                      >
                        {isSearchingCustomers ? (
                          <div className="appointment-search-dropdown__empty">
                            Searching customers...
                          </div>
                        ) : customerResults.length === 0 ? (
                          <div className="appointment-search-dropdown__empty">
                            No customers found matching "{customerSearch}"
                          </div>
                        ) : (
                          customerResults.map((c) => (
                            <div
                              key={c.id}
                              className="appointment-search-item"
                              onClick={() => {
                                setSelectedCustomer(c);
                                setCustomerSearch('');
                              }}
                            >
                              <div className="appointment-search-avatar">
                                {c.name ? c.name[0].toUpperCase() : 'C'}
                              </div>
                              <div className="appointment-search-item__info">
                                <div className="appointment-search-item__name">
                                  {c.name}
                                </div>
                                <div className="appointment-search-item__phone">
                                  {c.phone || 'No phone'}
                                </div>
                              </div>
                            </div>
                          ))
                        )}
                      </div>
                    )}

                    {selectedCustomer && (
                      <div className="appt-cust-selected-badge">
                        <span>
                          Selected: {selectedCustomer.name}{' '}
                          {selectedCustomer.phone &&
                            `(${selectedCustomer.phone})`}
                        </span>
                        <button
                          type="button"
                          className="appt-cust-clear-btn"
                          onClick={() => setSelectedCustomer(null)}
                        >
                          <X size={14} />
                        </button>
                      </div>
                    )}
                  </div>
                )}
              </div>

              {/* Appointment Date */}
              <div className="appt-form-group">
                <label className="appt-form-label">Appointment Date</label>
                <input
                  type="date"
                  className="appt-form-input"
                  value={apptDate}
                  onChange={(e) => setApptDate(e.target.value)}
                />
              </div>

              {/* Start & End Time (2 Clean Symmetrical Columns) */}
              <div className="appt-form-group">
                <div className="appt-time-grid">
                  {/* START TIME COLUMN */}
                  <div className="appt-time-col">
                    <label className="appt-form-label">
                      <span>Start Time</span>
                    </label>
                    <div className="appt-time-field">
                      <Clock size={16} className="appt-time-clock-icon" />
                      <input
                        type="text"
                        className="appt-time-input"
                        value={startTimeInput}
                        onChange={(e) => {
                          setStartTimeInput(e.target.value);
                          setErrorBanner(null);
                        }}
                        placeholder="09:00"
                        maxLength={5}
                      />
                      {timeFormat === '12' && (
                        <div className="appt-ampm-switch">
                          <button
                            type="button"
                            className={`appt-ampm-btn ${
                              startPeriod === 'AM' ? 'appt-ampm-btn--active' : ''
                            }`}
                            onClick={() => {
                              setStartPeriod('AM');
                              setErrorBanner(null);
                            }}
                          >
                            AM
                          </button>
                          <button
                            type="button"
                            className={`appt-ampm-btn ${
                              startPeriod === 'PM' ? 'appt-ampm-btn--active' : ''
                            }`}
                            onClick={() => {
                              setStartPeriod('PM');
                              setErrorBanner(null);
                            }}
                          >
                            PM
                          </button>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* END TIME COLUMN */}
                  <div className="appt-time-col">
                    <label className="appt-form-label">
                      <span>End Time</span>
                    </label>
                    <div className="appt-time-field">
                      <Clock size={16} className="appt-time-clock-icon" />
                      <input
                        type="text"
                        className="appt-time-input"
                        value={endTimeInput}
                        onChange={(e) => {
                          setEndTimeInput(e.target.value);
                          setErrorBanner(null);
                        }}
                        placeholder="09:30"
                        maxLength={5}
                      />
                      {timeFormat === '12' && (
                        <div className="appt-ampm-switch">
                          <button
                            type="button"
                            className={`appt-ampm-btn ${
                              endPeriod === 'AM' ? 'appt-ampm-btn--active' : ''
                            }`}
                            onClick={() => {
                              setEndPeriod('AM');
                              setErrorBanner(null);
                            }}
                          >
                            AM
                          </button>
                          <button
                            type="button"
                            className={`appt-ampm-btn ${
                              endPeriod === 'PM' ? 'appt-ampm-btn--active' : ''
                            }`}
                            onClick={() => {
                              setEndPeriod('PM');
                              setErrorBanner(null);
                            }}
                          >
                            PM
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                </div>

                <div className="appt-biz-hours-meta">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                    <Store size={12} />
                    <span>
                      Business hours: {formatSlotLabel(openTime, timeFormat)} -{' '}
                      {formatSlotLabel(closeTime, timeFormat)}
                    </span>
                  </div>
                  {calculatedDuration && (
                    <span className="appt-duration-badge">
                      Duration: {calculatedDuration}
                    </span>
                  )}
                </div>
              </div>

              {/* Notes */}
              <div className="appt-form-group">
                <label className="appt-form-label">Notes (Optional)</label>
                <input
                  type="text"
                  className="appt-form-input"
                  placeholder="Special requests, instructions..."
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                />
              </div>
            </div>

            {/* RIGHT COLUMN: Categories & Products */}
            <div className="appt-form-col-right">
              <label className="appt-form-label">Category</label>
              <div className="appt-categories-chips">
                <div
                  className={`appt-cat-chip ${
                    selectedCategoryId === null ? 'appt-cat-chip--active' : ''
                  }`}
                  onClick={() => setSelectedCategoryId(null)}
                >
                  All
                </div>
                {allowedCategories.map((c) => (
                  <div
                    key={c.id}
                    className={`appt-cat-chip ${
                      selectedCategoryId === c.id ? 'appt-cat-chip--active' : ''
                    }`}
                    onClick={() => setSelectedCategoryId(c.id)}
                  >
                    {c.name}
                  </div>
                ))}
              </div>

              <label className="appt-form-label">Products & Services</label>
              <div className="appt-products-list">
                {filteredProducts.length === 0 ? (
                  <div
                    style={{
                      padding: '20px',
                      textAlign: 'center',
                      color: '#94a3b8',
                      fontSize: '12px',
                    }}
                  >
                    No products or services available in this category
                  </div>
                ) : (
                  filteredProducts.map((p) => {
                    const isSelected = selectedProducts.some(
                      (sp) => sp.id === p.id
                    );
                    return (
                      <div
                        key={p.id}
                        className={`appt-product-row ${
                          isSelected ? 'appt-product-row--selected' : ''
                        }`}
                        onClick={() => {
                          if (isSelected) {
                            setSelectedProducts(
                              selectedProducts.filter((sp) => sp.id !== p.id)
                            );
                          } else {
                            setSelectedProducts([...selectedProducts, p]);
                          }
                        }}
                      >
                        <div
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                          }}
                        >
                          <input
                            type="checkbox"
                            checked={isSelected}
                            readOnly
                            className="appt-product-checkbox"
                          />
                          <span className="appt-product-name">{p.name}</span>
                        </div>
                        <span className="appt-product-price">
                          ${fmtMoney(p.price)}
                        </span>
                      </div>
                    );
                  })
                )}
              </div>

              <div className="appt-total-row">
                <span>Total:</span>
                <span className="appt-total-val">${fmtMoney(totalPrice)}</span>
              </div>
            </div>
          </div>

          {/* Validation or Collision Error Banner */}
          {errorBanner && (
            <div className="appt-alert-banner">
              <AlertCircle size={16} />
              <span>{errorBanner}</span>
            </div>
          )}
        </div>

        <div className="appt-modal__footer">
          <button
            type="button"
            className="appt-btn-cancel"
            onClick={onClose}
            disabled={isSubmitting}
          >
            Cancel
          </button>
          <button
            type="button"
            className="appt-btn-primary"
            onClick={handleConfirmBooking}
            disabled={isSubmitting}
          >
            {isSubmitting ? 'Confirming...' : 'Confirm Booking'}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ==========================================================================
   SUB-MODAL: AppointmentDetailsModal
   ========================================================================== */
interface AppointmentDetailsModalProps {
  appt: Appointment;
  timeFormat: '12' | '24';
  allowDeleteService: boolean;
  onClose: () => void;
  onStartService: () => void;
  onOpenReschedule: () => void;
  onStatusChange: (status: AppointmentStatus) => void;
  onDeleteClick: () => void;
  onReload: () => void;
}

function AppointmentDetailsModal({
  appt,
  timeFormat,
  allowDeleteService,
  onClose,
  onStartService,
  onOpenReschedule,
  onStatusChange,
  onDeleteClick,
  onReload,
}: AppointmentDetailsModalProps) {
  const [isExtending, setIsExtending] = useState<boolean>(false);

  const handleExtendDuration = async (addMinutes: number) => {
    setIsExtending(true);
    const curEndM = timeToMinutes(appt.end_time);
    const newEndM = curEndM + addMinutes;
    if (newEndM > 24 * 60) {
      toast.error('Cannot extend past midnight.');
      setIsExtending(false);
      return;
    }
    const newEndTime = minutesToTime24(newEndM);

    try {
      // Conflict check
      const conflictRes = await appointmentApi.checkConflict({
        staff_id: appt.staff_id,
        appointment_date: appt.appointment_date,
        startTime: appt.end_time,
        endTime: newEndTime,
        exclude_id: appt.id,
      } as any);

      if (conflictRes.data.has_conflict) {
        toast.error(
          `Cannot extend: Staff already has an active appointment in this window.`
        );
        setIsExtending(false);
        return;
      }

      await appointmentApi.update(appt.id, { end_time: newEndTime });
      toast.success(
        `Appointment extended to ${formatSlotLabel(
          newEndTime,
          timeFormat
        )} (+${addMinutes}m)`
      );
      onClose();
      onReload();
    } catch {
      toast.error('Failed to extend appointment duration');
    } finally {
      setIsExtending(false);
    }
  };

  const currentDurationM =
    timeToMinutes(appt.end_time) - timeToMinutes(appt.start_time);

  return (
    <div className="appt-modal-overlay" onClick={onClose}>
      <div
        className="appt-modal appt-modal--details"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="appt-modal__header">
          <span className="appt-modal__title">Appointment Details</span>
          <button
            type="button"
            className="appt-modal__close-btn"
            onClick={onClose}
          >
            <X size={20} />
          </button>
        </div>

        <div className="appt-modal__body">
          <div className="appt-detail-row">
            <User size={15} className="appt-detail-icon" />
            <span className="appt-detail-label">Customer</span>
            <span className="appt-detail-val">
              {appt.customer_name || 'Walk-in'}
            </span>
          </div>

          <div className="appt-detail-row">
            <Phone size={15} className="appt-detail-icon" />
            <span className="appt-detail-label">Phone</span>
            <span className="appt-detail-val">
              {appt.customer_phone || 'None'}
            </span>
          </div>

          <div className="appt-detail-row">
            <UserCheck size={15} className="appt-detail-icon" />
            <span className="appt-detail-label">Staff</span>
            <span className="appt-detail-val">{appt.staff_name}</span>
          </div>

          <div className="appt-detail-row">
            <CalendarIcon size={15} className="appt-detail-icon" />
            <span className="appt-detail-label">Date</span>
            <span className="appt-detail-val">{appt.appointment_date}</span>
          </div>

          <div className="appt-detail-row">
            <Clock size={15} className="appt-detail-icon" />
            <span className="appt-detail-label">Time</span>
            <span className="appt-detail-val">
              {formatApptTimeRange(appt.start_time, appt.end_time, timeFormat)}
            </span>
          </div>

          <div className="appt-detail-row">
            <AlertCircle size={15} className="appt-detail-icon" />
            <span className="appt-detail-label">Status</span>
            <span className="appt-detail-val">
              <span
                className="appointment-card__badge"
                style={{
                  display: 'inline-block',
                  backgroundColor:
                    appt.status === 'booked'
                      ? '#3b82f6'
                      : appt.status === 'in_service'
                      ? '#f59e0b'
                      : appt.status === 'completed'
                      ? '#10b981'
                      : appt.status === 'no_show'
                      ? '#f43f5e'
                      : '#94a3b8',
                  color: '#ffffff',
                }}
              >
                {appt.status.toUpperCase().replace('_', ' ')}
              </span>
            </span>
          </div>

          {/* Services list */}
          {appt.services && appt.services.length > 0 && (
            <div style={{ marginTop: '12px' }}>
              <div
                style={{
                  fontSize: '12px',
                  fontWeight: 700,
                  color: '#0f172a',
                  marginBottom: '6px',
                }}
              >
                Services ({appt.services.length}):
              </div>
              <div
                style={{
                  backgroundColor: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  borderRadius: '8px',
                  padding: '8px 12px',
                  maxHeight: '120px',
                  overflowY: 'auto',
                }}
              >
                {appt.services.map((sv, idx) => (
                  <div
                    key={idx}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      fontSize: '12.5px',
                      padding: '3px 0',
                    }}
                  >
                    <span style={{ color: '#334155' }}>
                      • {sv.name || sv.product_name || 'Service'}
                    </span>
                    {sv.price !== undefined && (
                      <span style={{ fontWeight: 700, color: '#0f172a' }}>
                        ${fmtMoney(sv.price)}
                      </span>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Total Amount */}
          {appt.total_amount && parseFloat(String(appt.total_amount)) > 0 && (
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '8px 12px',
                backgroundColor: '#fff1f2',
                border: '1px solid #fecdd3',
                borderRadius: '8px',
                marginTop: '10px',
              }}
            >
              <span
                style={{
                  fontSize: '12.5px',
                  fontWeight: 700,
                  color: '#9f1239',
                }}
              >
                Total Amount:
              </span>
              <span
                style={{
                  fontSize: '14.5px',
                  fontWeight: 800,
                  color: '#e11d48',
                }}
              >
                ${fmtMoney(appt.total_amount)}
              </span>
            </div>
          )}

          {/* Notes */}
          {appt.notes && (
            <div style={{ marginTop: '10px', fontSize: '12px', color: '#475569' }}>
              <strong>Notes:</strong> {appt.notes}
            </div>
          )}

          {/* Duration Extension Box (for booked & in_service) */}
          {(appt.status === 'booked' || appt.status === 'in_service') && (
            <div className="appt-extend-box">
              <div className="appt-extend-top">
                <span className="appt-extend-title">
                  <Timer size={14} />
                  Extend Duration
                </span>
                <span className="appt-extend-current">
                  {currentDurationM}m currently
                </span>
              </div>
              <div className="appt-extend-buttons">
                {[15, 30, 45, 60].map((m) => (
                  <button
                    key={m}
                    type="button"
                    className="appt-extend-btn"
                    disabled={isExtending}
                    onClick={() => handleExtendDuration(m)}
                  >
                    +{m} min
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Action buttons */}
          <div className="appt-actions-wrap">
            {appt.status === 'booked' && (
              <>
                <button
                  type="button"
                  className="appt-action-btn"
                  style={{
                    backgroundColor: '#fffbeb',
                    borderColor: '#f59e0b',
                    color: '#b45309',
                  }}
                  onClick={async () => {
                    await onStatusChange('in_service');
                    onStartService();
                  }}
                >
                  <Play size={14} />
                  <span>Start Service</span>
                </button>
                <button
                  type="button"
                  className="appt-action-btn"
                  style={{
                    backgroundColor: '#eff6ff',
                    borderColor: '#3b82f6',
                    color: '#1d4ed8',
                  }}
                  onClick={onOpenReschedule}
                >
                  <CalendarCheck size={14} />
                  <span>Reschedule</span>
                </button>
                <button
                  type="button"
                  className="appt-action-btn"
                  style={{
                    backgroundColor: '#fff1f2',
                    borderColor: '#f43f5e',
                    color: '#be123c',
                  }}
                  onClick={() => onStatusChange('no_show')}
                >
                  <UserX size={14} />
                  <span>Mark No Show</span>
                </button>
                <button
                  type="button"
                  className="appt-action-btn"
                  style={{
                    backgroundColor: '#f1f5f9',
                    borderColor: '#94a3b8',
                    color: '#475569',
                  }}
                  onClick={() => onStatusChange('cancelled')}
                >
                  <CalendarX size={14} />
                  <span>Cancel Booking</span>
                </button>
                {allowDeleteService && (
                  <button
                    type="button"
                    className="appt-action-btn"
                    style={{
                      backgroundColor: '#fff1f2',
                      borderColor: '#e11d48',
                      color: '#e11d48',
                    }}
                    onClick={onDeleteClick}
                  >
                    <Trash2 size={14} />
                    <span>Delete</span>
                  </button>
                )}
              </>
            )}

            {appt.status === 'in_service' && (
              <>
                <button
                  type="button"
                  className="appt-action-btn"
                  style={{
                    backgroundColor: '#f0fdf4',
                    borderColor: '#10b981',
                    color: '#047857',
                  }}
                  onClick={onStartService}
                >
                  <Play size={14} />
                  <span>Continue in Cart</span>
                </button>
                <button
                  type="button"
                  className="appt-action-btn"
                  style={{
                    backgroundColor: '#eff6ff',
                    borderColor: '#3b82f6',
                    color: '#1d4ed8',
                  }}
                  onClick={onOpenReschedule}
                >
                  <CalendarCheck size={14} />
                  <span>Reschedule</span>
                </button>
                <button
                  type="button"
                  className="appt-action-btn"
                  style={{
                    backgroundColor: '#fffbeb',
                    borderColor: '#d97706',
                    color: '#b45309',
                  }}
                  onClick={() => onStatusChange('booked')}
                >
                  <Pause size={14} />
                  <span>Stop Service</span>
                </button>
                <button
                  type="button"
                  className="appt-action-btn"
                  style={{
                    backgroundColor: '#f1f5f9',
                    borderColor: '#94a3b8',
                    color: '#475569',
                  }}
                  onClick={() => onStatusChange('cancelled')}
                >
                  <CalendarX size={14} />
                  <span>Cancel</span>
                </button>
                {allowDeleteService && (
                  <button
                    type="button"
                    className="appt-action-btn"
                    style={{
                      backgroundColor: '#fff1f2',
                      borderColor: '#e11d48',
                      color: '#e11d48',
                    }}
                    onClick={onDeleteClick}
                  >
                    <Trash2 size={14} />
                    <span>Delete</span>
                  </button>
                )}
              </>
            )}

            {(appt.status === 'cancelled' || appt.status === 'no_show') && (
              <button
                type="button"
                className="appt-action-btn"
                style={{
                  backgroundColor: '#eff6ff',
                  borderColor: '#3b82f6',
                  color: '#1d4ed8',
                }}
                onClick={() => {
                  onClose();
                  onOpenReschedule();
                }}
              >
                <RotateCcw size={14} />
                <span>Rebook</span>
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ==========================================================================
   SUB-MODAL: ExactRescheduleModal
   ========================================================================== */
interface ExactRescheduleModalProps {
  appt: Appointment;
  staffList: Staff[];
  timeFormat: '12' | '24';
  onClose: () => void;
  onSuccess: () => void;
}

function ExactRescheduleModal({
  appt,
  staffList,
  onClose,
  onSuccess,
}: ExactRescheduleModalProps) {
  const [targetStaffId, setTargetStaffId] = useState<number>(appt.staff_id);
  const [targetDate, setTargetDate] = useState<string>(appt.appointment_date);
  const [startTime, setStartTime] = useState<string>(appt.start_time);
  const [endTime, setEndTime] = useState<string>(appt.end_time);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState<boolean>(false);

  const startM = timeToMinutes(startTime);
  const endM = timeToMinutes(endTime);
  const dur = endM - startM;
  const isValidRange = dur > 0;
  const durStr = isValidRange
    ? `${dur} minutes (${Math.floor(dur / 60)}h ${dur % 60}m)`
    : 'Invalid duration';

  const handleSave = async () => {
    if (!isValidRange) {
      setErrorMsg('End time must be after start time.');
      return;
    }

    setIsSaving(true);
    setErrorMsg(null);

    try {
      // Conflict check
      const conflictRes = await appointmentApi.checkConflict({
        staff_id: targetStaffId,
        appointment_date: targetDate,
        startTime: startTime.trim(),
        endTime: endTime.trim(),
        exclude_id: appt.id,
      } as any);

      if (conflictRes.data.has_conflict) {
        const conf = conflictRes.data.conflicting_appointment;
        const range = conf ? ` (${conf.start_time} - ${conf.end_time})` : '';
        const targetStaff = staffList.find((s) => s.id === targetStaffId);
        setErrorMsg(
          `Collision: ${targetStaff?.name || 'Staff'} is already booked${range}.`
        );
        setIsSaving(false);
        return;
      }

      const targetStaff = staffList.find((s) => s.id === targetStaffId);
      await appointmentApi.update(appt.id, {
        staff_id: targetStaffId,
        staff_name: targetStaff?.name || '',
        appointment_date: targetDate,
        start_time: startTime.trim(),
        end_time: endTime.trim(),
      });

      toast.success(
        `Rescheduled to ${targetStaff?.name} at ${startTime} - ${endTime} on ${targetDate}`
      );
      onSuccess();
    } catch {
      setErrorMsg('Failed to update appointment on server.');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="appt-modal-overlay" onClick={onClose}>
      <div
        className="appt-modal appt-modal--reschedule"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="appt-modal__header">
          <div>
            <span className="appt-modal__title">Exact Reschedule</span>
            <div style={{ fontSize: '11.5px', color: '#64748b' }}>
              {appt.customer_name}
            </div>
          </div>
          <button
            type="button"
            className="appt-modal__close-btn"
            onClick={onClose}
          >
            <X size={18} />
          </button>
        </div>

        <div className="appt-modal__body">
          <div className="appt-form-group">
            <label className="appt-form-label">Staff Member</label>
            <select
              className="appt-form-select"
              value={targetStaffId}
              onChange={(e) => {
                setTargetStaffId(Number(e.target.value));
                setErrorMsg(null);
              }}
            >
              {staffList.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name} ({s.role || 'Staff'})
                </option>
              ))}
            </select>
          </div>

          <div className="appt-form-group">
            <label className="appt-form-label">Date</label>
            <input
              type="date"
              className="appt-form-input"
              value={targetDate}
              onChange={(e) => {
                setTargetDate(e.target.value);
                setErrorMsg(null);
              }}
            />
          </div>

          <div style={{ display: 'flex', gap: '12px' }}>
            <div className="appt-form-group" style={{ flex: 1 }}>
              <label className="appt-form-label">Start Time (HH:mm)</label>
              <input
                type="text"
                className="appt-form-input"
                value={startTime}
                onChange={(e) => {
                  setStartTime(e.target.value);
                  setErrorMsg(null);
                }}
                placeholder="11:43"
              />
            </div>
            <div className="appt-form-group" style={{ flex: 1 }}>
              <label className="appt-form-label">End Time (HH:mm)</label>
              <input
                type="text"
                className="appt-form-input"
                value={endTime}
                onChange={(e) => {
                  setEndTime(e.target.value);
                  setErrorMsg(null);
                }}
                placeholder="12:57"
              />
            </div>
          </div>

          {/* Quick duration shortcuts */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              marginBottom: '12px',
            }}
          >
            <span style={{ fontSize: '11px', color: '#64748b' }}>
              Quick Duration:
            </span>
            {[30, 45, 60, 90].map((d) => (
              <button
                key={d}
                type="button"
                style={{
                  padding: '3px 8px',
                  borderRadius: '4px',
                  backgroundColor: '#eff6ff',
                  border: '1px solid #bfdbfe',
                  color: '#2563eb',
                  fontSize: '10.5px',
                  fontWeight: 600,
                  cursor: 'pointer',
                }}
                onClick={() => {
                  const sM = timeToMinutes(startTime);
                  setEndTime(minutesToTime24(sM + d));
                  setErrorMsg(null);
                }}
              >
                {d}m
              </button>
            ))}
          </div>

          {/* Calculated duration banner */}
          <div
            style={{
              padding: '8px 12px',
              borderRadius: '8px',
              backgroundColor: isValidRange ? '#f0fdf4' : '#fff1f2',
              border: `1px solid ${isValidRange ? '#bbf7d0' : '#fecdd3'}`,
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '12px',
              fontWeight: 600,
              color: isValidRange ? '#15803d' : '#be123c',
            }}
          >
            <Timer size={15} />
            <span>Total Slot: {durStr}</span>
          </div>

          {errorMsg && (
            <div className="appt-alert-banner" style={{ marginTop: '12px' }}>
              <AlertCircle size={15} />
              <span>{errorMsg}</span>
            </div>
          )}
        </div>

        <div className="appt-modal__footer">
          <button
            type="button"
            className="appt-btn-cancel"
            onClick={onClose}
            disabled={isSaving}
          >
            Cancel
          </button>
          <button
            type="button"
            className="appt-btn-primary"
            style={{ backgroundColor: '#3b82f6' }}
            onClick={handleSave}
            disabled={isSaving}
          >
            {isSaving ? 'Saving...' : 'Save Reschedule'}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ==========================================================================
   SUB-MODAL: StaffInfoModal
   ========================================================================== */
interface StaffInfoModalProps {
  staff: Staff;
  color: string;
  appointments: Appointment[];
  onClose: () => void;
  onViewSchedule: () => void;
}

function StaffInfoModal({
  staff,
  color,
  appointments,
  onClose,
  onViewSchedule,
}: StaffInfoModalProps) {
  const staffAppts = appointments.filter((a) => a.staff_id === staff.id);
  const bookedCount = staffAppts.filter((a) => a.status === 'booked').length;
  const inServiceCount = staffAppts.filter(
    (a) => a.status === 'in_service'
  ).length;
  const completedCount = staffAppts.filter(
    (a) => a.status === 'completed'
  ).length;

  return (
    <div className="appt-modal-overlay" onClick={onClose}>
      <div
        className="appt-modal appt-modal--staff-info"
        onClick={(e) => e.stopPropagation()}
      >
        <div
          style={{
            position: 'absolute',
            right: '14px',
            top: '14px',
          }}
        >
          <button
            type="button"
            className="appt-modal__close-btn"
            onClick={onClose}
          >
            <X size={18} />
          </button>
        </div>

        <div className="appt-modal__body" style={{ paddingTop: '30px' }}>
          <div className="staff-info-body">
            <div
              className="staff-info-avatar"
              style={{ backgroundColor: color }}
            >
              {staff.name ? staff.name[0].toUpperCase() : 'S'}
            </div>

            <div className="staff-info-name">{staff.name}</div>
            <div
              className="staff-info-role"
              style={{
                backgroundColor: `${color}15`,
                color: color,
              }}
            >
              {staff.role || 'Staff'}
            </div>

            <div className="staff-info-stats">
              {staff.email && (
                <div className="staff-info-stat-row">
                  <span>Email:</span>
                  <span>{staff.email}</span>
                </div>
              )}
              {staff.phone && (
                <div className="staff-info-stat-row">
                  <span>Phone:</span>
                  <span>{staff.phone}</span>
                </div>
              )}
              <div className="staff-info-stat-row">
                <span>Booked Today:</span>
                <span>{bookedCount}</span>
              </div>
              <div className="staff-info-stat-row">
                <span>In Service:</span>
                <span>{inServiceCount}</span>
              </div>
              <div className="staff-info-stat-row">
                <span>Completed:</span>
                <span>{completedCount}</span>
              </div>
            </div>

            <div style={{ display: 'flex', gap: '10px', width: '100%' }}>
              <button
                type="button"
                className="appt-btn-cancel"
                style={{ flex: 1 }}
                onClick={onClose}
              >
                Close
              </button>
              <button
                type="button"
                className="appt-btn-primary"
                style={{ flex: 1, backgroundColor: color }}
                onClick={onViewSchedule}
              >
                View Schedule
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

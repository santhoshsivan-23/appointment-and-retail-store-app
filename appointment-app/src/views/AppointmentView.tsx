import { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import { toast } from 'react-toastify';
import {
  Calendar as CalendarIcon,
  CalendarPlus,
  ChevronLeft,
  ChevronRight,
  RefreshCw,
  Search,
  X,
  Plus,
  Clock,
  User,
  Users,
  UserPlus,
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
  Edit3,
  CheckCircle2,
  LayoutGrid,
  Scissors,
  FileText,
  Receipt,
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
  return `${WEEKDAYS_LONG[d.getDay()]}, ${d.getDate()} ${MONTHS_SHORT[d.getMonth()]
    } ${d.getFullYear()}`;
}

const fmtMoney = (val: number | string | null | undefined): string => {
  if (val === null || val === undefined) return '0.00';
  const num = typeof val === 'number' ? val : parseFloat(String(val));
  return isNaN(num) ? '0.00' : num.toFixed(2);
};

export function useIsMobile(breakpoint = 768) {
  const [isMobile, setIsMobile] = useState<boolean>(() =>
    typeof window !== 'undefined' ? window.innerWidth <= breakpoint : false
  );

  useEffect(() => {
    const handleResize = () => {
      setIsMobile(window.innerWidth <= breakpoint);
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [breakpoint]);

  return isMobile;
}

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
  const business = useAppSelector((s) => s.auth.business);
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
  const [isMobileSearchOpen, setIsMobileSearchOpen] = useState<boolean>(false);

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
          } catch (_) { }
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

  /* ── Mobile View Memos & Visual Helpers ─────────────────────────────────── */
  const weekDays = useMemo(() => {
    const curr = new Date(selectedDate);
    const dayOfWeek = curr.getDay(); // 0 is Sunday
    const diffToMonday = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
    const monday = new Date(curr);
    monday.setDate(curr.getDate() + diffToMonday);

    const days: Date[] = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(monday);
      d.setDate(monday.getDate() + i);
      days.push(d);
    }
    return days;
  }, [selectedDate]);

  const mobileTimelineAppointments = useMemo(() => {
    let list = appointments;
    if (selectedStaffFilter !== null) {
      list = list.filter((a) => a.staff_id === selectedStaffFilter);
    }
    if (selectedStatusFilter !== null) {
      list = list.filter((a) => a.status === selectedStatusFilter);
    }
    if (customerSearchQuery.trim()) {
      const q = customerSearchQuery.toLowerCase().trim();
      list = list.filter(
        (a) =>
          (a.customer_name && a.customer_name.toLowerCase().includes(q)) ||
          (a.customer_phone && a.customer_phone.includes(q)) ||
          (a.services &&
            a.services.some(
              (s) =>
                (s.name && s.name.toLowerCase().includes(q)) ||
                (s.product_name && s.product_name.toLowerCase().includes(q))
            ))
      );
    }
    return [...list].sort((a, b) =>
      (a.start_time || '').localeCompare(b.start_time || '')
    );
  }, [
    appointments,
    selectedStaffFilter,
    selectedStatusFilter,
    customerSearchQuery,
  ]);

  const groupedByTime = useMemo(() => {
    const groups: { time: string; items: Appointment[] }[] = [];
    mobileTimelineAppointments.forEach((appt) => {
      const t = appt.start_time || '09:00';
      const existing = groups.find((g) => g.time === t);
      if (existing) {
        existing.items.push(appt);
      } else {
        groups.push({ time: t, items: [appt] });
      }
    });
    return groups;
  }, [mobileTimelineAppointments]);

  const getStatusVisuals = (status: string) => {
    switch (status?.toLowerCase()) {
      case 'in_service':
      case 'inservice':
        return {
          label: 'IN SERVICE',
          cardClass: 'mobile-appt-card--inservice',
          borderColor: '#f59e0b',
          badgeBg: '#fef3c7',
          badgeColor: '#b45309',
        };
      case 'completed':
        return {
          label: 'COMPLETED',
          cardClass: 'mobile-appt-card--completed',
          borderColor: '#10b981',
          badgeBg: '#d1fae5',
          badgeColor: '#065f46',
        };
      case 'no_show':
      case 'noshow':
        return {
          label: 'NO-SHOW',
          cardClass: 'mobile-appt-card--noshow',
          borderColor: '#f43f5e',
          badgeBg: '#ffe4e6',
          badgeColor: '#be123c',
        };
      case 'cancelled':
      case 'canceled':
        return {
          label: 'CANCELLED',
          cardClass: 'mobile-appt-card--cancelled',
          borderColor: '#94a3b8',
          badgeBg: '#f1f5f9',
          badgeColor: '#475569',
        };
      case 'booked':
      default:
        return {
          label: 'BOOKED',
          cardClass: 'mobile-appt-card--booked',
          borderColor: '#3b82f6',
          badgeBg: '#dbeafe',
          badgeColor: '#1e40af',
        };
    }
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
      {/* ── Desktop View (> 768px): Completely Intact & Unchanged ── */}
      <div className="appointment-desktop-view">
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
            <span>New Appointmentd</span>
          </button>
        </header>

        {/* ── 2. Staff Pills Filter Bar ───────────────────────────────────── */}
        <div className="appointment-staff-bar">
          <span className="appointment-staff-bar__label">Filter Staff:</span>
          <div className="appointment-staff-bar__pills">
            {/* All Staff Pill */}
            <div
              className={`staff-pill ${selectedStaffFilter === null
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
              className={`staff-pill staff-pill--toggle-cal ${isCalendarHidden ? 'staff-pill--toggle-cal-active' : ''
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
                      className={`timetable-time-slot ${outside ? 'timetable-time-slot--outside' : ''
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
                            className={`timetable-lane-slot ${outside ? 'timetable-lane-slot--outside' : ''
                              } ${isHoverTarget
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
                                className={`timetable-slot-drop-badge ${isBlocked
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
                            className={`appointment-card appointment-card--${appt.status
                              } ${draggingApptId === appt.id
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
                        className={`month-calendar__day ${!isCurrentMonth ? 'month-calendar__day--other-month' : ''
                          } ${isToday ? 'month-calendar__day--today' : ''} ${isSelected ? 'month-calendar__day--selected' : ''
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
                      className={`status-card ${isActive ? 'status-card--active' : ''
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
      </div>
      {/* ── End Desktop View ── */}

      {/* ── Mobile View (<= 768px): Tailored Schedule Experience ── */}
      <div className="appointment-mobile-view">
        {/* BEGIN: TopBar & Date Header */}
        <header className="mobile-appt-header">
          {/* App Bar Title & Quick Actions */}
          <div className="mobile-appt-header__top">
            <div>
              <span className="mobile-appt-header__studio">
                {business?.business_name || 'Omopet Studio'}
              </span>
              <h1 className="mobile-appt-header__title">
                Schedule
                <span className="mobile-appt-header__month-badge">
                  {MONTHS_SHORT[selectedDate.getMonth()]} {selectedDate.getFullYear()}
                </span>
              </h1>
            </div>
            <div className="mobile-appt-header__actions">
              {/* Calendar Day Picker Toggle */}
              <label
                aria-label="Open Calendar"
                className="mobile-header-icon-btn"
                title="Pick Date"
              >
                <CalendarIcon size={18} />
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

              {/* Search Toggle */}
              <button
                type="button"
                aria-label="Search"
                className={`mobile-header-icon-btn ${isMobileSearchOpen ? 'mobile-header-icon-btn--active' : ''
                  }`}
                onClick={() => setIsMobileSearchOpen(!isMobileSearchOpen)}
              >
                <Search size={18} />
              </button>

              {/* Refresh Schedule */}
              <button
                type="button"
                aria-label="Refresh"
                className="mobile-header-icon-btn"
                onClick={loadData}
                title="Refresh schedule"
              >
                <RefreshCw size={16} />
              </button>
            </div>
          </div>

          {/* Search Bar when expanded */}
          {isMobileSearchOpen && (
            <div className="mobile-search-bar">
              <Search size={15} className="mobile-search-icon" />
              <input
                type="text"
                className="mobile-search-input"
                placeholder="Search customer, phone, or service..."
                value={customerSearchQuery}
                onChange={(e) => setCustomerSearchQuery(e.target.value)}
                autoFocus
              />
              {customerSearchQuery && (
                <button
                  type="button"
                  className="mobile-search-clear"
                  onClick={() => setCustomerSearchQuery('')}
                >
                  <X size={14} />
                </button>
              )}
            </div>
          )}

          {/* Date Carousel / Week Strip */}
          <div className="mobile-week-strip no-scrollbar">
            {weekDays.map((d, idx) => {
              const isSelected =
                formatDateYMD(d) === formatDateYMD(selectedDate);
              const dayName = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][
                d.getDay()
              ];
              const isTodayDate =
                formatDateYMD(d) === formatDateYMD(new Date());

              return (
                <button
                  key={idx}
                  type="button"
                  className={`mobile-week-day ${isSelected ? 'mobile-week-day--active' : ''
                    }`}
                  onClick={() => {
                    setSelectedDate(d);
                    setCalendarMonth(new Date(d.getFullYear(), d.getMonth(), 1));
                  }}
                >
                  <span className="mobile-week-day__name">{dayName}</span>
                  <span className="mobile-week-day__num">{d.getDate()}</span>
                  {isSelected ? (
                    <span className="mobile-week-day__dot" />
                  ) : isTodayDate ? (
                    <span className="mobile-week-day__today-dot" />
                  ) : null}
                </button>
              );
            })}
          </div>

          {/* Staff Filter Chips Row */}
          <div className="mobile-staff-chips-row no-scrollbar">
            {/* 'All Staff' Chip */}
            <button
              type="button"
              className={`mobile-staff-chip ${selectedStaffFilter === null
                ? 'mobile-staff-chip--all-active'
                : ''
                }`}
              onClick={() => setSelectedStaffFilter(null)}
            >
              {selectedStaffFilter === null && (
                <Check size={13} strokeWidth={2.5} />
              )}
              <span>All Staff</span>
            </button>

            {/* Individual Staff Chips */}
            {staffList.map((s, idx) => {
              const col = staffColor(idx);
              const isSel = selectedStaffFilter === s.id;
              return (
                <button
                  key={s.id}
                  type="button"
                  className={`mobile-staff-chip ${isSel ? 'mobile-staff-chip--selected' : ''
                    }`}
                  style={{
                    borderColor: isSel ? col : `${col}40`,
                    backgroundColor: isSel ? `${col}15` : '#ffffff',
                    color: isSel ? col : '#334155',
                  }}
                  onClick={() => setSelectedStaffFilter(isSel ? null : s.id)}
                >
                  <span
                    className="mobile-staff-chip__avatar"
                    style={{ backgroundColor: col }}
                  >
                    {s.name ? s.name[0].toUpperCase() : 'S'}
                  </span>
                  <span>{s.name}</span>
                </button>
              );
            })}
          </div>
        </header>
        {/* END: TopBar & Date Header */}

        {/* BEGIN: Quick KPI Status Bar (Day Overview) */}
        <section className="mobile-kpi-bar">
          <div className="mobile-kpi-bar__header">
            <h2 className="mobile-kpi-bar__title">Day Overview</h2>
            <span className="mobile-kpi-bar__badge">
              {overviewStats.total || appointments.length} total
            </span>
          </div>
          <div className="mobile-kpi-grid">
            {/* Booked */}
            <div
              className={`mobile-kpi-card ${selectedStatusFilter === 'booked'
                ? 'mobile-kpi-card--active'
                : ''
                }`}
              style={{
                backgroundColor: '#EFF6FF',
                borderColor:
                  selectedStatusFilter === 'booked' ? '#3B82F6' : '#DBEAFE',
              }}
              onClick={() =>
                setSelectedStatusFilter(
                  selectedStatusFilter === 'booked' ? null : 'booked'
                )
              }
            >
              <div className="mobile-kpi-card__label-row">
                <span
                  className="mobile-kpi-card__dot"
                  style={{ backgroundColor: '#3B82F6' }}
                />
                <span
                  className="mobile-kpi-card__label"
                  style={{ color: '#1E40AF' }}
                >
                  Booked
                </span>
              </div>
              <span
                className="mobile-kpi-card__count"
                style={{ color: '#1D4ED8' }}
              >
                {overviewStats.booked || 0}
              </span>
            </div>

            {/* In Service */}
            <div
              className={`mobile-kpi-card ${selectedStatusFilter === 'in_service'
                ? 'mobile-kpi-card--active'
                : ''
                }`}
              style={{
                backgroundColor: '#FFFBEB',
                borderColor:
                  selectedStatusFilter === 'in_service' ? '#F59E0B' : '#FEF3C7',
              }}
              onClick={() =>
                setSelectedStatusFilter(
                  selectedStatusFilter === 'in_service' ? null : 'in_service'
                )
              }
            >
              <div className="mobile-kpi-card__label-row">
                <span
                  className="mobile-kpi-card__dot"
                  style={{ backgroundColor: '#F59E0B' }}
                />
                <span
                  className="mobile-kpi-card__label"
                  style={{ color: '#92400E' }}
                >
                  In Svc
                </span>
              </div>
              <span
                className="mobile-kpi-card__count"
                style={{ color: '#B45309' }}
              >
                {overviewStats.in_service || 0}
              </span>
            </div>

            {/* Completed */}
            <div
              className={`mobile-kpi-card ${selectedStatusFilter === 'completed'
                ? 'mobile-kpi-card--active'
                : ''
                }`}
              style={{
                backgroundColor: '#ECFDF5',
                borderColor:
                  selectedStatusFilter === 'completed' ? '#10B981' : '#D1FAE5',
              }}
              onClick={() =>
                setSelectedStatusFilter(
                  selectedStatusFilter === 'completed' ? null : 'completed'
                )
              }
            >
              <div className="mobile-kpi-card__label-row">
                <span
                  className="mobile-kpi-card__dot"
                  style={{ backgroundColor: '#10B981' }}
                />
                <span
                  className="mobile-kpi-card__label"
                  style={{ color: '#065F46' }}
                >
                  Done
                </span>
              </div>
              <span
                className="mobile-kpi-card__count"
                style={{ color: '#047857' }}
              >
                {overviewStats.completed || 0}
              </span>
            </div>

            {/* No-show */}
            <div
              className={`mobile-kpi-card ${selectedStatusFilter === 'no_show'
                ? 'mobile-kpi-card--active'
                : ''
                }`}
              style={{
                backgroundColor: '#FFF1F2',
                borderColor:
                  selectedStatusFilter === 'no_show' ? '#F43F5E' : '#FFE4E6',
              }}
              onClick={() =>
                setSelectedStatusFilter(
                  selectedStatusFilter === 'no_show' ? null : 'no_show'
                )
              }
            >
              <div className="mobile-kpi-card__label-row">
                <span
                  className="mobile-kpi-card__dot"
                  style={{ backgroundColor: '#F43F5E' }}
                />
                <span
                  className="mobile-kpi-card__label"
                  style={{ color: '#9F1239' }}
                >
                  No-show
                </span>
              </div>
              <span
                className="mobile-kpi-card__count"
                style={{ color: '#BE123C' }}
              >
                {overviewStats.no_show || 0}
              </span>
            </div>
          </div>
        </section>
        {/* END: Quick KPI Status Bar */}

        {/* BEGIN: Appointments Timeline Section */}
        <main className="mobile-timeline-section">
          {mobileTimelineAppointments.length === 0 ? (
            <div className="mobile-empty-schedule">
              <CalendarCheck size={36} color="#94A3B8" />
              <h3>No Appointments Scheduled</h3>
              <p>No appointments match the selected date or filter.</p>
              <button
                type="button"
                className="mobile-empty-book-btn"
                onClick={() => {
                  setModalNewApptPreset(null);
                  setModalNewApptOpen(true);
                }}
              >
                <Plus size={16} />
                <span>Book New Appointment</span>
              </button>
            </div>
          ) : (
            groupedByTime.map((group) => (
              <div key={group.time} className="mobile-time-block">
                {/* Timeline Block Header */}
                <div className="mobile-time-divider">
                  <span className="mobile-time-label">
                    {formatSlotLabel(group.time, timeFormat)}
                  </span>
                  <div className="mobile-time-divider__line" />
                </div>

                {/* Slot Appointment Cards */}
                <div className="mobile-time-cards-stack">
                  {group.items.map((appt) => {
                    const statusConfig = getStatusVisuals(appt.status);
                    const staffIdx = staffList.findIndex(
                      (s) => s.id === appt.staff_id
                    );
                    const staffCol =
                      staffIdx >= 0 ? staffColor(staffIdx) : '#64748b';
                    const serviceSummary =
                      appt.services && appt.services.length > 0
                        ? appt.services
                          .map((s) => s.name || s.product_name)
                          .filter(Boolean)
                          .join(', ')
                        : 'General Consultation';

                    return (
                      <div
                        key={appt.id}
                        className={`mobile-appt-card ${statusConfig.cardClass}`}
                        style={{ borderLeftColor: statusConfig.borderColor }}
                        onClick={() => setModalDetailsAppt(appt)}
                      >
                        <div className="mobile-appt-card__top">
                          <div>
                            <div className="mobile-appt-card__name-row">
                              <span className="mobile-appt-card__name">
                                {appt.customer_name || 'Walk-in Guest'}
                              </span>
                              <span
                                className="mobile-appt-card__status-badge"
                                style={{
                                  backgroundColor: statusConfig.badgeBg,
                                  color: statusConfig.badgeColor,
                                }}
                              >
                                {statusConfig.label}
                              </span>
                            </div>
                            <p className="mobile-appt-card__services">
                              {serviceSummary}
                            </p>
                          </div>

                          <div className="mobile-appt-card__meta-col">
                            <span className="mobile-appt-card__time">
                              {formatApptTimeRange(
                                appt.start_time,
                                appt.end_time,
                                timeFormat
                              )}
                            </span>
                            <div
                              className="mobile-appt-card__staff-chip"
                              style={{
                                backgroundColor: `${staffCol}15`,
                                borderColor: `${staffCol}30`,
                                color: staffCol,
                              }}
                            >
                              <span
                                className="mobile-appt-card__staff-dot"
                                style={{ backgroundColor: staffCol }}
                              />
                              <span>{appt.staff_name || 'Staff'}</span>
                            </div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            ))
          )}

          {/* Salon Closes Divider */}
          <div className="mobile-time-divider pt-2">
            <span className="mobile-time-label">
              {formatSlotLabel(closeTime, timeFormat)}
            </span>
            <div className="mobile-time-divider__line" />
            <span className="mobile-time-close-text">Salon Closes</span>
          </div>
        </main>
        {/* END: Appointments Timeline Section */}

        {/* Floating New Appointment Action Button */}
        <div className="mobile-floating-action-wrap">
          <button
            type="button"
            className="mobile-floating-new-btn"
            onClick={() => {
              setModalNewApptPreset(null);
              setModalNewApptOpen(true);
            }}
          >
            <Plus size={20} strokeWidth={2.5} />
            <span>New Appointment</span>
          </button>
        </div>
      </div>
      {/* ── End Mobile View ── */}

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
          allAppointments={appointments}
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
  allAppointments?: Appointment[];
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
  allAppointments,
  onClose,
  onSuccess,
}: NewAppointmentModalProps) {
  const isMobile = useIsMobile();
  const [mobileSubView, setMobileSubView] = useState<'main' | 'services'>('main');

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
    } catch (_) { }
    return null;
  }, [startTimeInput, startPeriod, endTimeInput, endPeriod, timeFormat]);

  // Current start & end in 24h
  const currentStart24 = useMemo(() => {
    if (timeFormat === '12') {
      try {
        return convert12To24(startTimeInput.trim(), startPeriod);
      } catch {
        return startTimeInput.trim();
      }
    }
    return startTimeInput.trim();
  }, [startTimeInput, startPeriod, timeFormat]);

  const currentEnd24 = useMemo(() => {
    if (timeFormat === '12') {
      try {
        return convert12To24(endTimeInput.trim(), endPeriod);
      } catch {
        return endTimeInput.trim();
      }
    }
    return endTimeInput.trim();
  }, [endTimeInput, endPeriod, timeFormat]);

  // Generate daily time slots for quick selection based on openTime, closeTime, slotDuration
  const timeSlots = useMemo(() => {
    const list: string[] = [];
    const openM = timeToMinutes(openTime);
    const closeM = timeToMinutes(closeTime);
    const step = slotDuration > 0 ? slotDuration : 30;

    for (let m = openM; m < closeM; m += step) {
      list.push(minutesToTime24(m));
    }
    return list;
  }, [openTime, closeTime, slotDuration]);

  // Handle clicking a time slot chip
  const handleSelectSlot = (slot24: string) => {
    const end24 = addMinutesTo24h(slot24, slotDuration);
    if (timeFormat === '12') {
      const sSplit = split24To12(slot24);
      const eSplit = split24To12(end24);
      setStartTimeInput(sSplit.time);
      setStartPeriod(sSplit.period);
      setEndTimeInput(eSplit.time);
      setEndPeriod(eSplit.period);
    } else {
      setStartTimeInput(slot24);
      setEndTimeInput(end24);
    }
    setErrorBanner(null);
  };

  const isSlotSelected = (slot24: string) => currentStart24 === slot24;

  // Local Conflict Check (using already loaded allAppointments without extra API calls)
  const localConflictMessage = useMemo(() => {
    if (!allAppointments || allAppointments.length === 0 || !selectedStaffId || !apptDate) {
      return null;
    }

    const newStartM = timeToMinutes(currentStart24);
    const newEndM = timeToMinutes(currentEnd24);
    if (newEndM <= newStartM) return null;

    const targetDateStr = apptDate.split('T')[0];

    const hasConflict = allAppointments.some((a) => {
      if (a.staff_id !== selectedStaffId) return false;
      const aDate = a.appointment_date ? a.appointment_date.split('T')[0] : '';
      if (aDate !== targetDateStr) return false;
      if (a.status === 'cancelled' || a.status === 'no_show') return false;

      const aStartM = timeToMinutes(a.start_time);
      const aEndM = timeToMinutes(a.end_time);
      return newStartM < aEndM && newEndM > aStartM;
    });

    if (hasConflict) {
      return 'This staff member is already booked for the selected time slot. Please select another time or staff member.';
    }
    return null;
  }, [allAppointments, selectedStaffId, apptDate, currentStart24, currentEnd24]);

  const isSlotBookedForStaff = (slot24: string) => {
    if (!allAppointments || allAppointments.length === 0 || !selectedStaffId || !apptDate) return false;
    const sM = timeToMinutes(slot24);
    const eM = sM + (slotDuration > 0 ? slotDuration : 30);
    const targetDateStr = apptDate.split('T')[0];

    return allAppointments.some((a) => {
      if (a.staff_id !== selectedStaffId) return false;
      const aDate = a.appointment_date ? a.appointment_date.split('T')[0] : '';
      if (aDate !== targetDateStr) return false;
      if (a.status === 'cancelled' || a.status === 'no_show') return false;

      const aStartM = timeToMinutes(a.start_time);
      const aEndM = timeToMinutes(a.end_time);
      return sM < aEndM && eM > aStartM;
    });
  };

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

  // Customer search: ONLY call API when letters are typed (q.length >= 1)
  useEffect(() => {
    if (selectedCustomer) {
      setCustomerResults([]);
      setIsSearchingCustomers(false);
      return;
    }

    const q = customerSearch.trim();
    if (!q) {
      setCustomerResults([]);
      setIsSearchingCustomers(false);
      return;
    }

    // Call API only when user is actively searching with letters
    setIsSearchingCustomers(true);
    const timer = setTimeout(async () => {
      try {
        let apiCustomers: Customer[] = [];
        try {
          const res = await customerApi.getAll(q);
          if (Array.isArray(res.data)) {
            apiCustomers = res.data;
          } else if (Array.isArray(res.data?.data)) {
            apiCustomers = res.data.data;
          }
        } catch (apiErr) {
          console.warn('Customer search API error:', apiErr);
        }

        // Also check any existing customers from loaded allAppointments matching query
        const apptCustomers: Customer[] = [];
        if (allAppointments && allAppointments.length > 0) {
          const lowerQ = q.toLowerCase();
          const seen = new Set<string>(
            apiCustomers.map((c) => (c.phone || c.name || '').toLowerCase())
          );
          allAppointments.forEach((a, idx) => {
            const name = (a.customer_name || '').trim();
            const phone = (a.customer_phone || '').trim();
            if (
              name &&
              (name.toLowerCase().includes(lowerQ) ||
                (phone && phone.toLowerCase().includes(lowerQ)))
            ) {
              const key = (phone || name).toLowerCase();
              if (!seen.has(key)) {
                seen.add(key);
                apptCustomers.push({
                  id: a.customer_id || -(idx + 5000),
                  business_id: 1,
                  name,
                  phone,
                  email: '',
                  is_walk_in: false,
                });
              }
            }
          });
        }

        const combinedSeen = new Set<string>();
        const merged: Customer[] = [];
        [...apiCustomers, ...apptCustomers].forEach((c) => {
          const key = `${(c.phone || '').trim().toLowerCase()}|${(c.name || '').trim().toLowerCase()}`;
          if (!combinedSeen.has(key)) {
            combinedSeen.add(key);
            merged.push(c);
          }
        });

        setCustomerResults(merged);
      } catch (err) {
        console.error('Customer search error:', err);
        setCustomerResults([]);
      } finally {
        setIsSearchingCustomers(false);
      }
    }, 250);

    return () => clearTimeout(timer);
  }, [customerSearch, selectedCustomer, allAppointments]);

  // Customer validation check based on customer mode
  const isCustomerValid = useMemo(() => {
    if (isWalkIn) {
      return Boolean(walkInName.trim() && walkInPhone.trim());
    }
    return Boolean(selectedCustomer);
  }, [isWalkIn, walkInName, walkInPhone, selectedCustomer]);

  // Mobile Clock Time Picker Modal State
  const [timePickerTarget, setTimePickerTarget] = useState<'start' | 'end' | null>(null);
  const [activeTimeTab, setActiveTimeTab] = useState<'both' | 'hour' | 'minute'>('both');
  const [pickerHour, setPickerHour] = useState<number>(10);
  const [pickerMinute, setPickerMinute] = useState<number>(0);
  const [pickerPeriod, setPickerPeriod] = useState<'AM' | 'PM'>('AM');
  const [pickerError, setPickerError] = useState<string | null>(null);

  const handleOpenTimePicker = (target: 'start' | 'end') => {
    const current24 = target === 'start' ? currentStart24 : currentEnd24;
    const split = split24To12(current24);
    const [hStr, mStr] = split.time.split(':');
    setPickerHour(parseInt(hStr, 10) || 10);
    setPickerMinute(parseInt(mStr, 10) || 0);
    setPickerPeriod(split.period);
    setActiveTimeTab('both');
    setPickerError(null);
    setTimePickerTarget(target);
  };

  const handleSaveTimePicker = () => {
    const chosen24 = convert12To24(
      `${pickerHour}:${String(pickerMinute).padStart(2, '0')}`,
      pickerPeriod
    );
    const chosenM = timeToMinutes(chosen24);
    const openM = timeToMinutes(openTime);
    const closeM = timeToMinutes(closeTime);

    if (timePickerTarget === 'start') {
      if (chosenM < openM) {
        setPickerError(
          `Start time cannot be before business opening (${formatSlotLabel(openTime, '12')}).`
        );
        return;
      }
      if (chosenM >= closeM) {
        setPickerError(
          `Start time must be before business closing (${formatSlotLabel(closeTime, '12')}).`
        );
        return;
      }

      const currentEndM = timeToMinutes(currentEnd24);
      // If chosen start time is >= current end time, advance end time to maintain valid range
      if (chosenM >= currentEndM) {
        const step = slotDuration > 0 ? slotDuration : 30;
        const newEndM = Math.min(chosenM + step, closeM);
        const newEnd24 = minutesToTime24(newEndM);
        const endSplit = split24To12(newEnd24);
        setEndTimeInput(endSplit.time);
        setEndPeriod(endSplit.period);
      }

      const sSplit = split24To12(chosen24);
      setStartTimeInput(sSplit.time);
      setStartPeriod(sSplit.period);
      setErrorBanner(null);
      setTimePickerTarget(null);
    } else if (timePickerTarget === 'end') {
      const currentStartM = timeToMinutes(currentStart24);
      if (chosenM <= currentStartM) {
        setPickerError('End time must be later than the start time.');
        return;
      }
      if (chosenM - currentStartM < 15) {
        setPickerError('Appointment duration must be at least 15 minutes.');
        return;
      }
      if (chosenM > closeM) {
        setPickerError(
          `End time cannot exceed business closing (${formatSlotLabel(closeTime, '12')}).`
        );
        return;
      }

      const eSplit = split24To12(chosen24);
      setEndTimeInput(eSplit.time);
      setEndPeriod(eSplit.period);
      setErrorBanner(null);
      setTimePickerTarget(null);
    }
  };

  const targetStaff = staffList.find((s) => s.id === selectedStaffId);

  const handleConfirmBooking = async () => {
    setErrorBanner(null);

    if (localConflictMessage) {
      setErrorBanner(localConflictMessage);
      return;
    }

    if (!selectedStaffId) {
      setErrorBanner('Please select a staff member.');
      return;
    }

    if (!isWalkIn && !selectedCustomer) {
      setErrorBanner('Please search and select a customer from the dropdown, or switch to Walk-in.');
      return;
    }

    if (isWalkIn && (!walkInName.trim() || !walkInPhone.trim())) {
      setErrorBanner('Please enter both name and phone number for the walk-in customer.');
      return;
    }

    // Validate time
    const start24 = currentStart24;
    const end24 = currentEnd24;

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
      // 1. Conflict Check (Server API)
      const conflictRes = await appointmentApi.checkConflict({
        staff_id: selectedStaffId,
        appointment_date: apptDate,
        start_time: start24,
        end_time: end24,
      });

      if (conflictRes.data.has_conflict) {
        const conf = conflictRes.data.conflicting_appointment;
        const range = conf ? ` (${conf.start_time} - ${conf.end_time})` : '';
        setErrorBanner(
          `Collision: ${targetStaff?.name || 'Staff'} is already booked${range}.`
        );
        setIsSubmitting(false);
        return;
      }

      // 2. Submit Create Appointment
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
        `Booked appointment for ${custName} with ${targetStaff?.name || 'Staff'
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

  /* ── MOBILE FLOW (< 768px) ────────────────────────────────────────────── */
  if (isMobile) {
    // Flow A Subview: Category -> Product/Service Selection
    if (mobileSubView === 'services') {
      return (
        <div className="mobile-appt-modal-fullscreen">
          <div className="mobile-fullscreen-header">
            <button
              type="button"
              className="mobile-fullscreen-back-btn"
              onClick={() => setMobileSubView('main')}
            >
              <ChevronLeft size={20} />
              <span>Back</span>
            </button>
            <h2 className="mobile-fullscreen-title">Select Services</h2>
            <button
              type="button"
              className="mobile-fullscreen-done-btn"
              onClick={() => setMobileSubView('main')}
            >
              Done
            </button>
          </div>

          <div className="mobile-fullscreen-body">
            <div className="mobile-category-scroll no-scrollbar">
              <button
                type="button"
                className={`mobile-cat-pill ${selectedCategoryId === null ? 'mobile-cat-pill--active' : ''
                  }`}
                onClick={() => setSelectedCategoryId(null)}
              >
                All Services
              </button>
              {allowedCategories.map((c) => (
                <button
                  key={c.id}
                  type="button"
                  className={`mobile-cat-pill ${selectedCategoryId === c.id ? 'mobile-cat-pill--active' : ''
                    }`}
                  onClick={() => setSelectedCategoryId(c.id)}
                >
                  {c.name}
                </button>
              ))}
            </div>

            <div className="mobile-service-cards-list">
              {filteredProducts.length === 0 ? (
                <div className="mobile-empty-services">
                  No products or services available in this category
                </div>
              ) : (
                filteredProducts.map((p) => {
                  const isSelected = selectedProducts.some((sp) => sp.id === p.id);
                  return (
                    <div
                      key={p.id}
                      className={`mobile-service-card ${isSelected ? 'mobile-service-card--selected' : ''
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
                      <div className="mobile-service-card__checkbox">
                        <div
                          className={`mobile-checkbox-indicator ${isSelected ? 'mobile-checkbox-indicator--checked' : ''
                            }`}
                        >
                          {isSelected && <Check size={12} strokeWidth={3} />}
                        </div>
                      </div>
                      <div className="mobile-service-card__content">
                        <div className="mobile-service-card__name">{p.name}</div>
                        {p.description && (
                          <div className="mobile-service-card__desc">
                            {p.description}
                          </div>
                        )}
                      </div>
                      <div className="mobile-service-card__price">
                        ${fmtMoney(p.price)}
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          <div className="mobile-fullscreen-footer">
            <div className="mobile-service-summary-row">
              <span className="mobile-service-summary-count">
                {selectedProducts.length} service
                {selectedProducts.length === 1 ? '' : 's'} selected
              </span>
              <span className="mobile-service-summary-total">
                Total: ${fmtMoney(totalPrice)}
              </span>
            </div>
            <button
              type="button"
              className="mobile-btn-apply-services"
              onClick={() => setMobileSubView('main')}
            >
              Add to Appointment & Return
            </button>
          </div>
        </div>
      );
    }

    // Main Mobile Booking Screen (Flow A & Flow B)
    return (
      <div className="mobile-appt-modal-fullscreen">
        <div className="mobile-fullscreen-header">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-rose-50 border border-rose-200 flex items-center justify-center text-rose-600">
              <CalendarPlus size={18} />
            </div>
            <h2 className="mobile-fullscreen-title">Book New Appointment</h2>
          </div>
          <button
            type="button"
            className="mobile-fullscreen-close-btn"
            onClick={onClose}
          >
            <X size={20} />
          </button>
        </div>

        <div className="mobile-fullscreen-body">
          {/* 1. Staff Selection */}
          <div className="mobile-form-section mobile-staff-section mt-1">
            <div className="mobile-section-header">
              <div className="mobile-section-title-wrap">
                <span className="mobile-section-icon-badge mobile-icon-badge--blue">
                  <UserCheck size={15} />
                </span>
                <span className="mobile-section-title">Select Staff</span>
              </div>
              {targetStaff && (
                <div className="mobile-staff-selected-badge">
                  <span className="mobile-staff-selected-badge-check">
                    <Check size={10} strokeWidth={3} />
                  </span>
                  <span>{targetStaff.name}</span>
                </div>
              )}
            </div>
            <div className="mobile-staff-selector-row no-scrollbar">
              {staffList.map((s, idx) => {
                const isSel = selectedStaffId === s.id;
                const col = STAFF_COLORS[idx % STAFF_COLORS.length];
                return (
                  <button
                    key={s.id}
                    type="button"
                    className={`mobile-staff-select-card ${isSel ? 'mobile-staff-select-card--selected' : ''
                      }`}
                    style={
                      isSel
                        ? {
                          borderColor: col,
                          backgroundColor: `${col}10`,
                        }
                        : {
                          borderColor: '#e2e8f0',
                          backgroundColor: '#ffffff',
                        }
                    }
                    onClick={() => {
                      setSelectedStaffId(s.id);
                      setErrorBanner(null);
                    }}
                  >
                    <span
                      className="mobile-staff-card-avatar"
                      style={{
                        backgroundColor: col,
                        boxShadow: isSel ? `0 0 0 2px #ffffff, 0 0 0 4px ${col}` : 'none',
                      }}
                    >
                      {s.name ? s.name[0].toUpperCase() : 'S'}
                    </span>
                    <span
                      className="mobile-staff-card-name"
                      style={{ color: isSel ? '#0f172a' : '#334155', fontWeight: isSel ? 800 : 600 }}
                    >
                      {s.name}
                    </span>
                    <span
                      className="mobile-staff-card-role"
                      style={{ color: '#64748b' }}
                    >
                      {s.role || 'Staff'}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* 2. Date Selection */}
          <div className="mobile-form-section">
            <div className="mobile-section-header">
              <div className="mobile-section-title-wrap">
                <span className="mobile-section-icon-badge mobile-icon-badge--purple">
                  <CalendarIcon size={15} />
                </span>
                <span className="mobile-section-title">Select Date</span>
              </div>
            </div>
            <div className="mobile-date-picker-row">
              <div className="mobile-date-input-wrap w-full">
                <CalendarIcon size={15} className="mobile-input-prefix-icon text-purple-500" />
                <input
                  type="date"
                  className="mobile-form-input mobile-form-input--with-prefix"
                  value={apptDate}
                  onChange={(e) => setApptDate(e.target.value)}
                />
              </div>
            </div>
          </div>

          {/* 3. Available Time Slots */}
          <div className="mobile-form-section">
            <div className="mobile-section-header">
              <div className="mobile-section-title-wrap">
                <span className="mobile-section-icon-badge mobile-icon-badge--emerald">
                  <Clock size={15} />
                </span>
                <span className="mobile-section-title">Available Time</span>
              </div>
              <span className="mobile-interval-badge">
                <span className="mobile-interval-icon-badge">
                  <Timer size={10} strokeWidth={2.6} />
                </span>
                <span>{slotDuration}m intervals</span>
              </span>
            </div>

            <div className="mobile-time-slots-grid no-scrollbar">
              {timeSlots.map((slot) => {
                const isSel = isSlotSelected(slot);
                const isBooked = isSlotBookedForStaff(slot);
                return (
                  <button
                    key={slot}
                    type="button"
                    className={`mobile-time-slot-pill ${isSel
                      ? 'mobile-time-slot-pill--selected'
                      : isBooked
                        ? 'mobile-time-slot-pill--booked'
                        : ''
                      }`}
                    onClick={() => handleSelectSlot(slot)}
                  >
                    <span>{formatSlotLabel(slot, timeFormat)}</span>
                    {isBooked && !isSel && (
                      <span className="mobile-slot-booked-tag">Booked</span>
                    )}
                  </button>
                );
              })}
            </div>
          </div>

          {/* 4. Display Start Time & End Time (with Tap to Edit Mobile Clock) */}
          <div className="mobile-form-section mobile-selected-time-section">
            <div className="mobile-section-header">
              <div className="mobile-section-title-wrap">
                <span className="mobile-section-icon-badge mobile-icon-badge--amber">
                  <Timer size={15} />
                </span>
                <span className="mobile-section-title">Selected Time</span>
              </div>
              <span className="mobile-duration-pill mobile-duration-pill--amber">
                <Clock size={12} className="text-amber-600" />
                <span>{calculatedDuration || `${slotDuration}m duration`}</span>
              </span>
            </div>

            <div className="mobile-time-cards-grid">
              {/* Start Time Box */}
              <div
                className="mobile-time-card-neat mobile-time-card-neat--start"
                onClick={() => handleOpenTimePicker('start')}
                role="button"
                tabIndex={0}
              >
                <div className="mobile-time-card-top">
                  <span className="mobile-time-card-label flex items-center gap-1">
                    <Clock size={12} className="text-blue-500" />
                    <span>Start Time</span>
                  </span>
                  <span className="mobile-time-card-edit-chip mobile-edit-chip--blue">
                    <Edit3 size={11} />
                    <span>Edit</span>
                  </span>
                </div>
                <div className="mobile-time-card-bottom">
                  <span className="mobile-time-card-digits">
                    {formatSlotLabel(currentStart24, '12')}
                  </span>
                  <div className="mobile-time-card-icon-wrap mobile-time-icon--blue">
                    <Clock size={16} />
                  </div>
                </div>
              </div>

              {/* End Time Box */}
              <div
                className="mobile-time-card-neat mobile-time-card-neat--end"
                onClick={() => handleOpenTimePicker('end')}
                role="button"
                tabIndex={0}
              >
                <div className="mobile-time-card-top">
                  <span className="mobile-time-card-label flex items-center gap-1">
                    <Clock size={12} className="text-purple-500" />
                    <span>End Time</span>
                  </span>
                  <span className="mobile-time-card-edit-chip mobile-edit-chip--purple">
                    <Edit3 size={11} />
                    <span>Edit</span>
                  </span>
                </div>
                <div className="mobile-time-card-bottom">
                  <span className="mobile-time-card-digits">
                    {formatSlotLabel(currentEnd24, '12')}
                  </span>
                  <div className="mobile-time-card-icon-wrap mobile-time-icon--purple">
                    <Clock size={16} />
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* 5. Customer Selection & Validation */}
          <div className="mobile-form-section mobile-customer-section">
            <div className="mobile-section-header">
              <div className="mobile-section-title-wrap">
                <span className="mobile-section-icon-badge mobile-icon-badge--indigo">
                  <User size={15} />
                </span>
                <span className="mobile-section-title">Customer</span>
              </div>
              <div className="mobile-walkin-toggle">
                <button
                  type="button"
                  className={`mobile-toggle-btn ${!isWalkIn ? 'mobile-toggle-btn--active' : ''
                    }`}
                  onClick={() => {
                    setIsWalkIn(false);
                    setErrorBanner(null);
                  }}
                >
                  <Users size={12} />
                  <span>Existing</span>
                </button>
                <button
                  type="button"
                  className={`mobile-toggle-btn ${isWalkIn ? 'mobile-toggle-btn--active' : ''
                    }`}
                  onClick={() => {
                    setIsWalkIn(true);
                    setErrorBanner(null);
                  }}
                >
                  <UserPlus size={12} />
                  <span>Walk-In</span>
                </button>
              </div>
            </div>

            {isWalkIn ? (
              <div className="space-y-3">
                <div>
                  <label className="mobile-search-customer-label mb-1.5">
                    <span className="mobile-search-icon-badge">
                      <User size={12} strokeWidth={2.5} />
                    </span>
                    <span className="mobile-search-label-text">Customer Name</span>
                    <span className="mobile-search-required-star">*</span>
                  </label>
                  <input
                    type="text"
                    className="mobile-form-input"
                    placeholder="Enter walk-in customer name"
                    value={walkInName}
                    onChange={(e) => setWalkInName(e.target.value)}
                  />
                </div>
                <div>
                  <label className="mobile-search-customer-label mb-1.5">
                    <span className="mobile-search-icon-badge">
                      <Phone size={12} strokeWidth={2.5} />
                    </span>
                    <span className="mobile-search-label-text">Phone Number</span>
                    <span className="mobile-search-required-star">*</span>
                  </label>
                  <input
                    type="tel"
                    className="mobile-form-input"
                    placeholder="Enter walk-in phone number"
                    value={walkInPhone}
                    onChange={(e) => setWalkInPhone(e.target.value)}
                  />
                </div>
                {!isCustomerValid && (
                  <div className="mobile-validation-tip">
                    <AlertCircle size={13} className="shrink-0 text-amber-600" />
                    <span>Both Name and Phone are required to enable booking and adding services.</span>
                  </div>
                )}
                {isCustomerValid && (
                  <div className="mobile-cust-selected-chip">
                    <div className="mobile-cust-selected-avatar">
                      {walkInName.trim()[0].toUpperCase()}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-bold text-emerald-950 text-xs truncate">
                        {walkInName.trim()} (Walk-in)
                      </div>
                      <div className="text-[11px] text-emerald-700 font-medium flex items-center gap-1 mt-0.5">
                        <Phone size={11} className="shrink-0" />
                        <span>{walkInPhone.trim()}</span>
                      </div>
                    </div>
                    <Check size={16} className="text-emerald-600 shrink-0" />
                  </div>
                )}
              </div>
            ) : (
              <div className="mobile-cust-search-wrapper">
                <div className="flex items-center justify-between mb-2">
                  <label className="mobile-search-customer-label">
                    {/* <span className="mobile-search-icon-badge">
                      <Search size={12} strokeWidth={2.5} />
                    </span> */}
                    <span className="mobile-search-label-text">Search Customer</span>
                    <span className="mobile-search-required-star">*</span>
                  </label>
                  {customerSearch.trim().length > 0 && isSearchingCustomers && (
                    <span className="text-[11px] text-indigo-700 bg-indigo-50 border border-indigo-200 font-semibold px-2.5 py-0.5 rounded-full flex items-center gap-1.5 shadow-2xs">
                      <RefreshCw size={10} className="animate-spin text-indigo-600" />
                      <span>Searching...</span>
                    </span>
                  )}
                </div>

                <div className="mobile-cust-search-input-box">
                  <input
                    type="text"
                    className="mobile-form-input mobile-form-input--search"
                    placeholder="Search by customer name or phone..."
                    value={
                      selectedCustomer ? selectedCustomer.name : customerSearch
                    }
                    onChange={(e) => {
                      setSelectedCustomer(null);
                      setCustomerSearch(e.target.value);
                      setErrorBanner(null);
                    }}
                    autoComplete="off"
                  />
                  {customerSearch && (
                    <button
                      type="button"
                      className="mobile-input-clear-btn"
                      title="Clear search"
                      onMouseDown={(e) => e.preventDefault()}
                      onClick={() => {
                        setCustomerSearch('');
                        setSelectedCustomer(null);
                        setCustomerResults([]);
                      }}
                    >
                      <X size={13} />
                    </button>
                  )}
                </div>

                {/* Dropdown Results - ONLY display when letters are typed (customerSearch.trim().length > 0) */}
                {!selectedCustomer && customerSearch.trim().length > 0 && (
                  <div className="mobile-cust-dropdown-panel">
                    <div className="mobile-cust-dropdown-header">
                      <span className="flex items-center gap-1.5">
                        <Users size={12} className="text-indigo-600" />
                        <span>Matching Customers ({customerResults.length})</span>
                      </span>
                      {customerResults.length > 0 && (
                        <span className="text-[10px] font-semibold text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded-full border border-indigo-100">
                          Tap to select
                        </span>
                      )}
                    </div>
                    {isSearchingCustomers ? (
                      <div className="mobile-cust-item-empty">
                        <RefreshCw size={14} className="animate-spin text-indigo-600 inline mr-2" />
                        <span>Searching database for "{customerSearch.trim()}"...</span>
                      </div>
                    ) : customerResults.length === 0 ? (
                      <div className="mobile-cust-item-empty">
                        <span>No matching customers found for "{customerSearch.trim()}"</span>
                      </div>
                    ) : (
                      <>
                        <div className="mobile-cust-dropdown-list">
                          {customerResults.map((c) => (
                            <div
                              key={c.id}
                              className="mobile-cust-item"
                              onMouseDown={(e) => {
                                e.preventDefault();
                                setSelectedCustomer(c);
                                setCustomerSearch('');
                                setCustomerResults([]);
                              }}
                              onClick={() => {
                                setSelectedCustomer(c);
                                setCustomerSearch('');
                                setCustomerResults([]);
                              }}
                            >
                              <div className="mobile-cust-avatar">
                                {c.name ? c.name[0].toUpperCase() : 'C'}
                              </div>
                              <div className="mobile-cust-info">
                                <div className="mobile-cust-name">{c.name}</div>
                                <div className="mobile-cust-phone">
                                  <Phone size={11} className="text-slate-400" />
                                  <span>{c.phone ? c.phone : 'No phone number'}</span>
                                </div>
                              </div>
                            </div>
                          ))}
                        </div>
                        {customerResults.length > 5 && (
                          <div className="mobile-cust-dropdown-footer">
                            ↕ Scroll for more ({customerResults.length} customers found)
                          </div>
                        )}
                      </>
                    )}
                  </div>
                )}

                {selectedCustomer ? (
                  <div className="mobile-cust-selected-chip">
                    <div className="mobile-cust-selected-avatar">
                      {selectedCustomer.name ? selectedCustomer.name[0].toUpperCase() : 'C'}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-bold text-emerald-950 text-xs truncate">
                        {selectedCustomer.name}
                      </div>
                      <div className="text-[11px] text-emerald-700 font-medium flex items-center gap-1 mt-0.5">
                        <Phone size={11} className="shrink-0" />
                        <span>{selectedCustomer.phone || 'No phone provided'}</span>
                      </div>
                    </div>
                    <button
                      type="button"
                      className="mobile-cust-selected-remove"
                      title="Change Customer"
                      onClick={() => {
                        setSelectedCustomer(null);
                        setCustomerSearch('');
                        setCustomerResults([]);
                      }}
                    >
                      <X size={13} />
                      <span>Change</span>
                    </button>
                  </div>
                ) : !customerSearch.trim() ? (
                  <div className="mobile-validation-tip">
                    <AlertCircle size={13} className="shrink-0 text-slate-400" />
                    <span>Type customer name or phone above to search and select.</span>
                  </div>
                ) : null}
              </div>
            )}
          </div>

          {/* 6. Selected Services Section (Optional) */}
          <div className="mobile-form-section">
            <div className="mobile-section-header">
              <div className="mobile-section-title-wrap">
                <span className="mobile-section-icon-badge mobile-icon-badge--rose">
                  <Store size={15} />
                </span>
                <span className="mobile-section-title">
                  Services & Products ({selectedProducts.length})
                </span>
              </div>
              <span className="text-[11px] font-bold text-slate-500 bg-slate-100 px-2.5 py-0.5 rounded-full border border-slate-200">
                Optional
              </span>
            </div>

            {selectedProducts.length > 0 ? (
              <div className="mobile-selected-services-box">
                <div className="mobile-selected-services-list">
                  {selectedProducts.map((p) => (
                    <div key={p.id} className="mobile-selected-service-row">
                      <div className="flex items-center gap-2 min-w-0">
                        <Scissors size={13} className="text-rose-500 shrink-0" />
                        <span className="mobile-selected-service-name truncate">
                          {p.name}
                        </span>
                      </div>
                      <div className="flex items-center gap-2 shrink-0">
                        <span className="mobile-selected-service-price">
                          ${fmtMoney(p.price)}
                        </span>
                        <button
                          type="button"
                          className="mobile-service-remove-btn"
                          title="Remove service"
                          onClick={() =>
                            setSelectedProducts(
                              selectedProducts.filter((sp) => sp.id !== p.id)
                            )
                          }
                        >
                          <X size={14} />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
                <div className="mobile-selected-services-total">
                  <span className="flex items-center gap-1.5 text-slate-600 font-bold">
                    <Receipt size={13} className="text-rose-600" />
                    <span>Services Total:</span>
                  </span>
                  <span className="mobile-services-total-val">
                    ${fmtMoney(totalPrice)}
                  </span>
                </div>
              </div>
            ) : (
              <div className="mobile-no-services-prompt">
                <Store size={16} className="text-slate-400 mx-auto mb-1 block" />
                <span>
                  No service added (Optional). You can add a service (requires customer) or book directly.
                </span>
              </div>
            )}
          </div>

          {/* 7. Remarks / Notes (Optional) */}
          <div className="mobile-form-section">
            <div className="mobile-section-header">
              <div className="mobile-section-title-wrap">
                <span className="mobile-section-icon-badge mobile-icon-badge--cyan">
                  <Edit3 size={15} />
                </span>
                <span className="mobile-section-title">Remarks & Notes</span>
              </div>
              <span className="text-[11px] font-bold text-slate-500 bg-slate-100 px-2.5 py-0.5 rounded-full border border-slate-200">
                Optional
              </span>
            </div>
            <div className="mobile-input-with-icon-wrap">
              <FileText size={15} className="mobile-input-prefix-icon text-cyan-600" />
              <input
                type="text"
                className="mobile-form-input mobile-form-input--with-prefix"
                placeholder="Special instructions, requests, pet behavior..."
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
              />
            </div>
          </div>

          {/* Generic Error Banner if any */}
          {errorBanner && (
            <div className="mobile-conflict-alert">
              <AlertCircle size={15} className="shrink-0" />
              <span>{errorBanner}</span>
            </div>
          )}
        </div>

        {/* Fixed Mobile Bottom Action Bar (Positioned above bottom nav) */}
        <div className="mobile-booking-bottom-bar">
          {/* Staff / Time Conflict Validation Alert */}
          {localConflictMessage && (
            <div className="mobile-conflict-alert">
              <AlertCircle size={15} className="shrink-0" />
              <span>{localConflictMessage}</span>
            </div>
          )}

          <div className="mobile-booking-actions">
            {/* Add Service Button (Dynamically enabled/disabled based on customer validation) */}
            <button
              type="button"
              className={`mobile-btn-add-service ${!isCustomerValid ? 'mobile-btn-disabled' : ''
                }`}
              disabled={!isCustomerValid}
              onClick={() => {
                if (isCustomerValid) {
                  setMobileSubView('services');
                }
              }}
              title={
                !isCustomerValid
                  ? isWalkIn
                    ? 'Enter walk-in name and phone to add services'
                    : 'Select an existing customer to add services'
                  : 'Add services'
              }
            >
              <Plus size={16} />
              <span>
                {selectedProducts.length > 0
                  ? `Edit Services (${selectedProducts.length})`
                  : '+ Add Service'}
              </span>
            </button>

            {/* Book Appointment Button (Direct Booking) */}
            <button
              type="button"
              className={`mobile-btn-confirm-booking ${!isCustomerValid || Boolean(localConflictMessage) || isSubmitting
                ? 'mobile-btn-disabled'
                : ''
                }`}
              disabled={
                !isCustomerValid ||
                Boolean(localConflictMessage) ||
                isSubmitting
              }
              onClick={handleConfirmBooking}
            >
              <CheckCircle2 size={16} />
              <span>
                {isSubmitting
                  ? 'Booking...'
                  : totalPrice > 0
                    ? `Book Appointment ($${fmtMoney(totalPrice)})`
                    : 'Book Appointment'}
              </span>
            </button>
          </div>
        </div>

        {/* Mobile Clock Time Picker Modal Dialog */}
        {timePickerTarget && (
          <div
            className="mobile-time-picker-overlay"
            onClick={() => setTimePickerTarget(null)}
          >
            <div
              className="mobile-time-picker-dialog"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Header */}
              <div className="mobile-time-picker-header">
                <Clock size={18} className="text-rose-600" />
                <span className="mobile-time-picker-title">
                  Select {timePickerTarget === 'start' ? 'Start Time' : 'End Time'}
                </span>
                <button
                  type="button"
                  className="mobile-time-picker-close"
                  onClick={() => setTimePickerTarget(null)}
                  aria-label="Close"
                >
                  <X size={18} />
                </button>
              </div>

              {/* Scrollable Content Body */}
              <div className="mobile-time-picker-body no-scrollbar">
                {/* Large Digital Clock Display (Clickable Hour & Minute Boxes) */}
                <div className="mobile-time-picker-display">
                  <div className="mobile-time-picker-digits">
                    <div
                      className={`mobile-time-picker-num-box ${activeTimeTab === 'hour'
                        ? 'mobile-time-picker-num-box--active'
                        : ''
                        }`}
                      onClick={() => {
                        setActiveTimeTab('hour');
                        setPickerError(null);
                      }}
                      role="button"
                      tabIndex={0}
                      title="Click to select Hour"
                    >
                      <span className="mobile-time-picker-big-digit">
                        {String(pickerHour).padStart(2, '0')}
                      </span>
                      <span className="mobile-time-picker-sublabel">HOUR</span>
                    </div>
                    <span className="mobile-time-picker-separator">:</span>
                    <div
                      className={`mobile-time-picker-num-box ${activeTimeTab === 'minute'
                        ? 'mobile-time-picker-num-box--active'
                        : ''
                        }`}
                      onClick={() => {
                        setActiveTimeTab('minute');
                        setPickerError(null);
                      }}
                      role="button"
                      tabIndex={0}
                      title="Click to select Minute"
                    >
                      <span className="mobile-time-picker-big-digit">
                        {String(pickerMinute).padStart(2, '0')}
                      </span>
                      <span className="mobile-time-picker-sublabel">MIN</span>
                    </div>
                  </div>

                  {/* AM / PM Toggle */}
                  <div className="mobile-time-picker-ampm">
                    <button
                      type="button"
                      className={`mobile-time-ampm-btn ${pickerPeriod === 'AM' ? 'mobile-time-ampm-btn--active' : ''
                        }`}
                      onClick={() => {
                        setPickerPeriod('AM');
                        setPickerError(null);
                      }}
                    >
                      AM
                    </button>
                    <button
                      type="button"
                      className={`mobile-time-ampm-btn ${pickerPeriod === 'PM' ? 'mobile-time-ampm-btn--active' : ''
                        }`}
                      onClick={() => {
                        setPickerPeriod('PM');
                        setPickerError(null);
                      }}
                    >
                      PM
                    </button>
                  </div>
                </div>

                {/* 3 Switcher Tabs ('Both' on left side of Hours and Minutes) */}
                <div className="mobile-time-tabs-row mobile-time-tabs-row--three">
                  <button
                    type="button"
                    className={`mobile-time-tab-btn ${activeTimeTab === 'both' ? 'mobile-time-tab-btn--active' : ''
                      }`}
                    onClick={() => {
                      setActiveTimeTab('both');
                      setPickerError(null);
                    }}
                  >
                    <LayoutGrid size={13} />
                    <span>Both</span>
                  </button>
                  <button
                    type="button"
                    className={`mobile-time-tab-btn ${activeTimeTab === 'hour' ? 'mobile-time-tab-btn--active' : ''
                      }`}
                    onClick={() => {
                      setActiveTimeTab('hour');
                      setPickerError(null);
                    }}
                  >
                    <Clock size={13} />
                    <span>Hour ({pickerHour} {pickerPeriod})</span>
                  </button>
                  <button
                    type="button"
                    className={`mobile-time-tab-btn ${activeTimeTab === 'minute' ? 'mobile-time-tab-btn--active' : ''
                      }`}
                    onClick={() => {
                      setActiveTimeTab('minute');
                      setPickerError(null);
                    }}
                  >
                    <Timer size={13} />
                    <span>Minutes (:{String(pickerMinute).padStart(2, '0')})</span>
                  </button>
                </div>

                {/* VIEW 1: BOTH (Exactly matching user's uploaded image with both Hour & Minute grids) */}
                {activeTimeTab === 'both' && (
                  <div className="mobile-time-both-container space-y-3">
                    {/* SELECT HOUR */}
                    <div className="mobile-time-picker-section">
                      <span className="mobile-time-section-category">SELECT HOUR</span>
                      <div className="mobile-time-section-selected">
                        Selected: {pickerHour} {pickerPeriod}
                      </div>
                      <div className="mobile-time-hours-grid">
                        {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map((h) => {
                          const isSel = pickerHour === h;
                          return (
                            <button
                              key={h}
                              type="button"
                              className={`mobile-time-hour-chip ${isSel ? 'mobile-time-hour-chip--active' : ''
                                }`}
                              onClick={() => {
                                setPickerHour(h);
                                setPickerError(null);
                              }}
                            >
                              {h}
                            </button>
                          );
                        })}
                      </div>
                    </div>

                    {/* SELECT MINUTE (5-Minute Interval Chips exactly as in image: :00, :05, :10, :15, :20, :25, :30, :35, :40, :45, :50, :55) */}
                    <div className="mobile-time-picker-section">
                      <span className="mobile-time-section-category">SELECT MINUTE</span>
                      <div className="mobile-time-section-selected">
                        Selected: :{String(pickerMinute).padStart(2, '0')}
                      </div>
                      <div className="mobile-time-minutes-grid">
                        {[0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55].map((m) => {
                          const isSel = pickerMinute === m;
                          return (
                            <button
                              key={m}
                              type="button"
                              className={`mobile-time-minute-chip ${isSel ? 'mobile-time-minute-chip--active' : ''
                                }`}
                              onClick={() => {
                                setPickerMinute(m);
                                setPickerError(null);
                              }}
                            >
                              :{String(m).padStart(2, '0')}
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  </div>
                )}

                {/* VIEW 2: Hour Selection ONLY (1 to 12 Buttons Only) */}
                {activeTimeTab === 'hour' && (
                  <div className="mobile-time-picker-section">
                    <span className="mobile-time-section-category">SELECT HOUR</span>
                    <div className="mobile-time-section-selected">
                      Selected: {pickerHour} {pickerPeriod}
                    </div>
                    <div className="mobile-time-hours-grid">
                      {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map((h) => {
                        const isSel = pickerHour === h;
                        return (
                          <button
                            key={h}
                            type="button"
                            className={`mobile-time-hour-chip ${isSel ? 'mobile-time-hour-chip--active' : ''
                              }`}
                            onClick={() => {
                              setPickerHour(h);
                              setPickerError(null);
                            }}
                          >
                            {h}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}

                {/* VIEW 3: Minute Selection ONLY (Exact Minutes Buttons Only :00 to :59) */}
                {activeTimeTab === 'minute' && (
                  <div className="mobile-time-picker-section">
                    <span className="mobile-time-section-category">SELECT MINUTE</span>
                    <div className="mobile-time-section-selected">
                      Selected: :{String(pickerMinute).padStart(2, '0')}
                    </div>

                    {/* Exact Minutes Buttons Grid (All 60 Minutes :00 to :59) */}
                    <div className="mobile-time-exact-minutes-scrollable no-scrollbar">
                      <div className="mobile-time-minutes-grid">
                        {Array.from({ length: 60 }, (_, i) => i).map((m) => {
                          const isSel = pickerMinute === m;
                          return (
                            <button
                              key={m}
                              type="button"
                              className={`mobile-time-minute-chip ${isSel ? 'mobile-time-minute-chip--active' : ''
                                }`}
                              onClick={() => {
                                setPickerMinute(m);
                                setPickerError(null);
                              }}
                            >
                              :{String(m).padStart(2, '0')}
                            </button>
                          );
                        })}
                      </div>
                    </div>
                  </div>
                )}

                {/* Validation Error Message */}
                {pickerError && (
                  <div className="mobile-time-picker-error">
                    <AlertCircle size={14} className="shrink-0" />
                    <span>{pickerError}</span>
                  </div>
                )}
              </div>

              {/* Action Buttons: Cancel and Done */}
              <div className="mobile-time-picker-actions">
                <button
                  type="button"
                  className="mobile-time-picker-btn-cancel"
                  onClick={() => setTimePickerTarget(null)}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  className="mobile-time-picker-btn-done"
                  onClick={handleSaveTimePicker}
                >
                  Done
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  /* ── DESKTOP FLOW (> 768px): Completely Intact & Unchanged ─────────────── */
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
                            className={`appt-ampm-btn ${startPeriod === 'AM' ? 'appt-ampm-btn--active' : ''
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
                            className={`appt-ampm-btn ${startPeriod === 'PM' ? 'appt-ampm-btn--active' : ''
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
                            className={`appt-ampm-btn ${endPeriod === 'AM' ? 'appt-ampm-btn--active' : ''
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
                            className={`appt-ampm-btn ${endPeriod === 'PM' ? 'appt-ampm-btn--active' : ''
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
                  className={`appt-cat-chip ${selectedCategoryId === null ? 'appt-cat-chip--active' : ''
                    }`}
                  onClick={() => setSelectedCategoryId(null)}
                >
                  All
                </div>
                {allowedCategories.map((c) => (
                  <div
                    key={c.id}
                    className={`appt-cat-chip ${selectedCategoryId === c.id ? 'appt-cat-chip--active' : ''
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
                        className={`appt-product-row ${isSelected ? 'appt-product-row--selected' : ''
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
          {(errorBanner || localConflictMessage) && (
            <div className="appt-alert-banner">
              <AlertCircle size={16} />
              <span>{localConflictMessage || errorBanner}</span>
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
            disabled={isSubmitting || Boolean(localConflictMessage)}
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
  const isMobile = useIsMobile();
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

  /* ── MOBILE APPOINTMENT DETAILS VIEW (< 768px) ─────────────────────────── */
  if (isMobile) {
    return (
      <div
        className="appt-modal-overlay appt-modal-overlay--mobile-details"
        onClick={onClose}
      >
        <div
          className="appt-modal mobile-details-fullscreen-popup"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="mobile-details-header">
            <div className="flex items-center gap-2.5 min-w-0">
              <span className="mobile-section-icon-badge mobile-icon-badge--indigo shadow-2xs">
                <CalendarCheck size={16} />
              </span>
              <span className="mobile-details-header-title truncate">Appointment Details</span>
              <span
                className="shrink-0 text-[10.5px] font-extrabold uppercase px-2.5 py-0.5 rounded-full tracking-wider shadow-2xs"
                style={{
                  backgroundColor:
                    appt.status === 'booked'
                      ? '#eff6ff'
                      : appt.status === 'in_service'
                        ? '#fffbeb'
                        : appt.status === 'completed'
                          ? '#ecfdf5'
                          : appt.status === 'no_show'
                            ? '#fff1f2'
                            : '#f1f5f9',
                  color:
                    appt.status === 'booked'
                      ? '#1d4ed8'
                      : appt.status === 'in_service'
                        ? '#b45309'
                        : appt.status === 'completed'
                          ? '#047857'
                          : appt.status === 'no_show'
                            ? '#e11d48'
                            : '#475569',
                  border: `1px solid ${appt.status === 'booked'
                    ? '#bfdbfe'
                    : appt.status === 'in_service'
                      ? '#fde68a'
                      : appt.status === 'completed'
                        ? '#a7f3d0'
                        : appt.status === 'no_show'
                          ? '#fecdd3'
                          : '#cbd5e1'
                    }`,
                }}
              >
                {appt.status.replace('_', ' ')}
              </span>
            </div>
            <button
              type="button"
              className="mobile-details-close-btn"
              onClick={onClose}
              aria-label="Close"
            >
              <X size={18} />
            </button>
          </div>

          {/* Scrollable Body */}
          <div className="mobile-details-body no-scrollbar">
            {/* Section 1: Customer Card */}
            <div className="mobile-details-section">
              <div className="mobile-details-section-header">
                <span className="mobile-section-icon-badge mobile-icon-badge--blue">
                  <User size={14} />
                </span>
                <span>Customer</span>
              </div>
              <div className="mobile-details-card mobile-details-card--customer">
                <div className="mobile-details-cust-row">
                  <div className="mobile-details-cust-avatar">
                    {appt.customer_name ? appt.customer_name[0].toUpperCase() : 'G'}
                  </div>
                  <div className="mobile-details-cust-info">
                    <div className="mobile-details-cust-top">
                      <span className="mobile-details-cust-name">
                        {appt.customer_name || 'Walk-in Guest'}
                      </span>
                      <span className="mobile-details-cust-badge">
                        {appt.customer_id ? 'Registered' : 'Walk-in'}
                      </span>
                    </div>
                    {appt.customer_phone ? (
                      <a
                        href={`tel:${appt.customer_phone}`}
                        className="mobile-details-cust-phone"
                      >
                        <Phone size={11} />
                        <span>{appt.customer_phone}</span>
                      </a>
                    ) : (
                      <span className="mobile-details-cust-phone-empty">
                        No phone provided
                      </span>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Section 2: Appointment Schedule (Color-coded Stat Tiles) */}
            <div className="mobile-details-section">
              <div className="mobile-details-section-header">
                <span className="mobile-section-icon-badge mobile-icon-badge--purple">
                  <CalendarIcon size={14} />
                </span>
                <span>Appointment Schedule</span>
              </div>
              <div className="mobile-details-card">
                <div className="mobile-details-schedule-grid">
                  {/* Date */}
                  <div className="mobile-details-tile mobile-details-tile--purple">
                    <div className="mobile-details-tile-header">
                      <CalendarIcon size={13} />
                      <span>Date</span>
                    </div>
                    <div className="mobile-details-tile-value">
                      {appt.appointment_date}
                    </div>
                  </div>

                  {/* Staff Member */}
                  <div className="mobile-details-tile mobile-details-tile--blue">
                    <div className="mobile-details-tile-header">
                      <UserCheck size={13} />
                      <span>Staff Member</span>
                    </div>
                    <div className="mobile-details-tile-value">
                      {appt.staff_name || 'Unassigned'}
                    </div>
                  </div>

                  {/* Time Range */}
                  <div className="mobile-details-tile mobile-details-tile--amber">
                    <div className="mobile-details-tile-header">
                      <Clock size={13} />
                      <span>Time</span>
                    </div>
                    <div className="mobile-details-tile-value">
                      {formatApptTimeRange(appt.start_time, appt.end_time, timeFormat)}
                    </div>
                  </div>

                  {/* Duration */}
                  <div className="mobile-details-tile mobile-details-tile--emerald">
                    <div className="mobile-details-tile-header">
                      <Timer size={13} />
                      <span>Duration</span>
                    </div>
                    <div className="mobile-details-tile-value">
                      {currentDurationM} mins
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Section 3: Services & Products */}
            <div className="mobile-details-section">
              <div className="mobile-details-section-header">
                <span className="mobile-section-icon-badge mobile-icon-badge--rose">
                  <Store size={14} />
                </span>
                <span>
                  Services & Products{' '}
                  {appt.services && appt.services.length > 0
                    ? `(${appt.services.length})`
                    : ''}
                </span>
              </div>
              <div className="mobile-details-card">
                {appt.services && appt.services.length > 0 ? (
                  <div className="mobile-details-services-list">
                    {appt.services.map((sv, idx) => (
                      <div key={idx} className="mobile-details-service-row">
                        <div className="mobile-details-service-left">
                          <span className="mobile-details-service-icon">
                            <Scissors size={12} />
                          </span>
                          <span className="mobile-details-service-name">
                            {sv.name || sv.product_name || 'Service Item'}
                          </span>
                          {sv.quantity && sv.quantity > 1 && (
                            <span className="mobile-details-service-qty">
                              ×{sv.quantity}
                            </span>
                          )}
                        </div>
                        {sv.price !== undefined && (
                          <span className="mobile-details-service-price">
                            ${fmtMoney(sv.price)}
                          </span>
                        )}
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="mobile-details-service-empty">
                    <Store size={14} />
                    <span>No extra services attached</span>
                  </div>
                )}

                {/* Total Amount Banner */}
                {appt.total_amount && parseFloat(String(appt.total_amount)) > 0 && (
                  <div className="mobile-details-total-box">
                    <span className="mobile-details-total-label">
                      <Receipt size={14} />
                      <span>Total Amount:</span>
                    </span>
                    <span className="mobile-details-total-val">
                      ${fmtMoney(appt.total_amount)}
                    </span>
                  </div>
                )}
              </div>
            </div>

            {/* Section 4: Remarks / Special Instructions */}
            {appt.notes && (
              <div className="mobile-details-section">
                <div className="mobile-details-section-header">
                  <span className="mobile-section-icon-badge mobile-icon-badge--amber">
                    <Edit3 size={14} />
                  </span>
                  <span>Remarks & Instructions</span>
                </div>
                <div className="mobile-details-notes-box">
                  <FileText size={16} style={{ color: '#d97706', flexShrink: 0, marginTop: '2px' }} />
                  <p className="mobile-details-notes-text">
                    "{appt.notes}"
                  </p>
                </div>
              </div>
            )}

            {/* Section 5: Extend Duration */}
            {(appt.status === 'booked' || appt.status === 'in_service') && (
              <div className="mobile-details-section">
                <div className="mobile-details-extend-header">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <span className="mobile-section-icon-badge mobile-icon-badge--cyan">
                      <Timer size={14} />
                    </span>
                    <span style={{ fontSize: '13px', fontWeight: 800, color: '#0f172a' }}>Extend Duration</span>
                  </div>
                  <span style={{ fontSize: '11px', color: '#0e7490', backgroundColor: '#ecfeff', border: '1px solid #a5f3fc', fontWeight: 700, padding: '2px 8px', borderRadius: '9999px' }}>
                    Current: {currentDurationM}m
                  </span>
                </div>
                <div className="mobile-details-card">
                  <div className="mobile-details-extend-tip">
                    <Clock size={12} style={{ color: '#0891b2' }} />
                    <span>Quickly add time to this appointment:</span>
                  </div>
                  <div className="mobile-details-extend-grid">
                    {[15, 30, 45, 60].map((m) => (
                      <button
                        key={m}
                        type="button"
                        className="mobile-details-extend-btn"
                        disabled={isExtending}
                        onClick={() => handleExtendDuration(m)}
                      >
                        <span className="mobile-details-extend-num">+{m}</span>
                        <span className="mobile-details-extend-sub">min</span>
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            )}

            {/* Section 6: Appointment Actions */}
            <div className="mobile-details-section">
              <div className="mobile-details-section-header">
                <span className="mobile-section-icon-badge mobile-icon-badge--emerald">
                  <CheckCircle2 size={14} />
                </span>
                <span>Appointment Actions</span>
              </div>
              <div className="mobile-details-actions-list">
                {appt.status === 'booked' && (
                  <button
                    type="button"
                    className="mobile-details-btn-primary"
                    onClick={async () => {
                      await onStatusChange('in_service');
                      onStartService();
                    }}
                  >
                    <Play size={16} fill="white" />
                    <span>Start Service Now</span>
                  </button>
                )}

                <div className="mobile-details-actions-grid">
                  <button
                    type="button"
                    className="mobile-details-action-btn mobile-details-action-btn--reschedule"
                    onClick={onOpenReschedule}
                  >
                    <CalendarCheck size={14} />
                    <span>Reschedule</span>
                  </button>

                  {appt.status !== 'no_show' && (
                    <button
                      type="button"
                      className="mobile-details-action-btn mobile-details-action-btn--noshow"
                      onClick={() => onStatusChange('no_show')}
                    >
                      <UserX size={14} />
                      <span>No Show</span>
                    </button>
                  )}

                  {appt.status !== 'cancelled' && (
                    <button
                      type="button"
                      className="mobile-details-action-btn mobile-details-action-btn--cancel"
                      onClick={() => onStatusChange('cancelled')}
                    >
                      <CalendarX size={14} />
                      <span>Cancel</span>
                    </button>
                  )}

                  {allowDeleteService && (
                    <button
                      type="button"
                      className="mobile-details-action-btn mobile-details-action-btn--delete"
                      onClick={onDeleteClick}
                    >
                      <Trash2 size={14} />
                      <span>Delete</span>
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  /* ── DESKTOP APPOINTMENT DETAILS VIEW (> 768px): Intact ────────────────── */
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

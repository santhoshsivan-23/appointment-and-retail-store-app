import { useState, useEffect, useCallback, useMemo } from 'react';
import { toast } from 'react-toastify';
import {
  Users,
  Calendar as CalendarIcon,
  CalendarDays,
  CalendarCheck2,
  Clock,
  RefreshCw,
  Search,
  ChevronRight,
  User,
  Phone,
  AlertCircle,
  CheckCircle2,
  X,
  Play,
  Trash2,
  Check,
  Briefcase,
  FileText,
  Tag,
  CreditCard,
  Scissors,
  UserX,
  XCircle,
  ArrowRight,
} from 'lucide-react';
import { useAppSelector } from '../store/hooks';
import {
  appointmentApi,
  type Appointment,
  type AppointmentStatus,
} from '../api/appointmentApi';
import { staffApi, type Staff } from '../api/staffApi';
import { customerApi, type Customer } from '../api/customerApi';
import { productApi, type Product } from '../api/productApi';
import {
  timeToMinutes,
  minutesToTime24,
  formatTime12,
  formatTimeSlotLabel,
  getTodayDateStr,
  formatDatePretty,
  generateBusinessSlots,
  checkClientOverlap,
  getStatusMeta,
  type BusinessSlot,
} from '../utils/appointmentV2Utils';
import WheelTimePicker from '../components/WheelTimePicker';
import ClockTimePickerModal from '../components/ClockTimePickerModal';
import AppointmentV2Header from '../components/AppointmentV2Header';
import AppointmentV2Calender from '../components/AppointmentV2Calender';
import AppointmentV2LayoutData from '../components/AppointmentV2LayoutData';
import '../styles/appointment_v2.css';

/* ── Props ───────────────────────────────────────────────────────────────── */
interface AppointmentV2ViewProps {
  onStartService?: (
    customer: any,
    products: any[],
    appointment: any
  ) => void;
}

type V2ViewMode = 'list' | 'grid' | 'time';

const STAFF_BG_COLORS = [
  '#2563eb',
  '#7c3aed',
  '#db2777',
  '#ea580c',
  '#059669',
  '#0891b2',
  '#4f46e5',
  '#d97706',
];

export default function AppointmentV2View({ onStartService }: AppointmentV2ViewProps) {
  const config = useAppSelector((state) => state.appointmentConfig);
  const openTime = config.openTime || '08:00';
  const closeTime = config.closeTime || '20:00';
  const timeFormat = config.timeFormat || '12';
  const appointmentV2Clock =
    config.appointmentV2Clock !== undefined
      ? config.appointmentV2Clock
      : localStorage.getItem('appointment_v2_clock') !== 'false';

  /* ── Core State ────────────────────────────────────────────────────────── */
  const [staffList, setStaffList] = useState<Staff[]>([]);
  const [isLoadingStaff, setIsLoadingStaff] = useState<boolean>(true);
  const [selectedStaff, setSelectedStaff] = useState<Staff | null>(null);
  const [staffSearchQuery, setStaffSearchQuery] = useState<string>('');

  // Selected Date (default: today)
  const [selectedDate, setSelectedDate] = useState<string>(getTodayDateStr());

  // View Mode: 'list' (default), 'grid', 'time'
  const [viewMode, setViewMode] = useState<V2ViewMode>('list');

  // Appointments for the selected staff and selected date
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [isLoadingAppts, setIsLoadingAppts] = useState<boolean>(false);

  // Unified expanded appointment ID for smooth expand/collapse across List, Time, and Grid layouts
  const [expandedApptId, setExpandedApptId] = useState<number | null>(null);

  // Real-time clock minutes for live indicator in Time View
  const [nowMinutes, setNowMinutes] = useState<number>(() => {
    const now = new Date();
    return now.getHours() * 60 + now.getMinutes();
  });

  useEffect(() => {
    const timer = setInterval(() => {
      const now = new Date();
      setNowMinutes(now.getHours() * 60 + now.getMinutes());
    }, 30000);
    return () => clearInterval(timer);
  }, []);

  // Time Slot Filter Modal
  const [showFilterModal, setShowFilterModal] = useState<boolean>(false);
  const [filterSlotStatus, setFilterSlotStatus] = useState<'all' | 'available' | 'booked'>('all');

  // Add Appointment Modal
  const [showAddModal, setShowAddModal] = useState<boolean>(false);
  const [prefilledAddSlot, setPrefilledAddSlot] = useState<{ start24: string; end24: string } | null>(null);
  const [prefilledAddCustomer, setPrefilledAddCustomer] = useState<Customer | null>(null);


  // Details Modal
  const [selectedDetailsAppt, setSelectedDetailsAppt] = useState<Appointment | null>(null);

  // Calendar Navigator Month (for right calendar widget)
  const [calendarViewDate, setCalendarViewDate] = useState<Date>(() => new Date());

  // Track failed staff images so fallback initials are displayed cleanly without conflict
  const [failedStaffImageIds, setFailedStaffImageIds] = useState<Set<number>>(new Set());

  /* ── 1. Fetch Staff List ───────────────────────────────────────────────── */
  const fetchStaff = useCallback(async () => {
    setIsLoadingStaff(true);
    try {
      const res = await staffApi.getAll(false);
      if (res.data?.data) {
        setStaffList(res.data.data);
      }
    } catch (err) {
      console.error('Failed to fetch staff list:', err);
      toast.error('Could not load staff directory.');
    } finally {
      setIsLoadingStaff(false);
    }
  }, []);

  useEffect(() => {
    fetchStaff();
  }, [fetchStaff]);

  /* ── 2. Fetch Appointments for Selected Staff & Date ───────────────────── */
  const fetchAppointments = useCallback(async () => {
    if (!selectedStaff) return;
    setIsLoadingAppts(true);
    try {
      const res = await appointmentApi.getAppointments({
        staff_id: selectedStaff.id,
        date: selectedDate,
      });
      if (res.data?.data) {
        // Sort chronologically by start_time
        const sorted = [...res.data.data].sort((a, b) =>
          (a.start_time || '').localeCompare(b.start_time || '')
        );
        setAppointments(sorted);
      }
    } catch (err) {
      console.error('Failed to load appointments:', err);
      toast.error('Failed to load appointments.');
    } finally {
      setIsLoadingAppts(false);
    }
  }, [selectedStaff, selectedDate]);

  useEffect(() => {
    if (selectedStaff) {
      fetchAppointments();
    }
  }, [selectedStaff, selectedDate, fetchAppointments]);

  /* ── Business Slots Generation ─────────────────────────────────────────── */
  const businessSlots: BusinessSlot[] = useMemo(() => {
    return generateBusinessSlots(openTime, closeTime, 30);
  }, [openTime, closeTime]);

  /* ── Helper: Map Appointments to Slots ─────────────────────────────────── */
  const slotAppointmentMap = useMemo(() => {
    const map = new Map<string, Appointment[]>();
    businessSlots.forEach((slot) => {
      const slotStart = timeToMinutes(slot.start24);
      const slotEnd = timeToMinutes(slot.end24);

      const matching = appointments.filter((appt) => {
        const apptStart = timeToMinutes(appt.start_time);
        const apptEnd = timeToMinutes(appt.end_time);
        // An appointment occupies this slot if there is an overlap
        return apptStart < slotEnd && slotStart < apptEnd;
      });

      map.set(slot.start24, matching);
    });
    return map;
  }, [businessSlots, appointments]);

  /* ── Quick Stats for Selected Staff & Date ─────────────────────────────── */
  const dayStats = useMemo(() => {
    let booked = 0;
    let inService = 0;
    let completed = 0;
    let noShow = 0;
    let cancelled = 0;

    appointments.forEach((a) => {
      const st = (a.status || '').toLowerCase();
      if (st === 'booked') booked++;
      else if (st === 'in_service' || st === 'inservice') inService++;
      else if (st === 'completed') completed++;
      else if (st === 'no_show' || st === 'noshow') noShow++;
      else if (st === 'cancelled' || st === 'canceled') cancelled++;
    });

    return {
      total: appointments.length,
      booked,
      inService,
      completed,
      noShow,
      cancelled,
    };
  }, [appointments]);

  /* ── Status Actions ────────────────────────────────────────────────────── */
  const handleUpdateStatus = async (apptId: number, newStatus: AppointmentStatus) => {
    // 1. Immediate optimistic UI update
    setAppointments((prev) =>
      prev.map((a) => (a.id === apptId ? { ...a, status: newStatus } : a))
    );
    if (selectedDetailsAppt && selectedDetailsAppt.id === apptId) {
      setSelectedDetailsAppt((prev) => (prev ? { ...prev, status: newStatus } : null));
    }

    try {
      await appointmentApi.updateStatus(apptId, newStatus);
      const label =
        newStatus === 'in_service'
          ? 'In Service'
          : newStatus === 'no_show'
          ? 'No Show'
          : newStatus === 'completed'
          ? 'Completed'
          : newStatus.charAt(0).toUpperCase() + newStatus.slice(1);
      toast.success(`Appointment marked as ${label}`);

      // Silent sync with backend
      if (selectedStaff) {
        const res = await appointmentApi.getAppointments({
          staff_id: selectedStaff.id,
          date: selectedDate,
        });
        if (res.data?.data) {
          const sorted = [...res.data.data].sort((a, b) =>
            (a.start_time || '').localeCompare(b.start_time || '')
          );
          setAppointments(sorted);
        }
      }
    } catch (err) {
      console.error('Failed to update status:', err);
      toast.error('Failed to update status.');
      fetchAppointments();
    }
  };

  const handleDeleteAppt = async (apptId: number) => {
    if (!window.confirm('Are you sure you want to delete this appointment?')) return;
    try {
      await appointmentApi.delete(apptId);
      toast.success('Appointment deleted successfully.');
      fetchAppointments();
      if (selectedDetailsAppt && selectedDetailsAppt.id === apptId) {
        setSelectedDetailsAppt(null);
      }
    } catch {
      toast.error('Failed to delete appointment.');
    }
  };

  const navigateToCart = (appt: Appointment) => {
    if (!onStartService) {
      toast.info('POS Cart connection ready');
      return;
    }

    const customerObj = {
      id: appt.customer_id || 0,
      name: appt.customer_name || 'Walk-in Customer',
      phone: appt.customer_phone || '',
    };

    const productsList: any[] = [];
    if (appt.services && appt.services.length > 0) {
      appt.services.forEach((s) => {
        const pid = s.product_id || s.id || Math.floor(Math.random() * 900000) + 10000;
        const price = typeof s.price === 'number' ? s.price : parseFloat(String(s.price || 0)) || 0;
        const sName = s.name || s.product_name || 'Service';
        const qty = s.quantity && s.quantity > 0 ? s.quantity : 1;
        for (let i = 0; i < qty; i++) {
          productsList.push({
            id: pid,
            name: sName,
            price: price,
            quantity: 1,
          });
        }
      });
    } else {
      const total = Number(appt.total_amount || 0);
      productsList.push({
        id: Math.floor(Math.random() * 900000) + 10000,
        name: 'General Service',
        price: total,
        quantity: 1,
      });
    }

    onStartService(customerObj, productsList, appt);
  };

  const handleStartServiceClick = async (appt: Appointment) => {
    await handleUpdateStatus(appt.id, 'in_service');
    navigateToCart({ ...appt, status: 'in_service' });
  };

  const handleContinueServiceClick = (appt: Appointment) => {
    navigateToCart(appt);
  };

  /* ========================================================================
     SCREEN 1: INITIAL STAFF SELECTION SCREEN
     ======================================================================== */
  if (!selectedStaff) {
    const filteredStaff = staffList.filter((s) => {
      const q = staffSearchQuery.toLowerCase().trim();
      return (
        s.name.toLowerCase().includes(q) ||
        (s.role && s.role.toLowerCase().includes(q)) ||
        (s.phone && s.phone.toLowerCase().includes(q))
      );
    });

    return (
      <div className="appointment-v2-container appointment-v2-screen h-full max-h-full w-full flex flex-col bg-[#F8FAF9] text-gray-800 antialiased overflow-hidden">
        <div className="v2-staff-screen w-full h-full flex flex-col overflow-y-auto v2-custom-scroll">
          {/* Header Card Banner utilizing full available width */}
          <div className="v2-staff-header-card">
            <div className="v2-staff-header-left">
              <div className="v2-staff-header-badge-row">
                <span className="v2-staff-badge">
                  <Users size={13} />
                  <span>Appointment V2</span>
                </span>
                <span className="v2-staff-count-chip">
                  {filteredStaff.length} {filteredStaff.length === 1 ? 'Specialist' : 'Specialists'}
                </span>
              </div>
              <h1 className="v2-staff-title">Select Staff Member</h1>
              <p className="v2-staff-subtitle">
                Choose a specialist to view today's schedule, navigate available time slots, and manage appointments in V2 view.
              </p>
            </div>

            <div className="v2-staff-header-right">
              <div className="v2-staff-search-box">
                <Search size={16} className="v2-staff-search-icon" />
                <input
                  type="text"
                  className="v2-staff-search-input"
                  placeholder="Search staff by name, role, phone..."
                  value={staffSearchQuery}
                  onChange={(e) => setStaffSearchQuery(e.target.value)}
                />
                {staffSearchQuery && (
                  <button
                    type="button"
                    className="v2-staff-search-clear"
                    title="Clear search"
                    onClick={() => setStaffSearchQuery('')}
                  >
                    <X size={14} />
                  </button>
                )}
              </div>
            </div>
          </div>

          {isLoadingStaff ? (
            <div className="v2-loading-screen flex-1 flex flex-col items-center justify-center p-12">
              <div className="v2-spinner mb-3" />
              <span className="text-sm font-medium text-slate-500">Loading staff roster...</span>
            </div>
          ) : filteredStaff.length === 0 ? (
            <div className="v2-staff-empty-state">
              <div className="v2-staff-empty-icon">
                <Users size={28} />
              </div>
              <h3 className="v2-staff-empty-title">No Staff Found</h3>
              <p className="v2-staff-empty-desc">
                {staffSearchQuery
                  ? `No staff members matched "${staffSearchQuery}".`
                  : 'No active staff members are registered in the terminal.'}
              </p>
              {staffSearchQuery && (
                <button
                  type="button"
                  className="v2-staff-empty-btn"
                  onClick={() => setStaffSearchQuery('')}
                >
                  Clear Search Filter
                </button>
              )}
            </div>
          ) : (
            <div className="v2-staff-grid">
              {filteredStaff.map((staff, idx) => {
                const bg = staff.color_code || STAFF_BG_COLORS[idx % STAFF_BG_COLORS.length];
                const initials = staff.name
                  .split(' ')
                  .map((n) => n[0])
                  .slice(0, 2)
                  .join('')
                  .toUpperCase();
                const isActive = staff.is_active === 1 || staff.is_active === true || staff.is_active === undefined;

                const hasImage = Boolean(
                  staff.image &&
                  staff.image.trim().length > 0 &&
                  !failedStaffImageIds.has(staff.id)
                );

                return (
                  <div
                    key={staff.id}
                    className="v2-staff-card"
                    onClick={() => {
                      setSelectedStaff(staff);
                      setSelectedDate(getTodayDateStr());
                      setExpandedApptId(null);
                    }}
                  >
                    <div className="v2-staff-card__top">
                      <div className="v2-staff-avatar" style={{ backgroundColor: bg }}>
                        {hasImage ? (
                          <img
                            src={staff.image!}
                            alt={staff.name}
                            className="v2-staff-avatar-img"
                            onError={() => {
                              setFailedStaffImageIds((prev) => new Set(prev).add(staff.id));
                            }}
                          />
                        ) : (
                          <span className="v2-staff-avatar-fallback">
                            {initials}
                          </span>
                        )}
                      </div>
                      <span
                        className={`v2-staff-status-badge ${isActive ? 'v2-staff-status-badge--active' : ''
                          }`}
                      >
                        <span className="v2-staff-status-dot" />
                        <span>{isActive ? 'Active' : 'Offline'}</span>
                      </span>
                    </div>

                    <div className="v2-staff-card__body">
                      <h3 className="v2-staff-card__name" title={staff.name}>
                        {staff.name}
                      </h3>
                      <p className="v2-staff-card__role" title={staff.role || 'Service Specialist'}>
                        <Briefcase size={13} className="text-emerald-600 flex-shrink-0" />
                        <span>{staff.role || 'Service Specialist'}</span>
                      </p>
                      {staff.phone && (
                        <p className="v2-staff-card__contact" title={staff.phone}>
                          <Phone size={12} className="text-slate-400 flex-shrink-0" />
                          <span>{staff.phone}</span>
                        </p>
                      )}
                    </div>

                    <div className="v2-staff-card__footer">
                      <span className="v2-staff-card__cta-text">View Appointments</span>
                      <span className="v2-staff-card__cta-icon">
                        <ChevronRight size={15} />
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    );
  }

  /* ========================================================================
     SCREEN 2: APPOINTMENT V2 MAIN LAYOUT
     ======================================================================== */
  const staffBg =
    STAFF_BG_COLORS[
    staffList.findIndex((s) => s.id === selectedStaff.id) %
    STAFF_BG_COLORS.length
    ] || '#0284c7';
  const staffInitials = selectedStaff.name
    .split(' ')
    .map((n) => n[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();

  return (
    <div
      className="appointment-v2-container appointment-v2-screen h-full max-h-full w-full flex flex-col bg-[#F8FAF9] text-gray-800 antialiased selection:bg-emerald-100 selection:text-emerald-900 overflow-hidden"
      data-purpose="appointment-v2-screen"
    >
      {/* BEGIN: MainContainer */}
      <div className="appointment-v2-inner-wrap w-full max-w-[1536px] mx-auto px-4 sm:px-6 lg:px-8 pt-3 pb-2 flex flex-col h-full flex-1 min-h-0 overflow-hidden">
        {/* SECTION 1: Top Header (Permanently Fixed in Top) */}
        <AppointmentV2Header
          selectedStaff={selectedStaff}
          staffBg={staffBg}
          staffInitials={staffInitials}
          selectedDate={selectedDate}
          viewMode={viewMode}
          isLoadingAppts={isLoadingAppts}
          onSwitchStaff={() => setSelectedStaff(null)}
          onViewModeChange={setViewMode}
          onOpenFilterModal={() => setShowFilterModal(true)}
          onRefresh={fetchAppointments}
          onOpenAddModal={() => {
            setPrefilledAddSlot(null);
            setPrefilledAddCustomer(null);
            setShowAddModal(true);
          }}
          onSelectCustomerToBook={(cust) => {
            setPrefilledAddCustomer(cust);
            setPrefilledAddSlot(null);
            setShowAddModal(true);
          }}
        />

        {/* BEGIN: DashboardBody with 2 Independently Scrollable Columns */}
        <main className="appointment-v2-columns-row flex-1 min-h-0 overflow-hidden items-stretch">
          {/* SECTION 2: Left Section (Appointment Data - Independently Scrollable) */}
          <AppointmentV2LayoutData
            isLoadingAppts={isLoadingAppts}
            viewMode={viewMode}
            selectedStaff={selectedStaff}
            selectedDate={selectedDate}
            appointments={appointments}
            businessSlots={businessSlots}
            slotAppointmentMap={slotAppointmentMap}
            expandedApptId={expandedApptId}
            onToggleExpandAppt={(id) => setExpandedApptId(expandedApptId === id ? null : id)}
            timeFormat={timeFormat}
            nowMinutes={nowMinutes}
            onStartServiceClick={handleStartServiceClick}
            onContinueServiceClick={handleContinueServiceClick}
            onOpenDetailsModal={(appt) => setSelectedDetailsAppt(appt)}
            onOpenAddModal={(slot) => {
              setPrefilledAddSlot(slot || null);
              setPrefilledAddCustomer(null);
              setShowAddModal(true);
            }}
            onSelectToday={() => {
              setSelectedDate(getTodayDateStr());
              setCalendarViewDate(new Date());
              setExpandedApptId(null);
            }}
          />

          {/* SECTION 3: Right Section (Calendar and Status Section - Independently Scrollable) */}
          <AppointmentV2Calender
            selectedStaff={selectedStaff}
            staffBg={staffBg}
            staffInitials={staffInitials}
            selectedDate={selectedDate}
            calendarViewDate={calendarViewDate}
            appointments={appointments}
            dayStats={dayStats}
            onSelectDate={(dateStr) => {
              setSelectedDate(dateStr);
              setExpandedApptId(null);
            }}
            onChangeCalendarMonth={setCalendarViewDate}
            onSwitchStaff={() => setSelectedStaff(null)}
          />
        </main>
        {/* END: DashboardBody */}
      </div>
      {/* END: MainContainer */}

      {/* ====================================================================
          MODAL 1: ADD APPOINTMENT (DATE + SCROLLABLE START/END TIME + CONFLICT)
          ==================================================================== */}
      {showAddModal && (
        <AddAppointmentV2Modal
          staff={selectedStaff}
          defaultDate={selectedDate}
          prefilledSlot={prefilledAddSlot}
          preselectedCustomer={prefilledAddCustomer}
          openTime={openTime}
          closeTime={closeTime}
          timeFormat={timeFormat}
          appointmentV2Clock={appointmentV2Clock}
          existingAppointments={appointments}
          onClose={() => {
            setShowAddModal(false);
            setPrefilledAddSlot(null);
            setPrefilledAddCustomer(null);
          }}
          onSuccess={() => {
            setShowAddModal(false);
            setPrefilledAddSlot(null);
            setPrefilledAddCustomer(null);
            fetchAppointments();
          }}
        />
      )}

      {/* ====================================================================
          MODAL 2: 30-MINUTE TIME SLOT FILTER
          ==================================================================== */}
      {showFilterModal && (
        <TimeSlotFilterModal
          slots={businessSlots}
          slotAppointmentMap={slotAppointmentMap}
          filterStatus={filterSlotStatus}
          onFilterChange={setFilterSlotStatus}
          onSelectSlot={(start24) => {
            setShowFilterModal(false);
            setViewMode('time');
            const appts = slotAppointmentMap.get(start24) || [];
            if (appts[0]) {
              setExpandedApptId(appts[0].id);
            }
            const el = document.getElementById(`v2-slot-${start24}`);
            if (el) {
              el.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
          }}
          onClose={() => setShowFilterModal(false)}
        />
      )}

      {/* ====================================================================
          MODAL 3: FULL APPOINTMENT DETAILS & ACTIONS
          ==================================================================== */}
      {selectedDetailsAppt && (
        <AppointmentDetailsV2Modal
          appt={selectedDetailsAppt}
          timeFormat={timeFormat}
          onClose={() => setSelectedDetailsAppt(null)}
          onStartService={() => {
            const cur = selectedDetailsAppt;
            setSelectedDetailsAppt(null);
            handleStartServiceClick(cur);
          }}
          onContinueService={() => {
            const cur = selectedDetailsAppt;
            setSelectedDetailsAppt(null);
            handleContinueServiceClick(cur);
          }}
          onStatusChange={(newStatus) => {
            handleUpdateStatus(selectedDetailsAppt.id, newStatus);
          }}
          onDelete={() => {
            handleDeleteAppt(selectedDetailsAppt.id);
          }}
        />
      )}
    </div>
  );
}

/* ==========================================================================
   SUB-COMPONENT: ADD APPOINTMENT V2 MODAL
   ========================================================================== */
interface AddAppointmentV2ModalProps {
  staff: Staff;
  defaultDate: string;
  prefilledSlot?: { start24: string; end24: string } | null;
  preselectedCustomer?: Customer | null;
  openTime: string;
  closeTime: string;
  timeFormat: '12' | '24';
  appointmentV2Clock?: boolean;
  existingAppointments: Appointment[];
  onClose: () => void;
  onSuccess: () => void;
}

function AddAppointmentV2Modal({
  staff,
  defaultDate,
  prefilledSlot,
  preselectedCustomer,
  openTime,
  closeTime,
  timeFormat,
  appointmentV2Clock = true,
  existingAppointments,
  onClose,
  onSuccess,
}: AddAppointmentV2ModalProps) {
  // Step 1: Date Selection
  const [apptDate, setApptDate] = useState<string>(defaultDate);

  // Step 2: Time Selection
  const defaultStart = prefilledSlot?.start24 || openTime || '08:00';
  const defaultEnd =
    prefilledSlot?.end24 ||
    minutesToTime24(timeToMinutes(defaultStart) + 30);

  const [startTime, setStartTime] = useState<string>(defaultStart);
  const [endTime, setEndTime] = useState<string>(defaultEnd);
  const [clockPickerTarget, setClockPickerTarget] = useState<'start' | 'end' | null>(null);

  // Customer Selection State (NO INITIAL FULL LIST CALL)
  const [isWalkIn, setIsWalkIn] = useState<boolean>(!preselectedCustomer);
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(
    preselectedCustomer || null
  );
  const [customerSearch, setCustomerSearch] = useState<string>('');
  const [customerResults, setCustomerResults] = useState<Customer[]>([]);
  const [isSearchingCustomers, setIsSearchingCustomers] = useState<boolean>(false);
  const [walkInName, setWalkInName] = useState<string>('');
  const [walkInPhone, setWalkInPhone] = useState<string>('');

  // Service Selection State (NO INITIAL FULL LIST CALL)
  const [serviceSearch, setServiceSearch] = useState<string>('');
  const [serviceResults, setServiceResults] = useState<Product[]>([]);
  const [isSearchingServices, setIsSearchingServices] = useState<boolean>(false);
  const [selectedServices, setSelectedServices] = useState<Product[]>([]);

  // Notes & Validation Error
  const [notes, setNotes] = useState<string>('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);

  // Customer Search: Call API only when user enters search term
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

    setIsSearchingCustomers(true);
    const timer = setTimeout(async () => {
      try {
        const res = await customerApi.getAll(q);
        const list = Array.isArray(res.data) ? res.data : res.data?.data || [];
        setCustomerResults(list);
      } catch (err) {
        console.error('Customer search error:', err);
        setCustomerResults([]);
      } finally {
        setIsSearchingCustomers(false);
      }
    }, 250);

    return () => clearTimeout(timer);
  }, [customerSearch, selectedCustomer]);

  // Service Search: Call dedicated search API only when user enters search term
  useEffect(() => {
    const q = serviceSearch.trim();
    if (!q) {
      setServiceResults([]);
      setIsSearchingServices(false);
      return;
    }

    setIsSearchingServices(true);
    const timer = setTimeout(async () => {
      try {
        const res = await productApi.search(q);
        const list = Array.isArray(res.data?.data)
          ? res.data.data
          : Array.isArray(res.data)
            ? res.data
            : [];
        setServiceResults(list);
      } catch (err) {
        console.error('Service search error:', err);
        setServiceResults([]);
      } finally {
        setIsSearchingServices(false);
      }
    }, 250);

    return () => clearTimeout(timer);
  }, [serviceSearch]);

  // Toggle Service Selection
  const handleToggleService = (product: Product) => {
    setSelectedServices((prev) => {
      const exists = prev.some((p) => p.id === product.id);
      if (exists) {
        return prev.filter((p) => p.id !== product.id);
      } else {
        return [...prev, product];
      }
    });
  };

  const handleRemoveService = (productId: number) => {
    setSelectedServices((prev) => prev.filter((p) => p.id !== productId));
  };

  // Compute Total Price
  const totalPrice = useMemo(() => {
    return selectedServices.reduce((sum, p) => sum + (Number(p.price) || 0), 0);
  }, [selectedServices]);

  // Submission & Validations
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    // 1. Validate Date
    if (!apptDate) {
      setErrorMsg('Please select an appointment date.');
      return;
    }

    // 2. Validate Start and End Time
    const startM = timeToMinutes(startTime);
    const endM = timeToMinutes(endTime);

    if (endM <= startM) {
      setErrorMsg('End Time must not be earlier than Start Time.');
      return;
    }

    // 3. Customer validation
    const customerName = isWalkIn
      ? walkInName.trim()
      : selectedCustomer?.name || '';
    if (!customerName) {
      setErrorMsg(
        isWalkIn
          ? 'Please enter walk-in customer name.'
          : 'Please search and select a customer.'
      );
      return;
    }

    const customerPhone = isWalkIn
      ? walkInPhone.trim()
      : selectedCustomer?.phone || '';

    const customerId = isWalkIn
      ? null
      : selectedCustomer?.id && selectedCustomer.id > 0
        ? selectedCustomer.id
        : null;

    setIsSubmitting(true);

    try {
      // 4. Appointment Conflict Validation (Local check first)
      if (apptDate === defaultDate) {
        const clientConflict = checkClientOverlap(
          existingAppointments,
          startTime,
          endTime
        );
        if (clientConflict.hasConflict) {
          setErrorMsg(
            'An appointment already exists for this staff member during the selected time.'
          );
          setIsSubmitting(false);
          return;
        }
      }

      // 5. Server-side conflict check
      const conflictRes = await appointmentApi.checkConflict({
        staff_id: staff.id,
        appointment_date: apptDate,
        start_time: startTime,
        end_time: endTime,
      });

      if (conflictRes.data.has_conflict) {
        setErrorMsg(
          'An appointment already exists for this staff member during the selected time.'
        );
        setIsSubmitting(false);
        return;
      }

      // 6. Create appointment
      const payload = {
        staff_id: staff.id,
        staff_name: staff.name,
        customer_id: customerId,
        customer_name: customerName,
        customer_phone: customerPhone,
        appointment_date: apptDate,
        start_time: startTime,
        end_time: endTime,
        total_amount: totalPrice,
        services: selectedServices.map((p) => ({
          product_id: p.id,
          name: p.name,
          price: Number(p.price) || 0,
          quantity: 1,
        })),
        notes: notes.trim(),
      };

      await appointmentApi.create(payload);

      toast.success(
        `Appointment successfully booked for ${customerName} (${formatTime12(
          startTime
        )} – ${formatTime12(endTime)})`,
        {
          icon: <CheckCircle2 color="#10B981" size={20} />,
        }
      );

      onSuccess();
    } catch (err: any) {
      console.error('Failed to create appointment:', err);
      setErrorMsg(
        err?.response?.data?.message || 'Failed to create appointment. Please try again.'
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="v2-modal-overlay" onClick={onClose}>
      <div className="v2-modal v2-modal--add-appt" onClick={(e) => e.stopPropagation()}>
        {/* 1. HEADER WITH APPOINTMENT/CALENDAR ICON */}
        <div className="v2-modal__header">
          <div className="v2-modal__header-left">
            <div className="v2-modal__header-icon-badge">
              <CalendarCheck2 size={24} />
            </div>
            <div className="v2-modal__header-titles">
              <h3 className="v2-modal__title">Add Appointment</h3>
              <p className="v2-modal__subtitle">
                Assigning staff: <strong className="v2-modal__subtitle-staff">{staff.name}</strong>
              </p>
            </div>
          </div>
          <button type="button" className="v2-modal__close-btn" onClick={onClose} aria-label="Close modal">
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', flex: 1, overflow: 'hidden' }}>
          <div className="v2-modal__body">
            {/* Error Banner */}
            {errorMsg && (
              <div className="v2-alert-error">
                <AlertCircle size={18} />
                <span>{errorMsg}</span>
              </div>
            )}

            {/* SECTION 1: SELECT APPOINTMENT (CALENDAR ICON - BLUE) */}
            <div className="v2-card-section">
              <div className="v2-section-header">
                <div className="v2-section-header-left">
                  <span className="v2-section-icon-badge v2-section-icon-badge--blue">
                    <CalendarIcon size={18} />
                  </span>
                  <div className="v2-section-header-text">
                    <h4 className="v2-section-title">Select Appointment</h4>
                    <span className="v2-section-subtitle">Choose the appointment date</span>
                  </div>
                </div>
                <div className="v2-section-header-badge v2-section-header-badge--blue">
                  {formatDatePretty(apptDate)}
                </div>
              </div>

              <div className="v2-section-content">
                <div className="v2-input-with-icon">
                  <CalendarDays size={16} className="v2-input-icon" />
                  <input
                    type="date"
                    className="v2-input v2-input--has-icon"
                    value={apptDate}
                    onChange={(e) => {
                      setApptDate(e.target.value);
                      setErrorMsg(null);
                    }}
                    required
                  />
                </div>
              </div>
            </div>

            {/* SECTION 2: SELECT START & END TIME (CLOCK ICON - AMBER) */}
            <div className="v2-card-section">
              <div className="v2-section-header">
                <div className="v2-section-header-left">
                  <span className="v2-section-icon-badge v2-section-icon-badge--amber">
                    <Clock size={18} />
                  </span>
                  <div className="v2-section-header-text">
                    <h4 className="v2-section-title">Select Start & End Time</h4>
                    <span className="v2-section-subtitle">
                      Business hours: {formatTime12(openTime)} – {formatTime12(closeTime)}
                    </span>
                  </div>
                </div>
              </div>

              <div className="v2-section-content">
                {appointmentV2Clock ? (
                  <div className="v2-time-pickers-container">
                    {/* Left Side: Start Time Drum Wheel */}
                    <WheelTimePicker
                      label="Start Time"
                      value={startTime}
                      timeFormat={timeFormat}
                      onChange={(newStart) => {
                        setStartTime(newStart);
                        setErrorMsg(null);
                        // Automatically push end time forward if needed
                        if (timeToMinutes(endTime) <= timeToMinutes(newStart)) {
                          setEndTime(minutesToTime24(timeToMinutes(newStart) + 30));
                        }
                      }}
                    />

                    {/* Right Side: End Time Drum Wheel */}
                    <WheelTimePicker
                      label="End Time"
                      value={endTime}
                      timeFormat={timeFormat}
                      onChange={(newEnd) => {
                        setEndTime(newEnd);
                        setErrorMsg(null);
                      }}
                    />
                  </div>
                ) : (
                  <div className="v2-time-pickers-container">
                    {/* Start Time Clock Trigger */}
                    <div
                      className="v2-clock-trigger-card"
                      onClick={() => setClockPickerTarget('start')}
                      role="button"
                      tabIndex={0}
                    >
                      <div className="v2-clock-trigger-left">
                        <div className="v2-clock-trigger-icon-badge">
                          <Clock size={18} />
                        </div>
                        <div className="v2-clock-trigger-text">
                          <span className="v2-clock-trigger-label">Start Time</span>
                          <span className="v2-clock-trigger-time">
                            {formatTime12(startTime)}
                          </span>
                        </div>
                      </div>
                      <span className="v2-clock-trigger-badge">Change</span>
                    </div>

                    {/* End Time Clock Trigger */}
                    <div
                      className="v2-clock-trigger-card"
                      onClick={() => setClockPickerTarget('end')}
                      role="button"
                      tabIndex={0}
                    >
                      <div className="v2-clock-trigger-left">
                        <div className="v2-clock-trigger-icon-badge">
                          <Clock size={18} />
                        </div>
                        <div className="v2-clock-trigger-text">
                          <span className="v2-clock-trigger-label">End Time</span>
                          <span className="v2-clock-trigger-time">
                            {formatTime12(endTime)}
                          </span>
                        </div>
                      </div>
                      <span className="v2-clock-trigger-badge">Change</span>
                    </div>
                  </div>
                )}

                {/* Window Summary & Quick Duration Presets */}
                <div className="v2-time-duration-bar">
                  <div className="v2-time-duration-bar__left">
                    <Clock size={16} color="#d97706" />
                    <span className="v2-time-duration-label">
                      {formatTimeSlotLabel(startTime, endTime, timeFormat)}
                    </span>
                    <span
                      className={`v2-time-duration-badge ${timeToMinutes(endTime) > timeToMinutes(startTime)
                        ? 'v2-time-duration-badge--valid'
                        : 'v2-time-duration-badge--invalid'
                        }`}
                    >
                      {timeToMinutes(endTime) > timeToMinutes(startTime)
                        ? `${timeToMinutes(endTime) - timeToMinutes(startTime)} mins`
                        : 'End must be after Start'}
                    </span>
                  </div>

                  {/* Quick Add Duration Presets */}
                  <div className="v2-quick-duration-presets">
                    <span className="v2-quick-duration-hint">Quick:</span>
                    {[15, 30, 45, 60, 90].map((mins) => (
                      <button
                        key={mins}
                        type="button"
                        className="v2-quick-duration-btn"
                        onClick={() => {
                          const newEndM = timeToMinutes(startTime) + mins;
                          setEndTime(minutesToTime24(newEndM));
                          setErrorMsg(null);
                        }}
                      >
                        +{mins}m
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>

            {/* SECTION 3: CUSTOMER INFORMATION (USER ICON - EMERALD) */}
            <div className="v2-card-section">
              <div className="v2-section-header">
                <div className="v2-section-header-left">
                  <span className="v2-section-icon-badge v2-section-icon-badge--emerald">
                    <User size={18} />
                  </span>
                  <div className="v2-section-header-text">
                    <h4 className="v2-section-title">Customer Information</h4>
                    <span className="v2-section-subtitle">Search registered customer or enter guest</span>
                  </div>
                </div>
              </div>

              <div className="v2-section-content">
                {/* Segmented Customer Type Buttons */}
                <div className="v2-customer-type-toggle">
                  <button
                    type="button"
                    className={`v2-customer-toggle-btn ${!isWalkIn ? 'v2-customer-toggle-btn--active' : ''}`}
                    onClick={() => {
                      setIsWalkIn(false);
                      setErrorMsg(null);
                    }}
                  >
                    <span>Registered Customer</span>
                  </button>
                  <button
                    type="button"
                    className={`v2-customer-toggle-btn ${isWalkIn ? 'v2-customer-toggle-btn--active' : ''}`}
                    onClick={() => {
                      setIsWalkIn(true);
                      setErrorMsg(null);
                    }}
                  >
                    <span>Walk-in Guest</span>
                  </button>
                </div>

                {isWalkIn ? (
                  <div className="v2-customer-inputs-grid">
                    <div className="v2-input-with-icon">
                      <User size={16} className="v2-input-icon" />
                      <input
                        type="text"
                        className="v2-input v2-input--has-icon"
                        placeholder="Customer Name *"
                        value={walkInName}
                        onChange={(e) => {
                          setWalkInName(e.target.value);
                          setErrorMsg(null);
                        }}
                        required
                      />
                    </div>
                    <div className="v2-input-with-icon">
                      <Phone size={16} className="v2-input-icon" />
                      <input
                        type="tel"
                        className="v2-input v2-input--has-icon"
                        placeholder="Phone Number (optional)"
                        value={walkInPhone}
                        onChange={(e) => setWalkInPhone(e.target.value)}
                      />
                    </div>
                  </div>
                ) : selectedCustomer ? (
                  /* Display Selected Customer Chip/Card */
                  <div className="v2-cust-selected-card">
                    <div className="v2-cust-selected-left">
                      <div className="v2-cust-selected-avatar">
                        {selectedCustomer.name ? selectedCustomer.name[0].toUpperCase() : 'C'}
                      </div>
                      <div className="v2-cust-selected-info">
                        <div className="v2-cust-selected-name">{selectedCustomer.name}</div>
                        <div className="v2-cust-selected-phone">
                          <Phone size={12} />
                          <span>{selectedCustomer.phone || 'No phone provided'}</span>
                        </div>
                      </div>
                    </div>
                    <button
                      type="button"
                      className="v2-cust-selected-change-btn"
                      title="Change customer"
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
                ) : (
                  /* Live Search Input & Dropdown */
                  <div className="v2-search-input-box">
                    <div className="v2-input-with-icon">
                      <Search size={16} className="v2-input-icon" />
                      <input
                        type="text"
                        className="v2-input v2-input--has-icon v2-input--has-icon-and-clear"
                        placeholder="Search by customer name or phone..."
                        value={customerSearch}
                        onChange={(e) => {
                          setCustomerSearch(e.target.value);
                          setErrorMsg(null);
                        }}
                        autoComplete="off"
                      />
                      {customerSearch && (
                        <button
                          type="button"
                          className="v2-input-clear-btn"
                          title="Clear search"
                          onClick={() => {
                            setCustomerSearch('');
                            setCustomerResults([]);
                          }}
                        >
                          <X size={13} />
                        </button>
                      )}
                    </div>

                    {/* Dropdown panel when searching */}
                    {customerSearch.trim().length > 0 && (
                      <div className="v2-search-dropdown-panel">
                        <div className="v2-search-dropdown-header">
                          <span>Matching Customers ({customerResults.length})</span>
                          {customerResults.length > 0 && (
                            <span className="v2-search-dropdown-badge">Tap to select</span>
                          )}
                        </div>

                        {isSearchingCustomers ? (
                          <div className="v2-search-item-empty">
                            <RefreshCw size={14} className="v2-spin inline mr-2 text-blue-600" />
                            <span>Searching database for "{customerSearch.trim()}"...</span>
                          </div>
                        ) : customerResults.length === 0 ? (
                          <div className="v2-search-item-empty">
                            <span>No matching customers found for "{customerSearch.trim()}"</span>
                          </div>
                        ) : (
                          <>
                            <div className="v2-search-dropdown-list">
                              {customerResults.map((c) => (
                                <div
                                  key={c.id}
                                  className="v2-search-item"
                                  onClick={() => {
                                    setSelectedCustomer(c);
                                    setCustomerSearch('');
                                    setCustomerResults([]);
                                    setErrorMsg(null);
                                  }}
                                >
                                  <div className="v2-search-item__left">
                                    <div className="v2-search-avatar">
                                      {c.name ? c.name[0].toUpperCase() : 'C'}
                                    </div>
                                    <div className="v2-search-item__info">
                                      <div className="v2-search-item__title">{c.name}</div>
                                      <div className="v2-search-item__sub">
                                        <Phone size={11} />
                                        <span>{c.phone || 'No phone'}</span>
                                      </div>
                                    </div>
                                  </div>
                                </div>
                              ))}
                            </div>
                            {customerResults.length > 5 && (
                              <div className="v2-search-dropdown-footer">
                                ↕ Scroll for more ({customerResults.length} customers found)
                              </div>
                            )}
                          </>
                        )}
                      </div>
                    )}

                    {!customerSearch.trim() && (
                      <div className="v2-hint-tip">
                        <AlertCircle size={13} className="text-slate-400" />
                        <span>Type customer name or phone above to search and select.</span>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>

            {/* SECTION 4: SELECT SERVICE (BRIEFCASE ICON - PURPLE) */}
            <div className="v2-card-section">
              <div className="v2-section-header">
                <div className="v2-section-header-left">
                  <span className="v2-section-icon-badge v2-section-icon-badge--purple">
                    <Briefcase size={18} />
                  </span>
                  <div className="v2-section-header-text">
                    <h4 className="v2-section-title">Select Service</h4>
                    <span className="v2-section-subtitle">
                      {selectedServices.length} service{selectedServices.length === 1 ? '' : 's'} selected
                    </span>
                  </div>
                </div>
                <div className="v2-section-price-badge">
                  <span className="v2-section-price-label">Total:</span>
                  <span className="v2-section-price-amount">${totalPrice.toFixed(2)}</span>
                </div>
              </div>

              <div className="v2-section-content">
                {/* Search Bar for Services (calls dedicated API on typing) */}
                <div className="v2-search-input-box">
                  <div className="v2-input-with-icon">
                    <Search size={16} className="v2-input-icon" />
                    <input
                      type="text"
                      className="v2-input v2-input--has-icon v2-input--has-icon-and-clear"
                      placeholder="Search service or product name..."
                      value={serviceSearch}
                      onChange={(e) => {
                        setServiceSearch(e.target.value);
                      }}
                      autoComplete="off"
                    />
                    {serviceSearch && (
                      <button
                        type="button"
                        className="v2-input-clear-btn"
                        title="Clear service search"
                        onClick={() => {
                          setServiceSearch('');
                          setServiceResults([]);
                        }}
                      >
                        <X size={13} />
                      </button>
                    )}
                  </div>

                  {/* Dropdown panel when searching services */}
                  {serviceSearch.trim().length > 0 && (
                    <div className="v2-search-dropdown-panel">
                      <div className="v2-search-dropdown-header">
                        <span>Matching Services ({serviceResults.length})</span>
                        {serviceResults.length > 0 && (
                          <span className="v2-search-dropdown-badge">Tap to toggle</span>
                        )}
                      </div>

                      {isSearchingServices ? (
                        <div className="v2-search-item-empty">
                          <RefreshCw size={14} className="v2-spin inline mr-2 text-purple-600" />
                          <span>Searching services for "{serviceSearch.trim()}"...</span>
                        </div>
                      ) : serviceResults.length === 0 ? (
                        <div className="v2-search-item-empty">
                          <span>No matching services or products found for "{serviceSearch.trim()}"</span>
                        </div>
                      ) : (
                        <>
                          <div className="v2-search-dropdown-list">
                            {serviceResults.map((p) => {
                              const isSel = selectedServices.some((s) => s.id === p.id);
                              return (
                                <div
                                  key={p.id}
                                  className={`v2-search-item ${isSel ? 'v2-search-item--selected' : ''
                                    }`}
                                  onClick={() => handleToggleService(p)}
                                >
                                  <div className="v2-search-item__left">
                                    <span
                                      className={`v2-service-pick-chip__check ${isSel ? 'v2-service-pick-chip__check--checked' : ''
                                        }`}
                                    >
                                      {isSel && <Check size={12} />}
                                    </span>
                                    <div className="v2-search-item__info">
                                      <span className="v2-search-item__title">{p.name}</span>
                                      <span className="v2-search-item__sub">
                                        {p.product_type || 'Service'}
                                      </span>
                                    </div>
                                  </div>
                                  <span className="v2-search-item__price">
                                    ${Number(p.price).toFixed(2)}
                                  </span>
                                </div>
                              );
                            })}
                          </div>
                          {serviceResults.length > 5 && (
                            <div className="v2-search-dropdown-footer">
                              ↕ Scroll for more ({serviceResults.length} services found)
                            </div>
                          )}
                        </>
                      )}
                    </div>
                  )}
                </div>

                {/* Selected Services Display */}
                {selectedServices.length > 0 ? (
                  <div className="v2-selected-services-wrap">
                    <span className="v2-selected-services-title">
                      Selected Services ({selectedServices.length}):
                    </span>
                    <div className="v2-selected-services-chips">
                      {selectedServices.map((p) => (
                        <div key={p.id} className="v2-selected-service-chip">
                          <span>{p.name}</span>
                          <span className="v2-selected-service-chip__price">
                            ${Number(p.price).toFixed(2)}
                          </span>
                          <button
                            type="button"
                            className="v2-selected-service-chip__remove"
                            title="Remove service"
                            onClick={() => handleRemoveService(p.id)}
                          >
                            <X size={13} />
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                ) : !serviceSearch.trim() ? (
                  <div className="v2-hint-tip">
                    <Briefcase size={13} className="text-slate-400" />
                    <span>Type service or product name above to search and add services.</span>
                  </div>
                ) : null}
              </div>
            </div>

            {/* SECTION 5: NOTES (FILETEXT ICON - ROSE) */}
            <div className="v2-card-section">
              <div className="v2-section-header">
                <div className="v2-section-header-left">
                  <span className="v2-section-icon-badge v2-section-icon-badge--rose">
                    <FileText size={18} />
                  </span>
                  <div className="v2-section-header-text">
                    <h4 className="v2-section-title">Notes</h4>
                    <span className="v2-section-subtitle">Special requests or instructions</span>
                  </div>
                </div>
                <span className="v2-section-optional-badge">Optional</span>
              </div>

              <div className="v2-section-content">
                <textarea
                  rows={2}
                  className="v2-input v2-textarea"
                  placeholder="Special requests, client preferences, or internal notes..."
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                />
              </div>
            </div>
          </div>

          {/* MODAL FOOTER */}
          <div className="v2-modal__footer">
            <button type="button" className="v2-btn v2-btn--secondary" onClick={onClose} disabled={isSubmitting}>
              Cancel
            </button>
            <button type="submit" className="v2-btn v2-btn--primary v2-btn--save-appt" disabled={isSubmitting}>
              <CheckCircle2 size={16} />
              <span>{isSubmitting ? 'Checking & Saving...' : 'Save Appointment'}</span>
            </button>
          </div>
        </form>
      </div>

      {/* CLOCK-BASED TIME PICKER MODAL (when appointment_v2_clock is OFF) */}
      {clockPickerTarget && (
        <ClockTimePickerModal
          isOpen={true}
          label={clockPickerTarget === 'start' ? 'Select Start Time' : 'Select End Time'}
          initialTime24={clockPickerTarget === 'start' ? startTime : endTime}
          onClose={() => setClockPickerTarget(null)}
          onSelectTime={(newTime24) => {
            if (clockPickerTarget === 'start') {
              setStartTime(newTime24);
              setErrorMsg(null);
              // Automatically push end time forward if needed
              if (timeToMinutes(endTime) <= timeToMinutes(newTime24)) {
                setEndTime(minutesToTime24(timeToMinutes(newTime24) + 30));
              }
            } else {
              setEndTime(newTime24);
              setErrorMsg(null);
            }
            setClockPickerTarget(null);
          }}
        />
      )}
    </div>
  );
}

/* ==========================================================================
   SUB-COMPONENT: TIME SLOT FILTER MODAL
   ========================================================================== */
interface TimeSlotFilterModalProps {
  slots: BusinessSlot[];
  slotAppointmentMap: Map<string, Appointment[]>;
  filterStatus: 'all' | 'available' | 'booked';
  onFilterChange: (st: 'all' | 'available' | 'booked') => void;
  onSelectSlot: (start24: string) => void;
  onClose: () => void;
}

function TimeSlotFilterModal({
  slots,
  slotAppointmentMap,
  filterStatus,
  onFilterChange,
  onSelectSlot,
  onClose,
}: TimeSlotFilterModalProps) {
  const filtered = slots.filter((slot) => {
    const appts = slotAppointmentMap.get(slot.start24) || [];
    const isBooked = appts.length > 0;
    if (filterStatus === 'available') return !isBooked;
    if (filterStatus === 'booked') return isBooked;
    return true;
  });

  return (
    <div className="v2-modal-overlay" onClick={onClose}>
      <div className="v2-modal" style={{ maxWidth: 540 }} onClick={(e) => e.stopPropagation()}>
        <div className="v2-modal__header">
          <h3 className="v2-modal__title">30-Minute Time Slot Overview</h3>
          <button type="button" className="v2-modal__close-btn" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        <div className="v2-modal__body">
          <div className="v2-filter-tabs">
            <button
              type="button"
              className={`v2-filter-tab-btn ${filterStatus === 'all' ? 'v2-filter-tab-btn--active' : ''}`}
              onClick={() => onFilterChange('all')}
            >
              All Slots ({slots.length})
            </button>
            <button
              type="button"
              className={`v2-filter-tab-btn ${filterStatus === 'available' ? 'v2-filter-tab-btn--active' : ''
                }`}
              onClick={() => onFilterChange('available')}
            >
              Available Only
            </button>
            <button
              type="button"
              className={`v2-filter-tab-btn ${filterStatus === 'booked' ? 'v2-filter-tab-btn--active' : ''}`}
              onClick={() => onFilterChange('booked')}
            >
              Booked Only
            </button>
          </div>

          <div className="v2-filter-slots-grid">
            {filtered.map((slot) => {
              const appts = slotAppointmentMap.get(slot.start24) || [];
              const isBooked = appts.length > 0;
              const statusMeta = isBooked ? getStatusMeta(appts[0].status) : null;

              return (
                <div
                  key={slot.start24}
                  className="v2-filter-slot-card"
                  onClick={() => onSelectSlot(slot.start24)}
                >
                  <span className="v2-filter-slot-card__time">{slot.label}</span>
                  {isBooked && statusMeta ? (
                    <span
                      style={{
                        color: statusMeta.color,
                        fontWeight: 700,
                        fontSize: 11,
                        textTransform: 'uppercase',
                      }}
                    >
                      ● {statusMeta.label}
                    </span>
                  ) : (
                    <span style={{ color: '#059669', fontWeight: 600, fontSize: 11 }}>
                      ○ Available
                    </span>
                  )}
                </div>
              );
            })}
          </div>
        </div>

        <div className="v2-modal__footer">
          <button type="button" className="v2-btn v2-btn--secondary" onClick={onClose}>
            Close
          </button>
        </div>
      </div>
    </div>
  );
}

/* ==========================================================================
   SUB-COMPONENT: FULL APPOINTMENT DETAILS & ACTIONS MODAL
   ========================================================================== */
interface AppointmentDetailsV2ModalProps {
  appt: Appointment;
  timeFormat: '12' | '24';
  onClose: () => void;
  onStartService: () => void;
  onContinueService: () => void;
  onStatusChange: (newStatus: AppointmentStatus) => void;
  onDelete: () => void;
}

function AppointmentDetailsV2Modal({
  appt,
  timeFormat,
  onClose,
  onStartService,
  onContinueService,
  onStatusChange,
  onDelete,
}: AppointmentDetailsV2ModalProps) {
  const statusMeta = getStatusMeta(appt.status);

  return (
    <div className="v2-modal-overlay" onClick={onClose}>
      <div
        className="v2-modal v2-appt-details-modal"
        style={{ maxWidth: 580 }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* ── Modal Header: Unique Modern Redesign (Requirement 1) ── */}
        <div className="v2-modal__header v2-appt-modal-header">
          <div className="v2-appt-modal-header__main">
            {/* Header Icon Badge */}
            <div className="v2-appt-modal-header__badge">
              <CalendarCheck2 size={22} className="v2-appt-modal-header__badge-icon" />
            </div>

            {/* Title & Metadata */}
            <div className="v2-appt-modal-header__titles">
              <div className="v2-appt-modal-header__row">
                <h3 className="v2-appt-modal-heading">Appointment</h3>
                <span className="v2-appt-id-pill" title={`Appointment ID: #${appt.id}`}>
                  <Tag size={12} className="v2-appt-id-icon" />
                  <span>#{appt.id}</span>
                </span>
                <span className={`v2-status-pill v2-status-pill--${statusMeta.key}`}>
                  {statusMeta.label}
                </span>
              </div>
              <p className="v2-appt-modal-sub">
                <span className="v2-appt-modal-sub-item">
                  <CalendarIcon size={12} />
                  <span>{formatDatePretty(appt.appointment_date)}</span>
                </span>
                <span className="v2-appt-modal-sub-sep">•</span>
                <span className="v2-appt-modal-sub-item">
                  <Clock size={12} />
                  <span>{formatTimeSlotLabel(appt.start_time, appt.end_time, timeFormat)}</span>
                </span>
              </p>
            </div>
          </div>

          <button
            type="button"
            className="v2-modal__close-btn"
            onClick={onClose}
            aria-label="Close dialog"
          >
            <X size={18} />
          </button>
        </div>

        {/* ── Modal Body: Organized Cards with Icons (Requirement 2) ── */}
        <div className="v2-modal__body v2-appt-modal-body">
          {/* Section 1: Core Details Grid with Dedicated Icons */}
          <div className="v2-details-card-grid">
            {/* Customer Name */}
            <div className="v2-detail-card">
              <div className="v2-detail-card__icon-wrap v2-detail-card__icon-wrap--customer">
                <User size={16} />
              </div>
              <div className="v2-detail-card__content">
                <span className="v2-detail-card__label">Customer Name</span>
                <span className="v2-detail-card__value" title={appt.customer_name || 'Walk-in Guest'}>
                  {appt.customer_name || 'Walk-in Guest'}
                </span>
              </div>
            </div>

            {/* Phone Number */}
            <div className="v2-detail-card">
              <div className="v2-detail-card__icon-wrap v2-detail-card__icon-wrap--phone">
                <Phone size={16} />
              </div>
              <div className="v2-detail-card__content">
                <span className="v2-detail-card__label">Phone Number</span>
                <span className="v2-detail-card__value">
                  {appt.customer_phone ? (
                    <a
                      href={`tel:${appt.customer_phone}`}
                      className="v2-detail-link"
                      onClick={(e) => e.stopPropagation()}
                    >
                      {appt.customer_phone}
                    </a>
                  ) : (
                    <span style={{ color: '#94a3b8' }}>None</span>
                  )}
                </span>
              </div>
            </div>

            {/* Assigned Staff */}
            <div className="v2-detail-card">
              <div className="v2-detail-card__icon-wrap v2-detail-card__icon-wrap--staff">
                <Briefcase size={16} />
              </div>
              <div className="v2-detail-card__content">
                <span className="v2-detail-card__label">Assigned Staff</span>
                <span className="v2-detail-card__value" title={appt.staff_name}>
                  {appt.staff_name}
                </span>
              </div>
            </div>

            {/* Appointment Date */}
            <div className="v2-detail-card">
              <div className="v2-detail-card__icon-wrap v2-detail-card__icon-wrap--date">
                <CalendarIcon size={16} />
              </div>
              <div className="v2-detail-card__content">
                <span className="v2-detail-card__label">Appointment Date</span>
                <span className="v2-detail-card__value">
                  {formatDatePretty(appt.appointment_date)}
                </span>
              </div>
            </div>

            {/* Scheduled Time */}
            <div className="v2-detail-card">
              <div className="v2-detail-card__icon-wrap v2-detail-card__icon-wrap--time">
                <Clock size={16} />
              </div>
              <div className="v2-detail-card__content">
                <span className="v2-detail-card__label">Scheduled Time</span>
                <span className="v2-detail-card__value">
                  {formatTimeSlotLabel(appt.start_time, appt.end_time, timeFormat)}
                </span>
              </div>
            </div>

            {/* Total Payment */}
            <div className="v2-detail-card">
              <div className="v2-detail-card__icon-wrap v2-detail-card__icon-wrap--payment">
                <CreditCard size={16} />
              </div>
              <div className="v2-detail-card__content">
                <span className="v2-detail-card__label">Total Payment</span>
                <span className="v2-detail-card__value v2-detail-card__value--price">
                  ${Number(appt.total_amount || 0).toFixed(2)}
                </span>
              </div>
            </div>
          </div>

          {/* Section 2: Services Included with Icons */}
          <div className="v2-field-group">
            <div className="v2-field-label-row">
              <div className="v2-field-label-with-icon">
                <Scissors size={15} className="v2-field-label-icon" />
                <span className="v2-field-label" style={{ marginBottom: 0 }}>Services Included</span>
              </div>
              {(appt.services || []).length > 0 && (
                <span className="v2-field-count-pill">
                  {appt.services.length} {appt.services.length === 1 ? 'item' : 'items'}
                </span>
              )}
            </div>

            <div className="v2-services-card-list">
              {(appt.services || []).length > 0 ? (
                appt.services.map((s, idx) => (
                  <div key={idx} className="v2-service-item-row">
                    <div className="v2-service-item-info">
                      <span className="v2-service-item-dot" />
                      <span className="v2-service-item-name">{s.name || s.product_name}</span>
                    </div>
                    <span className="v2-service-item-price">
                      ${Number(s.price || 0).toFixed(2)}
                    </span>
                  </div>
                ))
              ) : (
                <div className="v2-service-item-row v2-service-item-row--empty">
                  <div className="v2-service-item-info">
                    <Tag size={14} style={{ color: '#94a3b8' }} />
                    <span className="v2-service-item-name">General Service</span>
                  </div>
                  <span className="v2-service-item-price">
                    ${Number(appt.total_amount || 0).toFixed(2)}
                  </span>
                </div>
              )}
            </div>
          </div>

          {/* Section 3: Appointment Notes */}
          {appt.notes && (
            <div className="v2-field-group">
              <div className="v2-field-label-with-icon">
                <FileText size={15} className="v2-field-label-icon" />
                <span className="v2-field-label" style={{ marginBottom: 0 }}>Appointment Notes</span>
              </div>
              <div className="v2-notes-box">
                <FileText size={15} className="v2-notes-icon" />
                <p className="v2-notes-text">{appt.notes}</p>
              </div>
            </div>
          )}

          {/* Section 4: Status Change Controls with Status Icons */}
          <div className="v2-field-group">
            <div className="v2-field-label-with-icon">
              <RefreshCw size={14} className="v2-field-label-icon" />
              <span className="v2-field-label" style={{ marginBottom: 0 }}>Change Status</span>
            </div>
            <div className="v2-status-actions-grid">
              <button
                type="button"
                className={`v2-status-action-btn v2-status-action-btn--booked ${appt.status === 'booked' ? 'is-active' : ''}`}
                onClick={() => onStatusChange('booked')}
              >
                <Clock size={13} />
                <span>Booked</span>
              </button>
              <button
                type="button"
                className={`v2-status-action-btn v2-status-action-btn--in_service ${appt.status === 'in_service' ? 'is-active' : ''}`}
                onClick={() => onStatusChange('in_service')}
              >
                <Play size={13} />
                <span>In Service</span>
              </button>
              <button
                type="button"
                className={`v2-status-action-btn v2-status-action-btn--completed ${appt.status === 'completed' ? 'is-active' : ''}`}
                onClick={() => onStatusChange('completed')}
              >
                <CheckCircle2 size={13} />
                <span>Completed</span>
              </button>
              <button
                type="button"
                className={`v2-status-action-btn v2-status-action-btn--no_show ${appt.status === 'no_show' ? 'is-active' : ''}`}
                onClick={() => onStatusChange('no_show')}
              >
                <UserX size={13} />
                <span>No Show</span>
              </button>
              <button
                type="button"
                className={`v2-status-action-btn v2-status-action-btn--cancelled ${appt.status === 'cancelled' ? 'is-active' : ''}`}
                onClick={() => onStatusChange('cancelled')}
              >
                <XCircle size={13} />
                <span>Cancelled</span>
              </button>
            </div>
          </div>
        </div>

        {/* ── Modal Footer ── */}
        <div className="v2-modal__footer" style={{ justifyContent: 'space-between' }}>
          <button
            type="button"
            className="v2-btn v2-btn--secondary"
            style={{ color: '#ef4444', borderColor: '#fca5a5' }}
            onClick={onDelete}
          >
            <Trash2 size={15} />
            <span>Delete</span>
          </button>

          <div style={{ display: 'flex', gap: 10 }}>
            {appt.status === 'booked' && (
              <button
                type="button"
                className="v2-btn v2-btn--primary"
                onClick={onStartService}
              >
                <Play size={15} />
                <span>Start Service</span>
              </button>
            )}
            {appt.status === 'in_service' && (
              <button
                type="button"
                className="v2-btn v2-btn--primary"
                onClick={onContinueService}
              >
                <ArrowRight size={15} />
                <span>Continue Service</span>
              </button>
            )}
            <button
              type="button"
              className="v2-btn v2-btn--secondary"
              onClick={onClose}
            >
              <Check size={15} />
              <span>Done</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

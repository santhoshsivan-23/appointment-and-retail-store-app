import { useState, useEffect, useCallback, useMemo } from 'react';
import { toast } from 'react-toastify';
import {
  Users,
  Calendar as CalendarIcon,
  CalendarDays,
  CalendarCheck2,
  Clock,
  List as ListIcon,
  LayoutGrid,
  Filter,
  Plus,
  RefreshCw,
  Search,
  ChevronLeft,
  ChevronRight,
  User,
  Phone,
  AlertCircle,
  CheckCircle2,
  X,
  Play,
  Trash2,
  CalendarCheck,
  Check,
  Briefcase,
  FileText,
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

  // Time View: selected expanded slot (e.g. "08:00")
  const [expandedTimeSlot, setExpandedTimeSlot] = useState<string | null>(null);

  // Time Slot Filter Modal
  const [showFilterModal, setShowFilterModal] = useState<boolean>(false);
  const [filterSlotStatus, setFilterSlotStatus] = useState<'all' | 'available' | 'booked'>('all');

  // Add Appointment Modal
  const [showAddModal, setShowAddModal] = useState<boolean>(false);
  const [prefilledAddSlot, setPrefilledAddSlot] = useState<{ start24: string; end24: string } | null>(null);

  // Details Modal
  const [selectedDetailsAppt, setSelectedDetailsAppt] = useState<Appointment | null>(null);

  // Calendar Navigator Month (for right calendar widget)
  const [calendarViewDate, setCalendarViewDate] = useState<Date>(() => new Date());

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
    try {
      await appointmentApi.updateStatus(apptId, newStatus);
      toast.success(`Appointment marked as ${newStatus.replace('_', ' ')}`);
      fetchAppointments();
      if (selectedDetailsAppt && selectedDetailsAppt.id === apptId) {
        setSelectedDetailsAppt((prev) => (prev ? { ...prev, status: newStatus } : null));
      }
    } catch {
      toast.error('Failed to update status.');
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

  const handleStartServiceClick = (appt: Appointment) => {
    if (onStartService) {
      const customer = {
        id: appt.customer_id,
        name: appt.customer_name,
        phone: appt.customer_phone,
      };
      const products = (appt.services || []).map((s) => ({
        id: s.product_id || s.id,
        name: s.name || s.product_name,
        price: s.price || 0,
        quantity: s.quantity || 1,
      }));
      onStartService(customer, products, appt);
    } else {
      handleUpdateStatus(appt.id, 'in_service');
    }
  };

  /* ========================================================================
     SCREEN 1: INITIAL STAFF SELECTION SCREEN
     ======================================================================== */
  if (!selectedStaff) {
    const filteredStaff = staffList.filter((s) => {
      const q = staffSearchQuery.toLowerCase();
      return (
        s.name.toLowerCase().includes(q) ||
        (s.role && s.role.toLowerCase().includes(q))
      );
    });

    return (
      <div className="appointment-v2-container">
        <div className="v2-staff-screen">
          <div className="v2-staff-header">
            <div className="v2-staff-header__badge">
              <Users size={14} />
              <span>Appointment V2</span>
            </div>
            <h1 className="v2-staff-header__title">Select Staff Member</h1>
            <p className="v2-staff-header__subtitle">
              Choose a staff member to view today's schedule, navigate available time slots, and manage appointments in V2 view.
            </p>

            <div className="v2-staff-search-bar">
              <Search size={18} color="#64748b" />
              <input
                type="text"
                className="v2-staff-search-input"
                placeholder="Search staff by name or role..."
                value={staffSearchQuery}
                onChange={(e) => setStaffSearchQuery(e.target.value)}
              />
              {staffSearchQuery && (
                <button
                  type="button"
                  style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}
                  onClick={() => setStaffSearchQuery('')}
                >
                  <X size={16} />
                </button>
              )}
            </div>
          </div>

          {isLoadingStaff ? (
            <div className="v2-loading-screen">
              <div className="v2-spinner" />
              <span>Loading staff roster...</span>
            </div>
          ) : filteredStaff.length === 0 ? (
            <div className="v2-empty-state" style={{ maxWidth: 600, margin: '40px auto' }}>
              <div className="v2-empty-state__icon">
                <Users size={28} />
              </div>
              <h3 className="v2-empty-state__title">No Staff Found</h3>
              <p className="v2-empty-state__desc">
                {staffSearchQuery
                  ? `No staff members matched "${staffSearchQuery}".`
                  : 'No active staff members are registered in the terminal.'}
              </p>
            </div>
          ) : (
            <div className="v2-staff-grid">
              {filteredStaff.map((staff, idx) => {
                const bg = STAFF_BG_COLORS[idx % STAFF_BG_COLORS.length];
                const initials = staff.name
                  .split(' ')
                  .map((n) => n[0])
                  .slice(0, 2)
                  .join('')
                  .toUpperCase();
                const isActive = staff.is_active === 1 || staff.is_active === true || staff.is_active === undefined;

                return (
                  <div
                    key={staff.id}
                    className="v2-staff-card"
                    onClick={() => {
                      setSelectedStaff(staff);
                      setSelectedDate(getTodayDateStr());
                      setExpandedTimeSlot(null);
                    }}
                  >
                    <div className="v2-staff-card__top">
                      <div className="v2-staff-avatar" style={{ backgroundColor: bg }}>
                        {initials}
                      </div>
                      <span
                        className={`v2-staff-status-badge ${
                          isActive ? 'v2-staff-status-badge--active' : ''
                        }`}
                      >
                        <span className="v2-staff-status-dot" />
                        <span>{isActive ? 'Active' : 'Offline'}</span>
                      </span>
                    </div>

                    <h3 className="v2-staff-card__name">{staff.name}</h3>
                    <p className="v2-staff-card__role">{staff.role || 'Service Specialist'}</p>

                    <div className="v2-staff-card__footer">
                      <span>View Appointments</span>
                      <ChevronRight size={16} />
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
    <div className="appointment-v2-container">
      {/* ── Top Header Bar ───────────────────────────────────────────── */}
      <header className="v2-top-header">
        <div className="v2-top-header__left">
          {/* Selected Staff Pill */}
          <div className="v2-staff-pill">
            <div className="v2-staff-pill__avatar" style={{ backgroundColor: staffBg }}>
              {staffInitials}
            </div>
            <span>{selectedStaff.name}</span>
            <button
              type="button"
              className="v2-staff-switch-btn"
              onClick={() => setSelectedStaff(null)}
              title="Switch Staff Member"
            >
              Switch Staff
            </button>
          </div>

          {/* Selected Date Indicator */}
          <div className="v2-date-indicator">
            <CalendarIcon size={16} color="#0284c7" />
            <span>{formatDatePretty(selectedDate)}</span>
            {selectedDate === getTodayDateStr() && (
              <span
                style={{
                  fontSize: 11,
                  background: '#dbeafe',
                  color: '#1d4ed8',
                  padding: '2px 8px',
                  borderRadius: 12,
                  fontWeight: 700,
                }}
              >
                Today
              </span>
            )}
          </div>
        </div>

        <div className="v2-top-header__right">
          {/* Layout / View Selector */}
          <div className="v2-view-selector" role="group" aria-label="Layout View Selector">
            <button
              type="button"
              className={`v2-view-tab-btn ${viewMode === 'list' ? 'v2-view-tab-btn--active' : ''}`}
              onClick={() => setViewMode('list')}
              title="List View"
            >
              <ListIcon size={16} />
              <span>List</span>
            </button>
            <button
              type="button"
              className={`v2-view-tab-btn ${viewMode === 'grid' ? 'v2-view-tab-btn--active' : ''}`}
              onClick={() => setViewMode('grid')}
              title="Grid View"
            >
              <LayoutGrid size={16} />
              <span>Grid</span>
            </button>
            <button
              type="button"
              className={`v2-view-tab-btn ${viewMode === 'time' ? 'v2-view-tab-btn--active' : ''}`}
              onClick={() => setViewMode('time')}
              title="Time View (30-min slots)"
            >
              <Clock size={16} />
              <span>Time</span>
            </button>
          </div>

          {/* Time Slot Filter Button */}
          <button
            type="button"
            className="v2-btn v2-btn--secondary"
            onClick={() => setShowFilterModal(true)}
            title="Filter 30-minute time slots"
          >
            <Filter size={15} />
            <span>Slot Filter</span>
          </button>

          {/* Refresh Button */}
          <button
            type="button"
            className="v2-btn v2-btn--secondary"
            onClick={fetchAppointments}
            disabled={isLoadingAppts}
            title="Refresh appointments"
          >
            <RefreshCw size={15} className={isLoadingAppts ? 'v2-spin' : ''} />
          </button>

          {/* Add Appointment Button */}
          <button
            type="button"
            className="v2-btn v2-btn--primary"
            onClick={() => {
              setPrefilledAddSlot(null);
              setShowAddModal(true);
            }}
          >
            <Plus size={16} />
            <span>Add Appointment</span>
          </button>
        </div>
      </header>

      {/* ── Main Split View Body ─────────────────────────────────────── */}
      <div className="v2-main-body">
        {/* ==============================================================
            LEFT SECTION: Appointments / Time Section
            ============================================================== */}
        <section className="v2-appointments-section">
          {isLoadingAppts ? (
            <div className="v2-loading-screen">
              <div className="v2-spinner" />
              <span>Loading schedule for {selectedStaff.name}...</span>
            </div>
          ) : viewMode === 'list' ? (
            /* ── VIEW 1: LIST VIEW ────────────────────────────────────── */
            <div className="v2-list-view">
              {appointments.length === 0 ? (
                <div className="v2-empty-state">
                  <div className="v2-empty-state__icon">
                    <CalendarCheck size={28} />
                  </div>
                  <h3 className="v2-empty-state__title">No Appointments Scheduled</h3>
                  <p className="v2-empty-state__desc">
                    {selectedStaff.name} has no appointments on {formatDatePretty(selectedDate)}.
                  </p>
                  <button
                    type="button"
                    className="v2-btn v2-btn--primary"
                    onClick={() => {
                      setPrefilledAddSlot(null);
                      setShowAddModal(true);
                    }}
                  >
                    <Plus size={16} />
                    <span>Book An Appointment</span>
                  </button>
                </div>
              ) : (
                appointments.map((appt) => {
                  const statusMeta = getStatusMeta(appt.status);
                  const servicesStr = (appt.services || [])
                    .map((s) => s.name || s.product_name)
                    .filter(Boolean);

                  return (
                    <div
                      key={appt.id}
                      className="v2-list-card"
                      onClick={() => setSelectedDetailsAppt(appt)}
                      style={{ cursor: 'pointer' }}
                    >
                      <div className="v2-list-card__left">
                        {/* Time Badge */}
                        <div className="v2-time-badge">
                          <Clock size={14} color="#0284c7" />
                          <span>
                            {formatTimeSlotLabel(appt.start_time, appt.end_time, timeFormat)}
                          </span>
                        </div>

                        {/* Customer Info */}
                        <div className="v2-customer-block">
                          <span className="v2-customer-name">
                            <User size={15} color="#475569" />
                            {appt.customer_name || 'Walk-in Guest'}
                          </span>
                          {appt.customer_phone && (
                            <span className="v2-customer-phone">
                              {appt.customer_phone}
                            </span>
                          )}
                        </div>

                        {/* Services */}
                        <div className="v2-services-summary">
                          {servicesStr.length > 0 ? (
                            servicesStr.map((svc, i) => (
                              <span key={i} className="v2-service-tag">
                                {svc}
                              </span>
                            ))
                          ) : (
                            <span className="v2-service-tag">General Service</span>
                          )}
                        </div>
                      </div>

                      <div className="v2-list-card__right">
                        {/* Status Badge */}
                        <span className={`v2-status-pill v2-status-pill--${statusMeta.key}`}>
                          {statusMeta.label}
                        </span>

                        {/* Price */}
                        <div className="v2-price-tag">
                          ${Number(appt.total_amount || 0).toFixed(2)}
                        </div>

                        {/* Quick Action Button */}
                        {appt.status === 'booked' && (
                          <button
                            type="button"
                            className="v2-btn v2-btn--secondary"
                            style={{ padding: '5px 10px', fontSize: 12 }}
                            onClick={(e) => {
                              e.stopPropagation();
                              handleStartServiceClick(appt);
                            }}
                            title="Start Service"
                          >
                            <Play size={13} color="#0284c7" />
                            <span>Start</span>
                          </button>
                        )}
                        {appt.status === 'in_service' && (
                          <button
                            type="button"
                            className="v2-btn v2-btn--secondary"
                            style={{ padding: '5px 10px', fontSize: 12, borderColor: '#10b981', color: '#047857' }}
                            onClick={(e) => {
                              e.stopPropagation();
                              handleUpdateStatus(appt.id, 'completed');
                            }}
                            title="Complete Service"
                          >
                            <Check size={13} color="#047857" />
                            <span>Complete</span>
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          ) : viewMode === 'grid' ? (
            /* ── VIEW 2: GRID VIEW ────────────────────────────────────── */
            <div className="v2-grid-view">
              {appointments.length === 0 ? (
                <div className="v2-empty-state" style={{ gridColumn: '1 / -1' }}>
                  <div className="v2-empty-state__icon">
                    <CalendarCheck size={28} />
                  </div>
                  <h3 className="v2-empty-state__title">No Appointments In Grid</h3>
                  <p className="v2-empty-state__desc">
                    {selectedStaff.name} has no appointments on {formatDatePretty(selectedDate)}.
                  </p>
                  <button
                    type="button"
                    className="v2-btn v2-btn--primary"
                    onClick={() => {
                      setPrefilledAddSlot(null);
                      setShowAddModal(true);
                    }}
                  >
                    <Plus size={16} />
                    <span>Book An Appointment</span>
                  </button>
                </div>
              ) : (
                appointments.map((appt) => {
                  const statusMeta = getStatusMeta(appt.status);
                  const servicesStr = (appt.services || [])
                    .map((s) => s.name || s.product_name)
                    .join(', ') || 'General Service';

                  return (
                    <div
                      key={appt.id}
                      className="v2-grid-card"
                      onClick={() => setSelectedDetailsAppt(appt)}
                    >
                      {/* Appointment time displayed INSIDE the appointment/grid area */}
                      <div
                        className={`v2-grid-card__time-header v2-grid-card__time-header--${statusMeta.key}`}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                          <Clock size={14} />
                          <span>
                            {formatTimeSlotLabel(appt.start_time, appt.end_time, timeFormat)}
                          </span>
                        </div>
                        <span className={`v2-status-pill v2-status-pill--${statusMeta.key}`}>
                          {statusMeta.label}
                        </span>
                      </div>

                      <div className="v2-grid-card__body">
                        <div className="v2-grid-card__customer">
                          {appt.customer_name || 'Walk-in Guest'}
                        </div>
                        <div className="v2-grid-card__service">{servicesStr}</div>
                        {appt.customer_phone && (
                          <div style={{ fontSize: 12, color: '#64748b', display: 'flex', alignItems: 'center', gap: 4 }}>
                            <Phone size={12} />
                            <span>{appt.customer_phone}</span>
                          </div>
                        )}
                      </div>

                      <div className="v2-grid-card__footer">
                        <span>${Number(appt.total_amount || 0).toFixed(2)}</span>
                        <span style={{ fontSize: 12, color: '#0284c7' }}>View Details →</span>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          ) : (
            /* ── VIEW 3: TIME VIEW (30-min slots + expand below) ──────── */
            <div className="v2-time-view">
              {businessSlots.map((slot) => {
                const apptsInSlot = slotAppointmentMap.get(slot.start24) || [];
                const isBooked = apptsInSlot.length > 0;
                const primaryAppt = apptsInSlot[0];
                const statusMeta = primaryAppt ? getStatusMeta(primaryAppt.status) : null;
                const isExpanded = expandedTimeSlot === slot.start24;

                return (
                  <div
                    key={slot.start24}
                    id={`v2-slot-${slot.start24}`}
                    className={`v2-time-slot-item ${
                      isExpanded ? 'v2-time-slot-item--selected' : ''
                    }`}
                  >
                    {/* Time Slot Row Header */}
                    <div
                      className="v2-time-slot-row"
                      onClick={() => {
                        setExpandedTimeSlot(isExpanded ? null : slot.start24);
                      }}
                    >
                      <div className="v2-time-slot-row__left">
                        <div className="v2-time-slot-clock">
                          <Clock size={15} color="#0284c7" />
                          <span>{slot.label}</span>
                        </div>

                        {/* Status Tag */}
                        {isBooked && statusMeta ? (
                          <span
                            className={`v2-slot-status-tag v2-slot-status-tag--${statusMeta.key}`}
                          >
                            <span>{statusMeta.label}</span>
                            {primaryAppt.customer_name && (
                              <span style={{ opacity: 0.9, fontWeight: 500 }}>
                                • {primaryAppt.customer_name}
                              </span>
                            )}
                          </span>
                        ) : (
                          <span className="v2-slot-status-tag v2-slot-status-tag--available">
                            Available
                          </span>
                        )}
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <span style={{ fontSize: 12, color: '#64748b' }}>
                          {isExpanded ? 'Hide Details' : 'View Details'}
                        </span>
                        <ChevronRight
                          size={16}
                          color="#64748b"
                          style={{
                            transform: isExpanded ? 'rotate(90deg)' : 'none',
                            transition: 'transform 0.2s ease',
                          }}
                        />
                      </div>
                    </div>

                    {/* Expandable Appointment Details Displayed BELOW the Selected Slot */}
                    {isExpanded && (
                      <div className="v2-slot-details-panel">
                        {isBooked ? (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                            {apptsInSlot.map((appt) => {
                              const stMeta = getStatusMeta(appt.status);
                              const svcNames = (appt.services || [])
                                .map((s) => s.name || s.product_name)
                                .join(', ') || 'General Service';

                              return (
                                <div key={appt.id} className="v2-slot-details-card">
                                  <div className="v2-slot-details-card__header">
                                    <div className="v2-slot-details-card__title">
                                      <User size={16} color="#0284c7" />
                                      <span>Appointment Details</span>
                                    </div>
                                    <span className={`v2-status-pill v2-status-pill--${stMeta.key}`}>
                                      {stMeta.label}
                                    </span>
                                  </div>

                                  <div className="v2-slot-details-grid">
                                    <div className="v2-detail-item">
                                      <span className="v2-detail-label">Customer</span>
                                      <span className="v2-detail-value">
                                        {appt.customer_name || 'Walk-in Guest'}
                                      </span>
                                    </div>

                                    <div className="v2-detail-item">
                                      <span className="v2-detail-label">Contact</span>
                                      <span className="v2-detail-value">
                                        {appt.customer_phone || 'None'}
                                      </span>
                                    </div>

                                    <div className="v2-detail-item">
                                      <span className="v2-detail-label">Service</span>
                                      <span className="v2-detail-value">{svcNames}</span>
                                    </div>

                                    <div className="v2-detail-item">
                                      <span className="v2-detail-label">Staff Member</span>
                                      <span className="v2-detail-value">
                                        {appt.staff_name || selectedStaff.name}
                                      </span>
                                    </div>

                                    <div className="v2-detail-item">
                                      <span className="v2-detail-label">Time Window</span>
                                      <span className="v2-detail-value">
                                        {formatTimeSlotLabel(appt.start_time, appt.end_time, timeFormat)}
                                      </span>
                                    </div>

                                    <div className="v2-detail-item">
                                      <span className="v2-detail-label">Amount</span>
                                      <span className="v2-detail-value">
                                        ${Number(appt.total_amount || 0).toFixed(2)}
                                      </span>
                                    </div>
                                  </div>

                                  {/* Action Buttons for this appointment */}
                                  <div className="v2-slot-details-actions">
                                    {appt.status === 'booked' && (
                                      <button
                                        type="button"
                                        className="v2-btn v2-btn--primary"
                                        onClick={() => handleStartServiceClick(appt)}
                                      >
                                        <Play size={14} />
                                        <span>Start Service</span>
                                      </button>
                                    )}

                                    {appt.status === 'in_service' && (
                                      <button
                                        type="button"
                                        className="v2-btn v2-btn--primary"
                                        style={{ backgroundColor: '#10b981' }}
                                        onClick={() => handleUpdateStatus(appt.id, 'completed')}
                                      >
                                        <Check size={14} />
                                        <span>Mark Completed</span>
                                      </button>
                                    )}

                                    <button
                                      type="button"
                                      className="v2-btn v2-btn--secondary"
                                      onClick={() => setSelectedDetailsAppt(appt)}
                                    >
                                      <span>Full Details & Actions</span>
                                    </button>
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        ) : (
                          <div className="v2-slot-empty-notice">
                            <span>No appointment booked for this time slot.</span>
                            <button
                              type="button"
                              className="v2-btn v2-btn--primary"
                              onClick={() => {
                                setPrefilledAddSlot({
                                  start24: slot.start24,
                                  end24: slot.end24,
                                });
                                setShowAddModal(true);
                              }}
                            >
                              <Plus size={14} />
                              <span>Book this time slot</span>
                            </button>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </section>

        {/* ==============================================================
            RIGHT SECTION: Calendar / Date Section
            ============================================================== */}
        <aside className="v2-calendar-section">
          {/* Interactive Mini-Calendar */}
          <div className="v2-calendar-widget">
            <div className="v2-calendar-header">
              <span className="v2-calendar-month-title">
                {calendarViewDate.toLocaleDateString('en-US', {
                  month: 'long',
                  year: 'numeric',
                })}
              </span>
              <div className="v2-calendar-nav-btns">
                <button
                  type="button"
                  className="v2-calendar-icon-btn"
                  onClick={() => {
                    const d = new Date(calendarViewDate);
                    d.setMonth(d.getMonth() - 1);
                    setCalendarViewDate(d);
                  }}
                  title="Previous month"
                >
                  <ChevronLeft size={16} />
                </button>
                <button
                  type="button"
                  className="v2-calendar-icon-btn"
                  style={{ width: 'auto', padding: '0 8px', fontSize: 12, fontWeight: 600 }}
                  onClick={() => {
                    const today = new Date();
                    setCalendarViewDate(today);
                    setSelectedDate(getTodayDateStr());
                  }}
                  title="Jump to today"
                >
                  Today
                </button>
                <button
                  type="button"
                  className="v2-calendar-icon-btn"
                  onClick={() => {
                    const d = new Date(calendarViewDate);
                    d.setMonth(d.getMonth() + 1);
                    setCalendarViewDate(d);
                  }}
                  title="Next month"
                >
                  <ChevronRight size={16} />
                </button>
              </div>
            </div>

            <div className="v2-calendar-weekdays">
              <span>Su</span>
              <span>Mo</span>
              <span>Tu</span>
              <span>We</span>
              <span>Th</span>
              <span>Fr</span>
              <span>Sa</span>
            </div>

            <div className="v2-calendar-grid">
              {(() => {
                const year = calendarViewDate.getFullYear();
                const month = calendarViewDate.getMonth();
                const firstDayIdx = new Date(year, month, 1).getDay();
                const daysInMonth = new Date(year, month + 1, 0).getDate();
                const daysInPrevMonth = new Date(year, month, 0).getDate();

                const cells = [];
                // Prev month trailing days
                for (let i = firstDayIdx - 1; i >= 0; i--) {
                  const dayNum = daysInPrevMonth - i;
                  cells.push(
                    <button
                      key={`prev-${dayNum}`}
                      type="button"
                      className="v2-calendar-day-btn v2-calendar-day-btn--other-month"
                      disabled
                    >
                      {dayNum}
                    </button>
                  );
                }

                // Current month days
                const todayStr = getTodayDateStr();
                for (let d = 1; d <= daysInMonth; d++) {
                  const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(
                    d
                  ).padStart(2, '0')}`;
                  const isToday = dateStr === todayStr;
                  const isSelected = dateStr === selectedDate;

                  cells.push(
                    <button
                      key={dateStr}
                      type="button"
                      className={`v2-calendar-day-btn ${
                        isToday ? 'v2-calendar-day-btn--today' : ''
                      } ${isSelected ? 'v2-calendar-day-btn--selected' : ''}`}
                      onClick={() => {
                        setSelectedDate(dateStr);
                        setExpandedTimeSlot(null);
                      }}
                    >
                      <span>{d}</span>
                      {isSelected && <span className="v2-calendar-day-dot" />}
                    </button>
                  );
                }

                return cells;
              })()}
            </div>
          </div>

          {/* Selected Day Summary Card */}
          <div className="v2-day-summary-card">
            <h4 className="v2-day-summary-card__title">
              Summary for {formatDatePretty(selectedDate)}
            </h4>
            <div className="v2-stats-row">
              <div className="v2-stat-chip">
                <span className="v2-stat-chip__label">Total Appts</span>
                <span className="v2-stat-chip__value">{dayStats.total}</span>
              </div>
              <div className="v2-stat-chip">
                <span className="v2-stat-chip__label" style={{ color: '#1d4ed8' }}>
                  Booked
                </span>
                <span className="v2-stat-chip__value" style={{ color: '#1d4ed8' }}>
                  {dayStats.booked}
                </span>
              </div>
              <div className="v2-stat-chip">
                <span className="v2-stat-chip__label" style={{ color: '#b45309' }}>
                  In Service
                </span>
                <span className="v2-stat-chip__value" style={{ color: '#b45309' }}>
                  {dayStats.inService}
                </span>
              </div>
              <div className="v2-stat-chip">
                <span className="v2-stat-chip__label" style={{ color: '#047857' }}>
                  Completed
                </span>
                <span className="v2-stat-chip__value" style={{ color: '#047857' }}>
                  {dayStats.completed}
                </span>
              </div>
            </div>
          </div>

          {/* Quick Staff Card */}
          <div
            style={{
              padding: 16,
              background: '#ffffff',
              border: '1px solid #e2e8f0',
              borderRadius: 12,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div
                style={{
                  width: 36,
                  height: 36,
                  borderRadius: 10,
                  backgroundColor: staffBg,
                  color: '#fff',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontWeight: 700,
                  fontSize: 14,
                }}
              >
                {staffInitials}
              </div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 700, color: '#0f172a' }}>
                  {selectedStaff.name}
                </div>
                <div style={{ fontSize: 12, color: '#64748b' }}>
                  {selectedStaff.role || 'Specialist'}
                </div>
              </div>
            </div>
            <button
              type="button"
              className="v2-staff-switch-btn"
              onClick={() => setSelectedStaff(null)}
            >
              Change
            </button>
          </div>
        </aside>
      </div>

      {/* ====================================================================
          MODAL 1: ADD APPOINTMENT (DATE + SCROLLABLE START/END TIME + CONFLICT)
          ==================================================================== */}
      {showAddModal && (
        <AddAppointmentV2Modal
          staff={selectedStaff}
          defaultDate={selectedDate}
          prefilledSlot={prefilledAddSlot}
          openTime={openTime}
          closeTime={closeTime}
          timeFormat={timeFormat}
          appointmentV2Clock={appointmentV2Clock}
          existingAppointments={appointments}
          onClose={() => {
            setShowAddModal(false);
            setPrefilledAddSlot(null);
          }}
          onSuccess={() => {
            setShowAddModal(false);
            setPrefilledAddSlot(null);
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
            setExpandedTimeSlot(start24);
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

  // Customer Selection
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [selectedCustomerId, setSelectedCustomerId] = useState<number | null>(null);
  const [isWalkIn, setIsWalkIn] = useState<boolean>(true);
  const [walkInName, setWalkInName] = useState<string>('');
  const [walkInPhone, setWalkInPhone] = useState<string>('');

  // Service Selection
  const [products, setProducts] = useState<Product[]>([]);
  const [selectedProductIds, setSelectedProductIds] = useState<number[]>([]);

  // Notes & Validation Error
  const [notes, setNotes] = useState<string>('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);

  // Load Customers & Products
  useEffect(() => {
    customerApi.getAll().then((res) => {
      if (res.data?.data) setCustomers(res.data.data);
    });
    productApi.getAll().then((res) => {
      if (res.data?.data) setProducts(res.data.data);
    });
  }, []);

  // Compute Total Price
  const selectedProducts = useMemo(() => {
    return products.filter((p) => selectedProductIds.includes(p.id));
  }, [products, selectedProductIds]);

  const totalPrice = useMemo(() => {
    return selectedProducts.reduce((sum, p) => sum + (Number(p.price) || 0), 0);
  }, [selectedProducts]);

  const handleToggleProduct = (prodId: number) => {
    setSelectedProductIds((prev) =>
      prev.includes(prodId) ? prev.filter((id) => id !== prodId) : [...prev, prodId]
    );
  };

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
      : customers.find((c) => c.id === selectedCustomerId)?.name || '';
    if (!customerName) {
      setErrorMsg('Please enter customer name or select an existing customer.');
      return;
    }

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
        customer_id: isWalkIn ? null : selectedCustomerId,
        customer_name: customerName,
        customer_phone: isWalkIn
          ? walkInPhone.trim()
          : customers.find((c) => c.id === selectedCustomerId)?.phone || '',
        appointment_date: apptDate,
        start_time: startTime,
        end_time: endTime,
        total_amount: totalPrice,
        services: selectedProducts.map((p) => ({
          product_id: p.id,
          name: p.name,
          price: p.price,
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
                      className={`v2-time-duration-badge ${
                        timeToMinutes(endTime) > timeToMinutes(startTime)
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
                    <span className="v2-section-subtitle">Assign a guest or registered customer</span>
                  </div>
                </div>
              </div>

              <div className="v2-section-content">
                {/* Segmented Customer Type Buttons */}
                <div className="v2-customer-type-toggle">
                  <button
                    type="button"
                    className={`v2-customer-toggle-btn ${isWalkIn ? 'v2-customer-toggle-btn--active' : ''}`}
                    onClick={() => setIsWalkIn(true)}
                  >
                    <span>Walk-in Guest</span>
                  </button>
                  <button
                    type="button"
                    className={`v2-customer-toggle-btn ${!isWalkIn ? 'v2-customer-toggle-btn--active' : ''}`}
                    onClick={() => setIsWalkIn(false)}
                  >
                    <span>Registered Customer</span>
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
                        onChange={(e) => setWalkInName(e.target.value)}
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
                ) : (
                  <div className="v2-customer-select-wrap">
                    <select
                      className="v2-input v2-select"
                      value={selectedCustomerId || ''}
                      onChange={(e) => setSelectedCustomerId(Number(e.target.value) || null)}
                      required
                    >
                      <option value="">-- Choose Registered Customer --</option>
                      {customers.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name} {c.phone ? `(${c.phone})` : ''}
                        </option>
                      ))}
                    </select>
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
                      {selectedProducts.length} service{selectedProducts.length === 1 ? '' : 's'} selected
                    </span>
                  </div>
                </div>
                <div className="v2-section-price-badge">
                  <span className="v2-section-price-label">Total:</span>
                  <span className="v2-section-price-amount">${totalPrice.toFixed(2)}</span>
                </div>
              </div>

              <div className="v2-section-content">
                <div className="v2-services-picker-grid">
                  {products.map((p) => {
                    const isSel = selectedProductIds.includes(p.id);
                    return (
                      <div
                        key={p.id}
                        className={`v2-service-pick-chip ${isSel ? 'v2-service-pick-chip--selected' : ''}`}
                        onClick={() => handleToggleProduct(p.id)}
                      >
                        <div className="v2-service-pick-chip__left">
                          <span
                            className={`v2-service-pick-chip__check ${
                              isSel ? 'v2-service-pick-chip__check--checked' : ''
                            }`}
                          >
                            {isSel && <Check size={12} />}
                          </span>
                          <span className="v2-service-pick-chip__name">{p.name}</span>
                        </div>
                        <span className="v2-service-pick-chip__price">
                          ${Number(p.price).toFixed(2)}
                        </span>
                      </div>
                    );
                  })}
                </div>
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
              className={`v2-filter-tab-btn ${
                filterStatus === 'available' ? 'v2-filter-tab-btn--active' : ''
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
  onStatusChange: (newStatus: AppointmentStatus) => void;
  onDelete: () => void;
}

function AppointmentDetailsV2Modal({
  appt,
  timeFormat,
  onClose,
  onStartService,
  onStatusChange,
  onDelete,
}: AppointmentDetailsV2ModalProps) {
  const statusMeta = getStatusMeta(appt.status);

  return (
    <div className="v2-modal-overlay" onClick={onClose}>
      <div className="v2-modal" style={{ maxWidth: 560 }} onClick={(e) => e.stopPropagation()}>
        <div className="v2-modal__header">
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <h3 className="v2-modal__title">Appointment #{appt.id}</h3>
            <span className={`v2-status-pill v2-status-pill--${statusMeta.key}`}>
              {statusMeta.label}
            </span>
          </div>
          <button type="button" className="v2-modal__close-btn" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        <div className="v2-modal__body">
          <div className="v2-slot-details-grid">
            <div className="v2-detail-item">
              <span className="v2-detail-label">Customer</span>
              <span className="v2-detail-value">{appt.customer_name || 'Walk-in Guest'}</span>
            </div>
            <div className="v2-detail-item">
              <span className="v2-detail-label">Phone</span>
              <span className="v2-detail-value">{appt.customer_phone || 'None'}</span>
            </div>
            <div className="v2-detail-item">
              <span className="v2-detail-label">Staff</span>
              <span className="v2-detail-value">{appt.staff_name}</span>
            </div>
            <div className="v2-detail-item">
              <span className="v2-detail-label">Date</span>
              <span className="v2-detail-value">{formatDatePretty(appt.appointment_date)}</span>
            </div>
            <div className="v2-detail-item">
              <span className="v2-detail-label">Time</span>
              <span className="v2-detail-value">
                {formatTimeSlotLabel(appt.start_time, appt.end_time, timeFormat)}
              </span>
            </div>
            <div className="v2-detail-item">
              <span className="v2-detail-label">Total Amount</span>
              <span className="v2-detail-value">
                ${Number(appt.total_amount || 0).toFixed(2)}
              </span>
            </div>
          </div>

          {/* Services list */}
          <div className="v2-field-group">
            <label className="v2-field-label">Services Included</label>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {(appt.services || []).length > 0 ? (
                appt.services.map((s, idx) => (
                  <div
                    key={idx}
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      padding: '8px 12px',
                      background: '#f8fafc',
                      borderRadius: 6,
                      fontSize: 13,
                    }}
                  >
                    <span>{s.name || s.product_name}</span>
                    <span style={{ fontWeight: 600 }}>${Number(s.price || 0).toFixed(2)}</span>
                  </div>
                ))
              ) : (
                <span style={{ fontSize: 13, color: '#64748b' }}>General Service</span>
              )}
            </div>
          </div>

          {appt.notes && (
            <div className="v2-field-group">
              <label className="v2-field-label">Appointment Notes</label>
              <p style={{ margin: 0, fontSize: 13, color: '#334155', background: '#f8fafc', padding: 10, borderRadius: 6 }}>
                {appt.notes}
              </p>
            </div>
          )}

          {/* Status Change Controls */}
          <div className="v2-field-group">
            <label className="v2-field-label">Change Status</label>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button
                type="button"
                className="v2-btn v2-btn--secondary"
                style={{ fontSize: 12, padding: '5px 10px' }}
                onClick={() => onStatusChange('booked')}
              >
                Mark Booked
              </button>
              <button
                type="button"
                className="v2-btn v2-btn--secondary"
                style={{ fontSize: 12, padding: '5px 10px', color: '#b45309' }}
                onClick={() => onStatusChange('in_service')}
              >
                In Service
              </button>
              <button
                type="button"
                className="v2-btn v2-btn--secondary"
                style={{ fontSize: 12, padding: '5px 10px', color: '#047857' }}
                onClick={() => onStatusChange('completed')}
              >
                Completed
              </button>
              <button
                type="button"
                className="v2-btn v2-btn--secondary"
                style={{ fontSize: 12, padding: '5px 10px', color: '#b91c1c' }}
                onClick={() => onStatusChange('no_show')}
              >
                No Show
              </button>
              <button
                type="button"
                className="v2-btn v2-btn--secondary"
                style={{ fontSize: 12, padding: '5px 10px', color: '#64748b' }}
                onClick={() => onStatusChange('cancelled')}
              >
                Cancelled
              </button>
            </div>
          </div>
        </div>

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
              <button type="button" className="v2-btn v2-btn--primary" onClick={onStartService}>
                <Play size={15} />
                <span>Start Service</span>
              </button>
            )}
            <button type="button" className="v2-btn v2-btn--secondary" onClick={onClose}>
              Done
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

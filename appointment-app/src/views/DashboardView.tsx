import { useState, useEffect, useCallback, useMemo } from 'react';
import {
  Calendar,
  Receipt,
  Users,
  Banknote,
  ShoppingCart,
  History,
  FolderTree,
  Package,
  Sliders,
  Store,
  RefreshCw,
  Clock,
  ChevronRight,
  Plus,
  CalendarCheck,
} from 'lucide-react';
import { useAppSelector } from '../store/hooks';
import { appointmentApi, type Appointment } from '../api/appointmentApi';
import { staffApi, type Staff } from '../api/staffApi';
import { saleApi, type Sale } from '../api/saleApi';

interface DashboardViewProps {
  onNavigate: (index: number) => void;
}

/* ── Safe Currency & Date Helpers ─────────────────────────── */
const fmtMoney = (val: number | string | null | undefined): string => {
  if (val === null || val === undefined) return '0.00';
  const num = typeof val === 'number' ? val : parseFloat(String(val));
  return isNaN(num) ? '0.00' : num.toFixed(2);
};

const formatTime12 = (time24?: string): string => {
  if (!time24) return '--:--';
  const parts = time24.split(':');
  if (parts.length < 2) return time24;
  let h = parseInt(parts[0], 10);
  const m = parts[1];
  if (isNaN(h)) return time24;
  const ampm = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  if (h === 0) h = 12;
  return `${h}:${m} ${ampm}`;
};

const getTodayDateStr = (): string => {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

const normalizeDateStr = (dateVal: any): string => {
  if (!dateVal) return '';
  const str = String(dateVal).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(str)) return str;
  const dt = new Date(dateVal);
  if (isNaN(dt.getTime())) return str.split('T')[0];
  const y = dt.getFullYear();
  const m = String(dt.getMonth() + 1).padStart(2, '0');
  const d = String(dt.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

const getStatusBadge = (status: string) => {
  switch (status.toLowerCase()) {
    case 'in_service':
    case 'inservice':
      return { label: 'In Service', className: 'dash-status-badge--in_service' };
    case 'completed':
      return { label: 'Completed', className: 'dash-status-badge--completed' };
    case 'no_show':
    case 'noshow':
      return { label: 'No Show', className: 'dash-status-badge--no_show' };
    case 'cancelled':
    case 'canceled':
      return { label: 'Cancelled', className: 'dash-status-badge--cancelled' };
    case 'booked':
    default:
      return { label: 'Booked', className: 'dash-status-badge--booked' };
  }
};

const getServicesSummary = (appt: Appointment): string => {
  if (!appt.services || appt.services.length === 0) return 'General Service';
  const names = appt.services
    .map((s) => s.name || s.product_name)
    .filter(Boolean) as string[];
  if (names.length === 0) return 'General Service';
  if (names.length === 1) return names[0];
  return `${names[0]} (+${names.length - 1} more)`;
};

export default function DashboardView({ onNavigate }: DashboardViewProps) {
  const business = useAppSelector((s) => s.auth.business);

  const businessName =
    business?.business_name?.trim() || 'IQ Unified Terminal';
  const ownerName =
    business?.owner_name?.trim() || 'Store Administrator';
  const businessType =
    business?.business_type?.trim() || 'Unified Retail & Appointments';

  /* ── Dynamic API State ──────────────────────────────────── */
  const [todayAppointments, setTodayAppointments] = useState<Appointment[]>([]);
  const [staffList, setStaffList] = useState<Staff[]>([]);
  const [normalSales, setNormalSales] = useState<Sale[]>([]);
  const [completedAppointments, setCompletedAppointments] = useState<Appointment[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isRefreshing, setIsRefreshing] = useState<boolean>(false);

  const todayStr = useMemo(() => getTodayDateStr(), []);
  const formattedTodayDate = useMemo(() => {
    return new Date().toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'long',
      day: 'numeric',
      year: 'numeric',
    });
  }, []);

  /* ── Data Fetcher ───────────────────────────────────────── */
  const fetchDashboardData = useCallback(async (isManualRefresh = false) => {
    if (isManualRefresh) {
      setIsRefreshing(true);
    } else {
      setIsLoading(true);
    }

    try {
      const [apptsRes, staffRes, salesRes, completedRes] = await Promise.all([
        appointmentApi.getAppointments({ date: todayStr }),
        staffApi.getAll(false),
        saleApi.getAll(),
        appointmentApi.getAppointments({ status: 'completed' }),
      ]);

      if (apptsRes.data && apptsRes.data.data) {
        // Sort today's appointments by start_time ascending
        const sortedAppts = [...apptsRes.data.data].sort((a, b) =>
          (a.start_time || '').localeCompare(b.start_time || '')
        );
        setTodayAppointments(sortedAppts);
      }

      if (staffRes.data && staffRes.data.data) {
        setStaffList(staffRes.data.data);
      }

      if (salesRes.data && salesRes.data.data) {
        // Only normal POS/cart transactions (appointment_id is null or 0)
        const posOnly = salesRes.data.data.filter(
          (s) => !s.appointment_id || s.appointment_id === 0
        );
        setNormalSales(posOnly);
      }

      if (completedRes.data && completedRes.data.data) {
        setCompletedAppointments(completedRes.data.data);
      }
    } catch (err) {
      console.error('Failed to fetch dashboard data:', err);
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  }, [todayStr]);

  useEffect(() => {
    fetchDashboardData(false);
  }, [fetchDashboardData]);

  /* ── Dynamic Calculations ───────────────────────────────── */
  const todayInServiceCount = useMemo(
    () =>
      todayAppointments.filter(
        (a) =>
          a.status.toLowerCase() === 'in_service' ||
          a.status.toLowerCase() === 'inservice'
      ).length,
    [todayAppointments]
  );

  const todayCompletedCount = useMemo(
    () =>
      todayAppointments.filter((a) => a.status.toLowerCase() === 'completed')
        .length,
    [todayAppointments]
  );

  const activeStaffCount = useMemo(() => {
    return staffList.filter(
      (s) => s.is_active === 1 || s.is_active === true || s.is_active === undefined
    ).length;
  }, [staffList]);

  // Total amount from normal POS sales
  const normalSalesTotal = useMemo(() => {
    return normalSales.reduce(
      (sum, s) => sum + (Number(s.total_amount) || 0),
      0
    );
  }, [normalSales]);

  // Normal sales amount for today
  const todayNormalSalesTotal = useMemo(() => {
    return normalSales
      .filter((s) => normalizeDateStr(s.created_at) === todayStr)
      .reduce((sum, s) => sum + (Number(s.total_amount) || 0), 0);
  }, [normalSales, todayStr]);

  // Total amount from completed appointments
  const appointmentSalesTotal = useMemo(() => {
    return completedAppointments.reduce(
      (sum, a) => sum + (Number(a.total_amount) || 0),
      0
    );
  }, [completedAppointments]);

  // Appointment sales for today
  const todayAppointmentSalesTotal = useMemo(() => {
    return completedAppointments
      .filter((a) => normalizeDateStr(a.appointment_date) === todayStr)
      .reduce((sum, a) => sum + (Number(a.total_amount) || 0), 0);
  }, [completedAppointments, todayStr]);

  /* ── Dynamic KPI Cards ──────────────────────────────────── */
  const kpis = [
    {
      title: "Today's Appointments",
      value: isLoading ? '...' : `${todayAppointments.length} Scheduled`,
      sub:
        todayAppointments.length === 0
          ? 'No sessions today'
          : `${todayInServiceCount} in service • ${todayCompletedCount} completed`,
      icon: Calendar,
      color: 'var(--primary)',
      bg: 'rgba(180, 41, 7, 0.12)',
      tabIndex: 1,
    },
    {
      title: 'Total Staff',
      value: isLoading ? '...' : `${activeStaffCount} On Duty`,
      sub: `${staffList.length} registered clinicians`,
      icon: Users,
      color: 'var(--tertiary)',
      bg: 'rgba(0, 108, 73, 0.12)',
      tabIndex: 2,
    },
    {
      title: 'Normal Sales',
      value: isLoading ? '...' : `$${fmtMoney(normalSalesTotal)}`,
      sub: `${normalSales.length} orders tendered • $${fmtMoney(todayNormalSalesTotal)} today`,
      icon: Receipt,
      color: 'var(--secondary)',
      bg: 'rgba(133, 83, 0, 0.12)',
      tabIndex: 5,
    },
    {
      title: 'Appointment Sales',
      value: isLoading ? '...' : `$${fmtMoney(appointmentSalesTotal)}`,
      sub: `${completedAppointments.length} sessions done • $${fmtMoney(todayAppointmentSalesTotal)} today`,
      icon: Banknote,
      color: '#4338CA',
      bg: 'rgba(67, 56, 202, 0.12)',
      tabIndex: 3,
    },
  ];

  /* ── Operations Shortcuts ───────────────────────────────── */
  const operations = [
    {
      id: 1,
      title: 'Appointments',
      desc: 'Manage daily schedule',
      icon: Calendar,
      color: 'var(--primary)',
      bg: 'rgba(180, 41, 7, 0.12)',
    },
    {
      id: 2,
      title: 'Staff Directory',
      desc: 'Clinicians & groomers',
      icon: Users,
      color: 'var(--secondary)',
      bg: 'rgba(133, 83, 0, 0.12)',
    },
    {
      id: 3,
      title: 'Appointment History',
      desc: 'Completed logs & reports',
      icon: History,
      color: 'var(--tertiary)',
      bg: 'rgba(0, 108, 73, 0.12)',
    },
    {
      id: 4,
      title: 'POS Cart',
      desc: 'Checkout & Tender',
      icon: ShoppingCart,
      color: '#4338CA',
      bg: 'rgba(67, 56, 202, 0.12)',
    },
    {
      id: 5,
      title: 'Sales History',
      desc: 'Cart orders & receipts',
      icon: Receipt,
      color: '#D97706',
      bg: 'rgba(217, 119, 6, 0.12)',
    },
    {
      id: 6,
      title: 'Categories',
      desc: 'Custom domain manager',
      icon: FolderTree,
      color: '#7C3AED',
      bg: 'rgba(124, 58, 237, 0.12)',
    },
    {
      id: 7,
      title: 'Products & Combos',
      desc: 'Catalog & modifier items',
      icon: Package,
      color: '#0D9488',
      bg: 'rgba(13, 148, 136, 0.12)',
    },
    {
      id: 8,
      title: 'Appointment Config',
      desc: 'Hours & interval settings',
      icon: Sliders,
      color: '#475569',
      bg: 'rgba(71, 85, 105, 0.12)',
    },
  ];

  return (
    <div className="dashboard-view">
      {/* 1. Hero Welcome Banner */}
      <section className="dashboard-hero-banner">
        <div>
          <span className="dashboard-hero__badge">
            Live Terminal Operations • Station #01
          </span>
          <h1 className="dashboard-hero__title">{businessName}</h1>
          <p className="dashboard-hero__meta">
            Manager: {ownerName} • Category: {businessType}
          </p>
        </div>
        <button
          type="button"
          className="dashboard-hero__action-btn"
          onClick={() => onNavigate(4)}
        >
          <Store size={18} />
          <span>Open Register / Cart</span>
        </button>
      </section>

      {/* 2. Dynamic KPI Summary Counters */}
      <section className="dashboard-kpi-grid">
        {kpis.map((kpi, idx) => {
          const Icon = kpi.icon;
          return (
            <div
              key={idx}
              className="kpi-card kpi-card--clickable"
              onClick={() => onNavigate(kpi.tabIndex)}
              title={`Click to open ${kpi.title}`}
            >
              <div className="kpi-card__top">
                <span className="kpi-card__title">{kpi.title}</span>
                <div
                  className="kpi-card__icon-box"
                  style={{ backgroundColor: kpi.bg, color: kpi.color }}
                >
                  <Icon size={18} />
                </div>
              </div>
              <div className="kpi-card__value">{kpi.value}</div>
              <div className="kpi-card__sub">{kpi.sub}</div>
            </div>
          );
        })}
      </section>

      {/* 3. Today's Appointments List Section */}
      <section className="dashboard-appts-card">
        <div className="dashboard-appts-card__header">
          <div className="dashboard-appts-card__header-left">
            <div className="dashboard-appts-card__title-row">
              <h2 className="dashboard-section-title">Today's Appointments</h2>
              <span className="dashboard-appts-badge">
                {isLoading ? '...' : `${todayAppointments.length} Scheduled`}
              </span>
            </div>
            <p className="dashboard-appts-card__subtitle">
              {formattedTodayDate} • {todayInServiceCount} in service •{' '}
              {todayCompletedCount} completed
            </p>
          </div>
          <div className="dashboard-appts-card__header-right">
            <button
              type="button"
              className="dashboard-icon-btn"
              onClick={() => fetchDashboardData(true)}
              disabled={isLoading || isRefreshing}
              title="Refresh dashboard data"
            >
              <RefreshCw
                size={16}
                className={isRefreshing ? 'spin-anim' : ''}
              />
            </button>
            <button
              type="button"
              className="dashboard-secondary-btn"
              onClick={() => onNavigate(1)}
            >
              <Calendar size={16} />
              <span>Open Timetable</span>
            </button>
          </div>
        </div>

        {/* Content State */}
        {isLoading ? (
          <div className="dashboard-appts-loading">
            <div className="dashboard-spinner" />
            <span>Fetching today's appointments & live stats...</span>
          </div>
        ) : todayAppointments.length === 0 ? (
          <div className="dashboard-appts-empty">
            <div className="dashboard-appts-empty__icon">
              <CalendarCheck size={28} />
            </div>
            <h3>No Appointments Scheduled For Today</h3>
            <p>
              There are no appointments on the calendar for {formattedTodayDate}.
            </p>
            <button
              type="button"
              className="dashboard-cta-btn"
              onClick={() => onNavigate(1)}
            >
              <Plus size={16} />
              <span>Book An Appointment</span>
            </button>
          </div>
        ) : (
          <>
            {/* Desktop Table View */}
            <div className="dashboard-appts-table-wrapper">
              <table className="dashboard-appts-table">
                <thead>
                  <tr>
                    <th>Time Slot</th>
                    <th>Customer</th>
                    <th>Staff Member</th>
                    <th>Services</th>
                    <th>Status</th>
                    <th>Total</th>
                    <th style={{ textAlign: 'right' }}>Schedule</th>
                  </tr>
                </thead>
                <tbody>
                  {todayAppointments.map((appt) => {
                    const statusInfo = getStatusBadge(appt.status);
                    return (
                      <tr
                        key={appt.id}
                        className="dashboard-appts-row"
                        onClick={() => onNavigate(1)}
                        title="Click to view in Appointments calendar"
                      >
                        <td>
                          <div className="appt-time-pill">
                            <Clock size={13} />
                            <span>
                              {formatTime12(appt.start_time)} -{' '}
                              {formatTime12(appt.end_time)}
                            </span>
                          </div>
                        </td>
                        <td>
                          <div className="appt-customer-info">
                            <span className="appt-customer-name">
                              {appt.customer_name || 'Walk-in Guest'}
                            </span>
                            {appt.customer_phone && (
                              <span className="appt-customer-phone">
                                {appt.customer_phone}
                              </span>
                            )}
                          </div>
                        </td>
                        <td>
                          <div className="appt-staff-pill">
                            <span className="appt-staff-dot" />
                            <span>{appt.staff_name || 'Unassigned'}</span>
                          </div>
                        </td>
                        <td>
                          <div
                            className="appt-services-text"
                            title={getServicesSummary(appt)}
                          >
                            {getServicesSummary(appt)}
                          </div>
                        </td>
                        <td>
                          <span
                            className={`dash-status-badge ${statusInfo.className}`}
                          >
                            {statusInfo.label}
                          </span>
                        </td>
                        <td>
                          <span className="appt-amount-val">
                            ${fmtMoney(appt.total_amount)}
                          </span>
                        </td>
                        <td style={{ textAlign: 'right' }}>
                          <button
                            type="button"
                            className="appt-action-link"
                            onClick={(e) => {
                              e.stopPropagation();
                              onNavigate(1);
                            }}
                          >
                            <span>Open</span>
                            <ChevronRight size={14} />
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {/* Mobile Responsive Cards List */}
            <div className="dashboard-appts-mobile-list">
              {todayAppointments.map((appt) => {
                const statusInfo = getStatusBadge(appt.status);
                return (
                  <div
                    key={appt.id}
                    className="dash-mobile-appt-card"
                    onClick={() => onNavigate(1)}
                    title="Click to view in Appointments calendar"
                  >
                    <div className="dash-mobile-appt-card__top">
                      <div className="appt-time-pill">
                        <Clock size={12} />
                        <span>
                          {formatTime12(appt.start_time)} -{' '}
                          {formatTime12(appt.end_time)}
                        </span>
                      </div>
                      <span
                        className={`dash-status-badge ${statusInfo.className}`}
                      >
                        {statusInfo.label}
                      </span>
                    </div>

                    <div className="dash-mobile-appt-card__body">
                      <div className="dash-mobile-appt-card__customer">
                        <span className="appt-customer-name">
                          {appt.customer_name || 'Walk-in Guest'}
                        </span>
                        {appt.customer_phone && (
                          <span className="appt-customer-phone">
                            {appt.customer_phone}
                          </span>
                        )}
                      </div>
                      <div className="appt-staff-pill">
                        <span className="appt-staff-dot" />
                        <span>{appt.staff_name || 'Unassigned'}</span>
                      </div>
                    </div>

                    <div className="dash-mobile-appt-card__services">
                      <span className="dash-mobile-appt-card__services-label">
                        Services:
                      </span>
                      <span className="dash-mobile-appt-card__services-val">
                        {getServicesSummary(appt)}
                      </span>
                    </div>

                    <div className="dash-mobile-appt-card__bottom">
                      <div className="dash-mobile-appt-card__price">
                        <span className="dash-mobile-appt-card__price-label">
                          Total:
                        </span>
                        <span className="appt-amount-val">
                          ${fmtMoney(appt.total_amount)}
                        </span>
                      </div>
                      <div className="dash-mobile-appt-card__link">
                        <span>View Schedule</span>
                        <ChevronRight size={14} />
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        )}
      </section>

      {/* 4. Terminal Operations Navigation */}
      <section>
        <h2 className="dashboard-section-title">Terminal Operations</h2>
        <div className="dashboard-ops-grid" style={{ marginTop: 14 }}>
          {operations.map((op) => {
            const Icon = op.icon;
            return (
              <button
                key={op.id}
                type="button"
                className="ops-card"
                onClick={() => onNavigate(op.id)}
              >
                <div
                  className="ops-card__icon-box"
                  style={{ backgroundColor: op.bg, color: op.color }}
                >
                  <Icon size={22} />
                </div>
                <div className="ops-card__title">{op.title}</div>
                <div className="ops-card__subtitle">{op.desc}</div>
              </button>
            );
          })}
        </div>
      </section>
    </div>
  );
}

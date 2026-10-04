import {
  Calendar,
  Receipt,
  Users,
  Building,
  ShoppingCart,
  History,
  FolderTree,
  Package,
  Sliders,
  Store,
} from 'lucide-react';
import { useAppSelector } from '../store/hooks';

interface DashboardViewProps {
  onNavigate: (index: number) => void;
}

export default function DashboardView({ onNavigate }: DashboardViewProps) {
  const business = useAppSelector((s) => s.auth.business);

  const businessName =
    business?.business_name?.trim() || 'IQ Unified Terminal';
  const ownerName =
    business?.owner_name?.trim() || 'Administrator';
  const businessType =
    business?.business_type?.trim() || 'Grooming & Clinical Suite';

  const kpis = [
    {
      title: "Today's Appointments",
      value: '14',
      sub: '4 in progress',
      icon: Calendar,
      color: 'var(--primary)',
      bg: 'rgba(180, 41, 7, 0.12)',
    },
    {
      title: 'Register Sales',
      value: '$1,840.50',
      sub: '26 orders tendered',
      icon: Receipt,
      color: 'var(--secondary)',
      bg: 'rgba(133, 83, 0, 0.12)',
    },
    {
      title: 'Active Clinicians',
      value: '3 On Duty',
      sub: '100% capacity',
      icon: Users,
      color: 'var(--tertiary)',
      bg: 'rgba(0, 108, 73, 0.12)',
    },
    {
      title: 'Suite Occupancy',
      value: '85%',
      sub: '12 of 14 rooms filled',
      icon: Building,
      color: '#C05621',
      bg: 'rgba(192, 86, 33, 0.12)',
    },
  ];

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
            Terminal Station #01 • Live Operations
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

      {/* 2. KPI Summary Counters */}
      <section className="dashboard-kpi-grid">
        {kpis.map((kpi, idx) => {
          const Icon = kpi.icon;
          return (
            <div key={idx} className="kpi-card">
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

      {/* 3. Terminal Operations */}
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

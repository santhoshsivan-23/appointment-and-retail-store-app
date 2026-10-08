import { useState, useMemo } from 'react';
import {
  Users,
  Receipt,
  FolderTree,
  Package,
  Sliders,
  Calendar,
  History,
  ShoppingCart,
  LayoutDashboard,
  LogOut,
  ChevronRight,
  Search,
  Store,
  SlidersHorizontal,
  CalendarDays,
} from 'lucide-react';
import { useAppSelector } from '../store/hooks';
import '../styles/more_options.css';

interface MoreOptionsViewProps {
  onNavigate: (index: number) => void;
  onLogoutClick: () => void;
  onSelectCartMode?: (mode: 'pos' | 'cart') => void;
}

interface OptionItem {
  id: number;
  title: string;
  desc: string;
  icon: React.ComponentType<{ size?: number; className?: string }>;
  color: string;
  bg: string;
  badge: string;
  category: 'management' | 'catalog' | 'frequent';
  action?: () => void;
}

export default function MoreOptionsView({
  onNavigate,
  onLogoutClick,
  onSelectCartMode,
}: MoreOptionsViewProps) {
  const business = useAppSelector((s) => s.auth.business);
  const [searchQuery, setSearchQuery] = useState('');

  const businessName =
    business?.business_name?.trim() || 'IQ Unified Terminal';
  const ownerName =
    business?.owner_name?.trim() || 'Store Administrator';
  const businessType =
    business?.business_type?.trim() || 'Unified Retail & Appointments';

  const allOptions: OptionItem[] = [
    // 1. Management Options (Sidebar items moved under More)
    {
      id: 2,
      title: 'Staff Directory',
      desc: 'Manage clinicians, stylists, roles & scheduling duty',
      icon: Users,
      color: '#006C49',
      bg: 'rgba(0, 108, 73, 0.12)',
      badge: 'Team',
      category: 'management',
      action: () => onNavigate(2),
    },
    {
      id: 5,
      title: 'Sales History',
      desc: 'Search & review past POS orders, receipts & tender records',
      icon: Receipt,
      color: '#D97706',
      bg: 'rgba(217, 119, 6, 0.12)',
      badge: 'Orders',
      category: 'management',
      action: () => onNavigate(5),
    },
    {
      id: 8,
      title: 'Appointment Config',
      desc: 'Business hours, appointment intervals & timetable settings',
      icon: Sliders,
      color: '#475569',
      bg: 'rgba(71, 85, 105, 0.12)',
      badge: 'Config',
      category: 'management',
      action: () => onNavigate(8),
    },

    // 2. Catalog & Inventory (Sidebar items moved under More)
    {
      id: 6,
      title: 'Categories',
      desc: 'Organize catalog categories and custom domains',
      icon: FolderTree,
      color: '#7C3AED',
      bg: 'rgba(124, 58, 237, 0.12)',
      badge: 'Catalog',
      category: 'catalog',
      action: () => onNavigate(6),
    },
    {
      id: 7,
      title: 'Products & Combos',
      desc: 'Product catalog, pricing, modifiers & service packages',
      icon: Package,
      color: '#0D9488',
      bg: 'rgba(13, 148, 136, 0.12)',
      badge: 'Inventory',
      category: 'catalog',
      action: () => onNavigate(7),
    },

    // 3. Quick Access to Primary Navigation
    {
      id: 0,
      title: 'Dashboard',
      desc: 'Live terminal overview & KPI operational statistics',
      icon: LayoutDashboard,
      color: '#B42907',
      bg: 'rgba(180, 41, 7, 0.12)',
      badge: 'Main',
      category: 'frequent',
      action: () => onNavigate(0),
    },
    {
      id: 1,
      title: 'Appointments Timetable',
      desc: 'Interactive schedule grid, staff lanes & time slots',
      icon: Calendar,
      color: '#B42907',
      bg: 'rgba(180, 41, 7, 0.12)',
      badge: 'Calendar',
      category: 'frequent',
      action: () => onNavigate(1),
    },
    {
      id: 10,
      title: 'Appointment V2 (New Layouts)',
      desc: 'Staff lanes, List, Grid & 30-min Time Slot view',
      icon: CalendarDays,
      color: '#0284C7',
      bg: 'rgba(2, 132, 199, 0.12)',
      badge: 'V2',
      category: 'frequent',
      action: () => onNavigate(10),
    },
    {
      id: 3,
      title: 'Appointment History',
      desc: 'Completed appointment sessions and clinical reports',
      icon: History,
      color: '#006C49',
      bg: 'rgba(0, 108, 73, 0.12)',
      badge: 'Reports',
      category: 'frequent',
      action: () => onNavigate(3),
    },
    {
      id: 4,
      title: 'POS Cart & Register',
      desc: 'Open register for tenders, barcode items & checkout',
      icon: ShoppingCart,
      color: '#4338CA',
      bg: 'rgba(67, 56, 202, 0.12)',
      badge: 'Checkout',
      category: 'frequent',
      action: () => {
        onSelectCartMode?.('pos');
        onNavigate(4);
      },
    },
  ];

  const filteredOptions = useMemo(() => {
    if (!searchQuery.trim()) return allOptions;
    const q = searchQuery.toLowerCase().trim();
    return allOptions.filter(
      (opt) =>
        opt.title.toLowerCase().includes(q) ||
        opt.desc.toLowerCase().includes(q) ||
        opt.badge.toLowerCase().includes(q)
    );
  }, [allOptions, searchQuery]);

  const managementOptions = useMemo(
    () => filteredOptions.filter((o) => o.category === 'management'),
    [filteredOptions]
  );

  const catalogOptions = useMemo(
    () => filteredOptions.filter((o) => o.category === 'catalog'),
    [filteredOptions]
  );

  const frequentOptions = useMemo(
    () => filteredOptions.filter((o) => o.category === 'frequent'),
    [filteredOptions]
  );

  return (
    <div className="more-options-page">
      {/* 1. Header Banner */}
      <div className="more-options-header">
        <div className="more-options-header__title-row">
          <div className="more-options-header__icon-box">
            <SlidersHorizontal size={20} />
          </div>
          <div>
            <h1 className="more-options-header__title">More Options</h1>
            <p className="more-options-header__sub">
              Access all secondary terminal tools, catalogs & settings
            </p>
          </div>
        </div>

        {/* Search bar */}
        <div className="more-options-search">
          <Search size={16} className="more-options-search__icon" />
          <input
            type="text"
            className="more-options-search__input"
            placeholder="Search tools, options or settings..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
          {searchQuery && (
            <button
              type="button"
              className="more-options-search__clear"
              onClick={() => setSearchQuery('')}
            >
              ×
            </button>
          )}
        </div>
      </div>

      {/* 2. Operations & Management Section */}
      {managementOptions.length > 0 && (
        <section className="more-options-section">
          <div className="more-options-section__title">
            <span>Management & Administration</span>
            <span className="more-options-section__count">
              {managementOptions.length}
            </span>
          </div>
          <div className="more-options-list">
            {managementOptions.map((opt) => {
              const Icon = opt.icon;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="more-option-card"
                  onClick={opt.action}
                >
                  <div
                    className="more-option-card__icon"
                    style={{ backgroundColor: opt.bg, color: opt.color }}
                  >
                    <Icon size={22} />
                  </div>
                  <div className="more-option-card__content">
                    <div className="more-option-card__top">
                      <span className="more-option-card__title">
                        {opt.title}
                      </span>
                      <span className="more-option-card__badge">
                        {opt.badge}
                      </span>
                    </div>
                    <p className="more-option-card__desc">{opt.desc}</p>
                  </div>
                  <div className="more-option-card__chevron">
                    <ChevronRight size={18} />
                  </div>
                </button>
              );
            })}
          </div>
        </section>
      )}

      {/* 3. Catalog & Inventory Section */}
      {catalogOptions.length > 0 && (
        <section className="more-options-section">
          <div className="more-options-section__title">
            <span>Catalog & Inventory Management</span>
            <span className="more-options-section__count">
              {catalogOptions.length}
            </span>
          </div>
          <div className="more-options-list">
            {catalogOptions.map((opt) => {
              const Icon = opt.icon;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="more-option-card"
                  onClick={opt.action}
                >
                  <div
                    className="more-option-card__icon"
                    style={{ backgroundColor: opt.bg, color: opt.color }}
                  >
                    <Icon size={22} />
                  </div>
                  <div className="more-option-card__content">
                    <div className="more-option-card__top">
                      <span className="more-option-card__title">
                        {opt.title}
                      </span>
                      <span className="more-option-card__badge">
                        {opt.badge}
                      </span>
                    </div>
                    <p className="more-option-card__desc">{opt.desc}</p>
                  </div>
                  <div className="more-option-card__chevron">
                    <ChevronRight size={18} />
                  </div>
                </button>
              );
            })}
          </div>
        </section>
      )}

      {/* 4. Primary Shortcuts (when searching or for quick jump) */}
      {frequentOptions.length > 0 && (
        <section className="more-options-section">
          <div className="more-options-section__title">
            <span>Core Navigation Shortcuts</span>
            <span className="more-options-section__count">
              {frequentOptions.length}
            </span>
          </div>
          <div className="more-options-list">
            {frequentOptions.map((opt) => {
              const Icon = opt.icon;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="more-option-card"
                  onClick={opt.action}
                >
                  <div
                    className="more-option-card__icon"
                    style={{ backgroundColor: opt.bg, color: opt.color }}
                  >
                    <Icon size={22} />
                  </div>
                  <div className="more-option-card__content">
                    <div className="more-option-card__top">
                      <span className="more-option-card__title">
                        {opt.title}
                      </span>
                      <span className="more-option-card__badge">
                        {opt.badge}
                      </span>
                    </div>
                    <p className="more-option-card__desc">{opt.desc}</p>
                  </div>
                  <div className="more-option-card__chevron">
                    <ChevronRight size={18} />
                  </div>
                </button>
              );
            })}
          </div>
        </section>
      )}

      {/* 5. Station Session Card */}
      <section className="more-options-section">
        <div className="more-options-section__title">
          <span>Terminal Station & Account</span>
        </div>
        <div className="more-session-card">
          <div className="more-session-card__info">
            <div className="more-session-card__icon">
              <Store size={22} />
            </div>
            <div>
              <div className="more-session-card__name">{businessName}</div>
              <div className="more-session-card__meta">
                {ownerName} • {businessType}
              </div>
            </div>
          </div>
          <button
            type="button"
            className="more-signout-btn"
            onClick={onLogoutClick}
          >
            <LogOut size={16} />
            <span>Sign Out Terminal</span>
          </button>
        </div>
      </section>
    </div>
  );
}

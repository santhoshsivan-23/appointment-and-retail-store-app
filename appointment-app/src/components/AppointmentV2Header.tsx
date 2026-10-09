import { useState, useEffect } from 'react';
import { Search, X, RefreshCw, Phone } from 'lucide-react';
import type { Staff } from '../api/staffApi';
import { customerApi, type Customer } from '../api/customerApi';
import { formatDatePretty, getTodayDateStr } from '../utils/appointmentV2Utils';

export interface AppointmentV2HeaderProps {
  selectedStaff: Staff;
  staffBg: string;
  staffInitials: string;
  selectedDate: string;
  viewMode: 'list' | 'grid' | 'time';
  isLoadingAppts: boolean;
  onSwitchStaff: () => void;
  onViewModeChange: (mode: 'list' | 'grid' | 'time') => void;
  onOpenFilterModal: () => void;
  onRefresh: () => void;
  onOpenAddModal: () => void;
  onSelectCustomerToBook: (customer: Customer) => void;
}

export default function AppointmentV2Header({
  selectedStaff,
  staffBg,
  staffInitials,
  selectedDate,
  viewMode,
  isLoadingAppts,
  onSwitchStaff,
  onViewModeChange,
  onOpenFilterModal,
  onRefresh,
  onOpenAddModal,
  onSelectCustomerToBook,
}: AppointmentV2HeaderProps) {
  // Quick Customer Search in the Top Header
  const [pageCustomerSearch, setPageCustomerSearch] = useState<string>('');
  const [pageCustomerResults, setPageCustomerResults] = useState<Customer[]>([]);
  const [isSearchingPageCustomers, setIsSearchingPageCustomers] = useState<boolean>(false);
  const [showPageCustomerDropdown, setShowPageCustomerDropdown] = useState<boolean>(false);

  useEffect(() => {
    if (!pageCustomerSearch.trim()) {
      setPageCustomerResults([]);
      return;
    }
    const timer = setTimeout(async () => {
      setIsSearchingPageCustomers(true);
      try {
        const res = await customerApi.getAll(pageCustomerSearch.trim());
        if (res.data?.data) {
          setPageCustomerResults(res.data.data);
        }
      } catch (err) {
        console.error('Failed to search customers:', err);
      } finally {
        setIsSearchingPageCustomers(false);
      }
    }, 250);

    return () => clearTimeout(timer);
  }, [pageCustomerSearch]);

  const isToday = selectedDate === getTodayDateStr();

  const [headerImgError, setHeaderImgError] = useState(false);
  useEffect(() => {
    setHeaderImgError(false);
  }, [selectedStaff.id, selectedStaff.image]);

  const hasHeaderImg = Boolean(
    selectedStaff.image && selectedStaff.image.trim().length > 0 && !headerImgError
  );

  return (
    <header
      className="appointment-v2-fixed-header bg-white rounded-2xl border border-sage-200/80 shadow-[0_2px_10px_-4px_rgba(6,78,59,0.05)] p-3 mb-3 flex-shrink-0 z-20 sticky top-0"
      data-purpose="top-navigation-bar"
    >
      <div className="flex flex-wrap items-center justify-between gap-4">
        {/* Left Controls: Staff & Date Selector */}
        <div className="flex flex-wrap items-center gap-3">
          {/* Staff Selector Chip */}
          <div
            className="v2-staff-pill inline-flex items-center gap-2.5 bg-slate-50 border border-slate-200 px-3 py-1.5 rounded-xl text-sm font-medium"
            data-purpose="staff-pill"
          >
            <div
              className="v2-staff-pill__avatar"
              style={{
                width: '30px',
                height: '30px',
                minWidth: '30px',
                minHeight: '30px',
                maxWidth: '30px',
                maxHeight: '30px',
                borderRadius: '50%',
                overflow: 'hidden',
                flexShrink: 0,
                backgroundColor: staffBg,
              }}
            >
              {hasHeaderImg ? (
                <img
                  src={selectedStaff.image!}
                  alt={selectedStaff.name}
                  className="v2-staff-pill__avatar-img"
                  style={{
                    width: '100%',
                    height: '100%',
                    maxWidth: '100%',
                    maxHeight: '100%',
                    objectFit: 'cover',
                    display: 'block',
                    borderRadius: '50%',
                  }}
                  onError={() => setHeaderImgError(true)}
                />
              ) : (
                <span
                  className="staff-pill-fallback"
                  style={{
                    fontSize: '11px',
                    fontWeight: 700,
                    color: '#ffffff',
                    userSelect: 'none',
                  }}
                >
                  {staffInitials}
                </span>
              )}
            </div>
            <span className="font-semibold text-gray-800">{selectedStaff.name}</span>
            <button
              className="v2-staff-switch-btn text-xs text-blue-600 hover:text-blue-800 font-medium px-2 py-0.5 rounded-md hover:bg-blue-50 transition-colors"
              type="button"
              onClick={onSwitchStaff}
            >
              Switch Staff
            </button>
          </div>

          {/* Date Display Pill */}
          <div
            className="inline-flex items-center gap-2.5 bg-white border border-slate-200 px-3.5 py-1.5 rounded-xl text-sm shadow-sm"
            data-purpose="current-date-picker"
          >
            <svg
              className="w-4 h-4 text-blue-600"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              viewBox="0 0 24 24"
            >
              <rect height="18" rx="2" ry="2" width="18" x="3" y="4" />
              <line x1="16" x2="16" y1="2" y2="6" />
              <line x1="8" x2="8" y1="2" y2="6" />
              <line x1="3" x2="21" y1="10" y2="10" />
            </svg>
            <span className="font-semibold text-gray-800">
              {formatDatePretty(selectedDate)}
            </span>
            {isToday && (
              <span className="bg-emerald-100 text-emerald-800 text-[11px] font-semibold px-2 py-0.5 rounded-full border border-emerald-200">
                Today
              </span>
            )}
          </div>
        </div>

        {/* Right Controls: View Switcher, Filter, Refresh, Search & Add Appointment */}
        <div className="flex flex-wrap items-center gap-3">
          {/* View Modes (List / Grid / Time) */}
          <div
            className="flex items-center bg-slate-50 border border-slate-200 p-1 rounded-xl text-sm"
            data-purpose="view-mode-toggle"
          >
            <button
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-lg text-xs font-medium transition ${
                viewMode === 'list'
                  ? 'bg-rose-50/70 text-rose-700 font-semibold shadow-sm border-2 border-rose-600'
                  : 'text-rose-600 hover:bg-rose-50 hover:text-rose-700 border border-transparent'
              }`}
              type="button"
              onClick={() => onViewModeChange('list')}
            >
              <span className="w-1.5 h-1.5 rounded-full bg-rose-600" />
              <svg
                className="w-3.5 h-3.5 text-rose-600"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                viewBox="0 0 24 24"
              >
                <line x1="8" x2="21" y1="6" y2="6" />
                <line x1="8" x2="21" y1="12" y2="12" />
                <line x1="8" x2="21" y1="18" y2="18" />
                <line x1="3" x2="3.01" y1="6" y2="6" />
                <line x1="3" x2="3.01" y1="12" y2="12" />
                <line x1="3" x2="3.01" y1="18" y2="18" />
              </svg>
              List
            </button>
            <button
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-lg text-xs font-medium transition ${
                viewMode === 'grid'
                  ? 'bg-emerald-50/70 text-emerald-700 font-semibold shadow-sm border-2 border-emerald-600'
                  : 'text-emerald-600 hover:bg-emerald-50 hover:text-emerald-700 border border-transparent'
              }`}
              type="button"
              onClick={() => onViewModeChange('grid')}
            >
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-600" />
              <svg
                className="w-3.5 h-3.5 text-emerald-600"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                viewBox="0 0 24 24"
              >
                <rect height="7" rx="1" width="7" x="3" y="3" />
                <rect height="7" rx="1" width="7" x="14" y="3" />
                <rect height="7" rx="1" width="7" x="14" y="14" />
                <rect height="7" rx="1" width="7" x="3" y="14" />
              </svg>
              Grid
            </button>
            <button
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-lg text-xs font-medium transition ${
                viewMode === 'time'
                  ? 'bg-blue-50/70 text-blue-700 font-semibold shadow-sm border-2 border-blue-600'
                  : 'text-blue-600 hover:bg-blue-50 hover:text-blue-700 border border-transparent'
              }`}
              type="button"
              onClick={() => onViewModeChange('time')}
            >
              <span className="w-1.5 h-1.5 rounded-full bg-blue-600" />
              <svg
                className="w-3.5 h-3.5 text-blue-600"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                viewBox="0 0 24 24"
              >
                <circle cx="12" cy="12" r="10" />
                <polyline points="12 6 12 12 16 14" />
              </svg>
              Time
            </button>
          </div>

          {/* Slot Filter Button */}
          <button
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-slate-200 bg-white text-gray-700 hover:text-blue-600 hover:bg-slate-50 text-xs font-medium transition shadow-sm"
            data-purpose="filter-button"
            type="button"
            onClick={onOpenFilterModal}
          >
            <svg
              className="w-3.5 h-3.5 text-gray-500"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              viewBox="0 0 24 24"
            >
              <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3" />
            </svg>
            Slot Filter
          </button>

          {/* Refresh Button */}
          <button
            aria-label="Refresh"
            className="p-2 rounded-xl border border-slate-200 bg-white text-gray-600 hover:text-blue-600 hover:bg-slate-50 transition shadow-sm"
            data-purpose="refresh-button"
            type="button"
            onClick={onRefresh}
            disabled={isLoadingAppts}
          >
            <svg
              className={`w-4 h-4 ${isLoadingAppts ? 'v2-spin' : ''}`}
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              viewBox="0 0 24 24"
            >
              <polyline points="23 4 23 10 17 10" />
              <polyline points="1 20 1 14 7 14" />
              <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
            </svg>
          </button>

          {/* Quick Customer Search on Appointment Page */}
          <div className="v2-top-search-wrap">
            <div className="v2-top-search-box">
              <Search size={14} className="text-slate-400 flex-shrink-0" />
              <input
                type="text"
                className="v2-top-search-input"
                placeholder="Search customer to book..."
                value={pageCustomerSearch}
                onChange={(e) => {
                  setPageCustomerSearch(e.target.value);
                  setShowPageCustomerDropdown(true);
                }}
                onFocus={() => {
                  if (pageCustomerSearch.trim()) setShowPageCustomerDropdown(true);
                }}
              />
              {pageCustomerSearch && (
                <button
                  type="button"
                  className="v2-top-search-clear"
                  title="Clear search"
                  onClick={() => {
                    setPageCustomerSearch('');
                    setPageCustomerResults([]);
                    setShowPageCustomerDropdown(false);
                  }}
                >
                  <X size={12} />
                </button>
              )}
            </div>

            {showPageCustomerDropdown && pageCustomerSearch.trim().length > 0 && (
              <div className="v2-top-search-dropdown">
                <div className="v2-search-dropdown-header">
                  <span>Customers ({pageCustomerResults.length})</span>
                  <span className="v2-search-dropdown-badge">Click to book</span>
                </div>
                {isSearchingPageCustomers ? (
                  <div className="v2-search-item-empty">
                    <RefreshCw size={13} className="v2-spin" />
                    <span>Searching database...</span>
                  </div>
                ) : pageCustomerResults.length === 0 ? (
                  <div className="v2-search-item-empty">
                    <span>No customers found for "{pageCustomerSearch.trim()}"</span>
                  </div>
                ) : (
                  <>
                    <div className="v2-search-dropdown-list">
                      {pageCustomerResults.map((c) => (
                        <div
                          key={c.id}
                          className="v2-top-search-item"
                          onClick={() => {
                            onSelectCustomerToBook(c);
                            setPageCustomerSearch('');
                            setShowPageCustomerDropdown(false);
                          }}
                        >
                          <div className="flex items-center gap-2.5 min-w-0">
                            <div className="w-8 h-8 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center font-bold text-xs flex-shrink-0">
                              {c.name ? c.name[0].toUpperCase() : 'C'}
                            </div>
                            <div className="min-w-0">
                              <div className="font-bold text-xs text-slate-800 truncate">
                                {c.name}
                              </div>
                              <div className="text-[11px] text-slate-400 flex items-center gap-1">
                                <Phone size={10} />
                                <span>{c.phone || 'No phone'}</span>
                              </div>
                            </div>
                          </div>
                          <span className="text-[11px] font-bold text-blue-600 bg-blue-50 px-2 py-0.5 rounded border border-blue-200">
                            Book
                          </span>
                        </div>
                      ))}
                    </div>
                    {pageCustomerResults.length > 5 && (
                      <div className="v2-search-dropdown-footer">
                        ↕ Scroll for more ({pageCustomerResults.length} customers)
                      </div>
                    )}
                  </>
                )}
              </div>
            )}
          </div>

          {/* Add Appointment CTA */}
          <button
            className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-semibold shadow-sm transition-all transform active:scale-95"
            data-purpose="primary-add-button"
            type="button"
            onClick={onOpenAddModal}
          >
            <svg
              className="w-4 h-4"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.5"
              viewBox="0 0 24 24"
            >
              <line x1="12" x2="12" y1="5" y2="19" />
              <line x1="5" x2="19" y1="12" y2="12" />
            </svg>
            Add Appointment
          </button>
        </div>
      </div>
    </header>
  );
}

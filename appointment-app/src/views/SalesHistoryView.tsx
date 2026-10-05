import { useState, useEffect, useCallback } from 'react';
import { toast } from 'react-toastify';
import {
  Receipt,
  RotateCw,
  Banknote,
  TrendingUp,
  Search,
  X,
  ChevronRight,
  ChevronLeft,
  User,
  BadgeCheck,
  Clock,
  CalendarCheck,
} from 'lucide-react';
import { saleApi, type Sale, formatReceiptNumber, getPaymentMethodLabel } from '../api/saleApi';
import '../styles/sales_history.css';

const PAGE_SIZE = 20;

/* ── Safe Currency / Number Formatter ─────────────────── */
const fmtMoney = (val: number | string | null | undefined): string => {
  if (val === null || val === undefined) return '0.00';
  const num = typeof val === 'number' ? val : parseFloat(String(val));
  return isNaN(num) ? '0.00' : num.toFixed(2);
};

export default function SalesHistoryView() {
  /* ── State ────────────────────────────────────────────── */
  const [allSales, setAllSales] = useState<Sale[]>([]);
  const [baselineSales, setBaselineSales] = useState<Sale[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isSearching, setIsSearching] = useState<boolean>(false);

  const [searchInput, setSearchInput] = useState<string>('');
  const [activeSearchQuery, setActiveSearchQuery] = useState<string>('');
  const [activeFilter, setActiveFilter] = useState<'all' | 'cash' | 'card' | 'qr'>('all');

  const [currentPage, setCurrentPage] = useState<number>(1);
  const [detailSale, setDetailSale] = useState<Sale | null>(null);

  /* ── Helper to Normalize API Sales ────────────────────── */
  const normalizeSalesList = (rawList: any[]): Sale[] => {
    // Strictly normal POS/Cart transactions only (appointment_id must be null or 0)
    const posSales = rawList.filter((s) => !s.appointment_id || s.appointment_id === 0);
    return posSales.map((s) => {
      let parsedItems: any[] = [];
      if (s.items) {
        if (Array.isArray(s.items)) {
          parsedItems = s.items;
        } else if (typeof s.items === 'string') {
          try {
            parsedItems = JSON.parse(s.items);
          } catch {
            parsedItems = [];
          }
        }
      }

      return {
        ...s,
        subtotal: Number(s.subtotal) || 0,
        item_discount_total: Number(s.item_discount_total) || 0,
        overall_discount: Number(s.overall_discount) || 0,
        tax_amount: Number(s.tax_amount) || 0,
        total_amount: Number(s.total_amount) || 0,
        amount_tendered: Number(s.amount_tendered) || 0,
        change_amount: Number(s.change_amount) || 0,
        items: parsedItems.map((it) => ({
          product_id: it.product_id,
          product_name: it.product_name || it.name || 'Item',
          unit_price: Number(it.unit_price) || 0,
          quantity: Number(it.quantity) || 1,
          discount: Number(it.discount) || 0,
          line_total: Number(it.line_total) || ((Number(it.unit_price) || 0) * (Number(it.quantity) || 1)),
        })),
      };
    });
  };

  /* ── Data Fetching ────────────────────────────────────── */
  const loadSales = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await saleApi.getAll();
      const rawList = res.data?.data ?? [];
      const list = normalizeSalesList(rawList);

      // Sort newest first
      list.sort((a, b) => {
        const tA = a.created_at ? new Date(a.created_at).getTime() : 0;
        const tB = b.created_at ? new Date(b.created_at).getTime() : 0;
        return tB - tA;
      });

      setBaselineSales(list);
      setAllSales(list);
      setCurrentPage(1);
      setActiveSearchQuery('');
      setSearchInput('');
    } catch (err) {
      console.error('Error loading sales:', err);
      toast.error('Failed to load sales history');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadSales();
  }, [loadSales]);

  /* ── Search Handlers ──────────────────────────────────── */
  const handlePerformSearch = async () => {
    const query = searchInput.trim();
    setIsSearching(true);
    setActiveSearchQuery(query);
    try {
      const res = await saleApi.getAll({ search: query || undefined });
      const rawList = res.data?.data ?? [];
      const list = normalizeSalesList(rawList);

      list.sort((a, b) => {
        const tA = a.created_at ? new Date(a.created_at).getTime() : 0;
        const tB = b.created_at ? new Date(b.created_at).getTime() : 0;
        return tB - tA;
      });

      setAllSales(list);
      setCurrentPage(1);
    } catch (err) {
      console.error('Error searching sales:', err);
      toast.error('Error searching sales');
    } finally {
      setIsSearching(false);
    }
  };

  const handleResetSearch = () => {
    setSearchInput('');
    setActiveSearchQuery('');
    setAllSales(baselineSales);
    setCurrentPage(1);
  };

  /* ── Metrics Calculations ─────────────────────────────── */
  const totalCompletedOrders = baselineSales.length;
  const totalRevenue = baselineSales.reduce((acc, s) => acc + (Number(s.total_amount) || 0), 0);
  const avgOrderValue = totalCompletedOrders > 0 ? totalRevenue / totalCompletedOrders : 0;

  const cashOrdersCount = baselineSales.filter((s) => s.payment_method?.toLowerCase() === 'cash').length;
  const cardOrdersCount = baselineSales.filter((s) => s.payment_method?.toLowerCase() === 'card').length;

  /* ── Filter & Pagination ──────────────────────────────── */
  const filteredSales = allSales.filter((s) => {
    if (activeFilter === 'cash') return s.payment_method?.toLowerCase() === 'cash';
    if (activeFilter === 'card') return s.payment_method?.toLowerCase() === 'card';
    if (activeFilter === 'qr') return s.payment_method?.toLowerCase() === 'qr';
    return true;
  });

  const totalItems = filteredSales.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / PAGE_SIZE));
  const validPage = Math.min(Math.max(1, currentPage), totalPages);
  const startIndex = (validPage - 1) * PAGE_SIZE;
  const pageSales = filteredSales.slice(startIndex, startIndex + PAGE_SIZE);

  /* ── Date/Time Formatter ──────────────────────────────── */
  const formatDateTime = (dateStr?: string) => {
    if (!dateStr) return 'N/A';
    const dt = new Date(dateStr);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const h = dt.getHours();
    const hour = h % 12 === 0 ? 12 : h % 12;
    const ampm = h >= 12 ? 'PM' : 'AM';
    const min = String(dt.getMinutes()).padStart(2, '0');
    return `${dt.getDate()} ${months[dt.getMonth()]} ${dt.getFullYear()}, ${hour}:${min} ${ampm}`;
  };

  /* ── Render ───────────────────────────────────────────── */
  return (
    <div className="sales-history-container">
      {/* ── 1. Header ──────────────────────────────────────── */}
      <header className="sales-header">
        <div className="sales-header__left">
          <h2 className="sales-header__title">Sales History & POS Orders</h2>
          <span className="sales-header__count-badge">{allSales.length} Total Orders</span>
        </div>

        <button
          type="button"
          className="sales-refresh-btn"
          disabled={isLoading}
          onClick={loadSales}
        >
          <RotateCw
            size={16}
            color="#E11D48"
            className={isLoading ? 'table-loader-spinner' : ''}
          />
          <span>Refresh</span>
        </button>
      </header>

      {/* ── 2. Summary KPI Metrics ─────────────────────────── */}
      <div className="sales-metrics-row">
        {/* Total Completed Orders */}
        <div className="sales-metric-card">
          <div className="sales-metric-icon" style={{ background: '#EEF2FF', color: '#4F46E5' }}>
            <Receipt size={20} />
          </div>
          <div className="sales-metric-info">
            <div className="sales-metric-title">Total Completed Orders</div>
            <div className="sales-metric-value">{totalCompletedOrders} Orders</div>
            <div className="sales-metric-sub">Total completed sales transactions</div>
          </div>
        </div>

        {/* Total Revenue */}
        <div className="sales-metric-card">
          <div className="sales-metric-icon" style={{ background: '#ECFDF5', color: '#059669' }}>
            <Banknote size={20} />
          </div>
          <div className="sales-metric-info">
            <div className="sales-metric-title">Total Revenue</div>
            <div className="sales-metric-value">${fmtMoney(totalRevenue)}</div>
            <div className="sales-metric-sub">Combined sales across all payment modes</div>
          </div>
        </div>

        {/* Average Order Value */}
        <div className="sales-metric-card">
          <div className="sales-metric-icon" style={{ background: '#FFF1F2', color: '#E11D48' }}>
            <TrendingUp size={20} />
          </div>
          <div className="sales-metric-info">
            <div className="sales-metric-title">Average Order Value</div>
            <div className="sales-metric-value">${fmtMoney(avgOrderValue)}</div>
            <div className="sales-metric-sub">Average checkout transaction ticket</div>
          </div>
        </div>
      </div>

      {/* ── 3. Filter Bar & Search ─────────────────────────── */}
      <div className="sales-filter-bar">
        <div className="sales-filter-chips">
          <button
            type="button"
            className={`sales-filter-chip ${activeFilter === 'all' ? 'sales-filter-chip--active-all' : ''}`}
            onClick={() => {
              setActiveFilter('all');
              setCurrentPage(1);
            }}
          >
            All Sales ({allSales.length})
          </button>
          <button
            type="button"
            className={`sales-filter-chip ${activeFilter === 'cash' ? 'sales-filter-chip--active-cash' : ''}`}
            onClick={() => {
              setActiveFilter('cash');
              setCurrentPage(1);
            }}
          >
            Cash ({cashOrdersCount})
          </button>
          <button
            type="button"
            className={`sales-filter-chip ${activeFilter === 'card' ? 'sales-filter-chip--active-card' : ''}`}
            onClick={() => {
              setActiveFilter('card');
              setCurrentPage(1);
            }}
          >
            Card ({cardOrdersCount})
          </button>
          <button
            type="button"
            className={`sales-filter-chip ${activeFilter === 'qr' ? 'sales-filter-chip--active-qr' : ''}`}
            onClick={() => {
              setActiveFilter('qr');
              setCurrentPage(1);
            }}
          >
            QR Payment
          </button>
        </div>

        {/* Search */}
        <div className="sales-search-section">
          <div className="sales-search-box">
            <Search size={16} className="sales-search-box__icon" />
            <input
              type="text"
              className="sales-search-input"
              placeholder="Search customer, phone, staff..."
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handlePerformSearch()}
            />
            {searchInput && (
              <button
                type="button"
                className="sales-search-clear-btn"
                onClick={() => {
                  setSearchInput('');
                  if (activeSearchQuery) handleResetSearch();
                }}
              >
                <X size={14} />
              </button>
            )}
          </div>

          <button
            type="button"
            className="sales-search-apply-btn"
            disabled={isSearching}
            onClick={handlePerformSearch}
          >
            {isSearching ? (
              <span className="table-loader-spinner" style={{ width: '14px', height: '14px', borderColor: '#fff', borderTopColor: 'transparent' }} />
            ) : (
              <>
                <Search size={15} />
                <span>Apply</span>
              </>
            )}
          </button>

          {activeSearchQuery && (
            <button
              type="button"
              className="sales-search-reset-btn"
              onClick={handleResetSearch}
            >
              <X size={14} />
              <span>Reset</span>
            </button>
          )}
        </div>
      </div>

      {/* ── 4. Sales List or Empty State ───────────────────── */}
      {isLoading ? (
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div className="table-loader-spinner" style={{ borderColor: '#E11D48', borderTopColor: 'transparent', width: '32px', height: '32px' }} />
        </div>
      ) : filteredSales.length === 0 ? (
        <div className="sales-empty-state">
          <div className="sales-empty-icon-circle">
            <Receipt size={40} />
          </div>
          <div className="sales-empty-title">
            {activeSearchQuery ? 'No orders match your search' : 'No sales records found'}
          </div>
          <div className="sales-empty-desc">
            {activeSearchQuery
              ? 'Try searching with a different keyword or reset filters.'
              : 'Orders completed in the Cart POS will immediately appear here.'}
          </div>
          <button
            type="button"
            style={{
              padding: '10px 18px',
              background: '#E11D48',
              color: '#ffffff',
              border: 'none',
              borderRadius: '10px',
              fontSize: '13px',
              fontWeight: 600,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
            }}
            onClick={loadSales}
          >
            <RotateCw size={15} />
            <span>Reload Sales</span>
          </button>
        </div>
      ) : (
        <div className="sales-list-container">
          {pageSales.map((sale) => {
            const method = (sale.payment_method || 'cash').toLowerCase();
            const badgeClass =
              method === 'cash'
                ? 'sale-payment-badge--cash'
                : method === 'card'
                ? 'sale-payment-badge--card'
                : method === 'qr'
                ? 'sale-payment-badge--qr'
                : 'sale-payment-badge--other';

            return (
              <div
                key={sale.id}
                className="sale-item-card"
                onClick={() => setDetailSale(sale)}
              >
                <div className="sale-item-icon-box">
                  <Receipt size={22} />
                </div>

                <div className="sale-item-main">
                  <div className="sale-item-top-row">
                    <span className="sale-item-receipt-num">
                      {formatReceiptNumber(sale.id, sale.created_at)}
                    </span>
                    <span className="sale-status-badge">
                      <BadgeCheck size={12} />
                      <span>Completed</span>
                    </span>
                  </div>

                  <div className="sale-item-meta-row">
                    <div className="sale-meta-group">
                      <User size={13} color="#94A3B8" />
                      <span className="sale-customer-name">
                        {sale.customer_name || 'Walk-in Customer'}
                      </span>
                      {sale.customer_phone && (
                        <span style={{ color: '#94A3B8', fontSize: '11px' }}>
                          ({sale.customer_phone})
                        </span>
                      )}
                    </div>

                    {sale.staff_name && (
                      <span className="sale-staff-pill">
                        <User size={11} color="#64748B" />
                        <span>{sale.staff_name}</span>
                      </span>
                    )}

                    <div className="sale-meta-group">
                      <Clock size={13} color="#94A3B8" />
                      <span>{formatDateTime(sale.created_at)}</span>
                    </div>
                  </div>
                </div>

                <div className="sale-item-right">
                  <span className="sale-item-total">${fmtMoney(sale.total_amount)}</span>
                  <span className={`sale-payment-badge ${badgeClass}`}>
                    {getPaymentMethodLabel(sale.payment_method)}
                  </span>
                </div>

                <ChevronRight size={18} className="sale-chevron" />
              </div>
            );
          })}
        </div>
      )}

      {/* ── 5. Pagination Controls ─────────────────────────── */}
      {!isLoading && filteredSales.length > 0 && (
        <div className="sales-pagination-bar">
          <span className="sales-pagination-info">
            Showing {startIndex + 1} - {Math.min(startIndex + PAGE_SIZE, totalItems)} of {totalItems} records (Page {validPage} of {totalPages})
          </span>

          <div className="sales-pagination-btns">
            <button
              type="button"
              className="sales-page-nav-btn"
              disabled={validPage <= 1}
              onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
            >
              <ChevronLeft size={16} />
              <span>Prev</span>
            </button>

            {/* Page number buttons */}
            {Array.from({ length: totalPages }, (_, i) => i + 1)
              .filter((p) => p === 1 || p === totalPages || Math.abs(p - validPage) <= 2)
              .map((p, idx, arr) => {
                const prev = arr[idx - 1];
                return (
                  <div key={p} style={{ display: 'flex', alignItems: 'center' }}>
                    {prev && p - prev > 1 && (
                      <span style={{ padding: '0 4px', color: '#94A3B8', fontSize: '12px' }}>...</span>
                    )}
                    <button
                      type="button"
                      className={`sales-page-num-btn ${p === validPage ? 'sales-page-num-btn--active' : ''}`}
                      onClick={() => setCurrentPage(p)}
                    >
                      {p}
                    </button>
                  </div>
                );
              })}

            <button
              type="button"
              className="sales-page-nav-btn"
              disabled={validPage >= totalPages}
              onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
            >
              <span>Next</span>
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      )}

      {/* ── 6. Detail Modal (Tax Receipt & Order Details) ──── */}
      {detailSale && (
        <div className="cart-modal-overlay" onClick={() => setDetailSale(null)}>
          <div className="sale-detail-dialog" onClick={(e) => e.stopPropagation()} role="dialog">
            {/* Header */}
            <div className="sale-detail-header">
              <div>
                <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 800, color: '#0F172A', fontFamily: 'var(--font-display)' }}>
                  Tax Receipt & Order Details
                </h3>
                <div style={{ fontSize: '12px', color: '#64748B', fontWeight: 600, marginTop: '2px' }}>
                  {formatReceiptNumber(detailSale.id, detailSale.created_at)}
                </div>
              </div>
              <span className="sale-status-badge" style={{ fontSize: '11px', padding: '3px 10px' }}>
                <BadgeCheck size={13} />
                <span>Completed</span>
              </span>
            </div>

            {/* Linked Appointment Banner */}
            {detailSale.appointment_id && (
              <div className="sale-linked-appt-banner">
                <CalendarCheck size={16} />
                <span>Linked Appointment: #{detailSale.appointment_id}</span>
                {detailSale.staff_name && (
                  <span style={{ marginLeft: 'auto', fontWeight: 600, color: '#065F46' }}>
                    Attendant: {detailSale.staff_name}
                  </span>
                )}
              </div>
            )}

            {/* Customer & Timestamp Grid */}
            <div className="sale-detail-grid">
              <div>
                <div style={{ fontSize: '11px', color: '#94A3B8', fontWeight: 500 }}>Customer</div>
                <div style={{ fontSize: '13px', fontWeight: 600, color: '#0F172A', marginTop: '2px' }}>
                  {detailSale.customer_name || 'Walk-in Guest'}
                </div>
                {detailSale.customer_phone && (
                  <div style={{ fontSize: '11.5px', color: '#64748B' }}>{detailSale.customer_phone}</div>
                )}
              </div>

              <div style={{ textAlign: 'right' }}>
                <div style={{ fontSize: '11px', color: '#94A3B8', fontWeight: 500 }}>Date & Time</div>
                <div style={{ fontSize: '12px', fontWeight: 600, color: '#0F172A', marginTop: '2px' }}>
                  {formatDateTime(detailSale.created_at)}
                </div>
                {detailSale.staff_name && !detailSale.appointment_id && (
                  <div style={{ fontSize: '11.5px', color: '#64748B' }}>Attendant: {detailSale.staff_name}</div>
                )}
              </div>
            </div>

            {/* Purchased Items List */}
            <div style={{ fontSize: '12.5px', fontWeight: 700, color: '#0F172A', marginBottom: '8px' }}>
              Purchased Items ({detailSale.items?.length || 0})
            </div>
            <div className="sale-detail-items-box">
              {detailSale.items?.map((it, idx) => (
                <div key={idx} className="sale-detail-item-row">
                  <span style={{ color: '#334155' }}>
                    {it.product_name} ×{it.quantity}
                  </span>
                  <span style={{ fontWeight: 600, color: '#0F172A' }}>
                    ${fmtMoney(it.line_total)}
                  </span>
                </div>
              ))}
            </div>

            {/* Financial Totals */}
            <div className="sale-detail-totals">
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#64748B' }}>
                <span>Subtotal</span>
                <span style={{ fontWeight: 600, color: '#0F172A' }}>${fmtMoney(detailSale.subtotal)}</span>
              </div>
              {Number(detailSale.item_discount_total) > 0 && (
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#E11D48' }}>
                  <span>Item Discounts</span>
                  <span style={{ fontWeight: 600 }}>-${fmtMoney(detailSale.item_discount_total)}</span>
                </div>
              )}
              {Number(detailSale.overall_discount) > 0 && (
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#E11D48' }}>
                  <span>Overall Discount</span>
                  <span style={{ fontWeight: 600 }}>-${fmtMoney(detailSale.overall_discount)}</span>
                </div>
              )}
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12.5px', color: '#64748B' }}>
                <span>Tax (8%)</span>
                <span style={{ fontWeight: 600, color: '#0F172A' }}>${fmtMoney(detailSale.tax_amount)}</span>
              </div>

              <div className="sale-detail-total-paid">
                <span>Total Paid</span>
                <span style={{ color: '#E11D48' }}>${fmtMoney(detailSale.total_amount)}</span>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: '#64748B', marginTop: '6px' }}>
                <span>Payment Method</span>
                <span style={{ fontWeight: 600, color: '#0F172A' }}>
                  {getPaymentMethodLabel(detailSale.payment_method)} (Tendered: ${fmtMoney(detailSale.amount_tendered || detailSale.total_amount)})
                </span>
              </div>

              {Number(detailSale.change_amount) > 0 && (
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: '#64748B', marginTop: '2px' }}>
                  <span>Change Returned</span>
                  <span style={{ fontWeight: 600, color: '#059669' }}>
                    ${fmtMoney(detailSale.change_amount)}
                  </span>
                </div>
              )}
            </div>

            {/* Close Button */}
            <button
              type="button"
              className="sale-detail-close-btn"
              onClick={() => setDetailSale(null)}
            >
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

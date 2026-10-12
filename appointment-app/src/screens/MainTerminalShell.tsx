import { useState, useEffect, useCallback } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { toast } from 'react-toastify';
import Header from '../components/Header';
import Sidebar from '../components/Sidebar';
import MobileBottomNav from '../components/MobileBottomNav';
import DashboardView from '../views/DashboardView';
import CartView from '../views/CartView';
import SalesHistoryView from '../views/SalesHistoryView';
import CategoriesView from '../views/CategoriesView';
import ProductsView from '../views/ProductsView';
import AppointmentConfigView from '../views/AppointmentConfigView';
import AppointmentView from '../views/AppointmentView';
import StaffView from '../views/StaffView';
import AppointmentHistoryView from '../views/AppointmentHistoryView';
import AppointmentV2View from '../views/AppointmentV2View';
import PrinterSettingsView from '../views/PrinterSettingsView';
import MoreOptionsView from '../views/MoreOptionsView';
import TabPlaceholderView from '../views/TabPlaceholderView';
import { useAppDispatch, useAppSelector } from '../store/hooks';
import { logout } from '../features/auth/authSlice';
import { settingsApi } from '../api/settingsApi';
import { setPrinterSettings } from '../features/printer/printerSlice';
import '../styles/terminal.css';

export default function MainTerminalShell() {
  const dispatch = useAppDispatch();
  const navigate = useNavigate();
  const location = useLocation();
  const business = useAppSelector((s) => s.auth.business);
  const isPrinterLoaded = useAppSelector((s) => s.printer.isLoaded);

  const isPrinterRoute = location.pathname === '/printer' || location.pathname === '/printers';
  const [currentTab, setCurrentTab] = useState<number>(() => (isPrinterRoute ? 11 : 0));
  const [showLogoutModal, setShowLogoutModal] = useState<boolean>(false);
  const [mobileCartMode, setMobileCartMode] = useState<'pos' | 'cart'>('pos');
  const [cartItemCount, setCartItemCount] = useState<number>(0);

  // Auto-sync LAN printer settings into Redux state on startup
  useEffect(() => {
    if (!isPrinterLoaded) {
      settingsApi
        .getSettings()
        .then((res) => {
          if (res.data?.data?.printer_settings) {
            dispatch(setPrinterSettings(res.data.data.printer_settings));
          }
        })
        .catch((err) => {
          console.warn('Could not auto-sync printer settings in terminal shell:', err);
        });
    }
  }, [isPrinterLoaded, dispatch]);

  // Sync tab if user navigates to /printer or /dashboard via direct URL or browser back/forward
  useEffect(() => {
    if (location.pathname === '/printer' || location.pathname === '/printers') {
      setCurrentTab(11);
    } else if (location.pathname === '/dashboard' && currentTab === 11) {
      setCurrentTab(0);
    }
  }, [location.pathname, currentTab]);

  const handleSelectTab = useCallback(
    (idx: number) => {
      setCurrentTab(idx);
      if (idx === 11) {
        if (location.pathname !== '/printer') {
          navigate('/printer');
        }
      } else {
        if (location.pathname === '/printer' || location.pathname === '/printers') {
          navigate('/dashboard');
        }
      }
    },
    [location.pathname, navigate]
  );


  const handleLogout = () => {
    dispatch(logout());
    setShowLogoutModal(false);
    toast.info('Signed out of terminal');
    navigate('/login', { replace: true });
  };

  const [cartPreload, setCartPreload] = useState<{
    customer?: any;
    products?: any[];
    appointmentId?: number | null;
    staffName?: string | null;
  } | null>(null);

  const businessName =
    business?.business_name?.trim() ||
    business?.owner_name?.trim() ||
    'IQ Store';

  return (
    <div className="terminal-shell">
      {/* 1. Fixed Top Header */}
      <Header onLogoutClick={() => setShowLogoutModal(true)} />

      {/* 2. Main Terminal Body: Sidebar + Viewport */}
      <div className="terminal-body">
        <Sidebar
          currentIndex={currentTab}
          onSelectTab={handleSelectTab}
        />

        <main
          className={`terminal-viewport ${
            currentTab === 1 || currentTab === 10 ? 'terminal-viewport--no-scroll' : ''
          }`}
        >
          {currentTab === 0 ? (
            <DashboardView onNavigate={handleSelectTab} />
          ) : currentTab === 1 ? (
            <AppointmentView
              onStartService={(customer, products, appointment) => {
                setCartPreload({
                  customer,
                  products,
                  appointmentId: appointment?.id,
                  staffName: appointment?.staff_name,
                });
                setMobileCartMode('cart');
                handleSelectTab(4); // Switch to Cart & POS
              }}
            />
          ) : currentTab === 2 ? (
            <StaffView />
          ) : currentTab === 3 ? (
            <AppointmentHistoryView />
          ) : currentTab === 4 ? (
            <CartView
              preloadCustomer={cartPreload?.customer}
              preloadProducts={cartPreload?.products}
              preloadAppointmentId={cartPreload?.appointmentId}
              preloadStaffName={cartPreload?.staffName}
              onNavigateToSalesHistory={() => handleSelectTab(5)}
              mobileViewMode={mobileCartMode}
              onMobileViewModeChange={(m) => setMobileCartMode(m)}
              onCartCountChange={(cnt) => setCartItemCount(cnt)}
            />
          ) : currentTab === 5 ? (
            <SalesHistoryView />
          ) : currentTab === 6 ? (
            <CategoriesView />
          ) : currentTab === 7 ? (
            <ProductsView />
          ) : currentTab === 8 ? (
            <AppointmentConfigView />
          ) : currentTab === 11 ? (
            <PrinterSettingsView />
          ) : currentTab === 9 ? (
            <MoreOptionsView
              onNavigate={handleSelectTab}
              onLogoutClick={() => setShowLogoutModal(true)}
              onSelectCartMode={(m) => setMobileCartMode(m)}
            />
          ) : currentTab === 10 ? (
            <AppointmentV2View
              onStartService={(customer, products, appointment) => {
                setCartPreload({
                  customer,
                  products,
                  appointmentId: appointment?.id,
                  staffName: appointment?.staff_name,
                });
                setMobileCartMode('cart');
                handleSelectTab(4); // Switch to Cart & POS
              }}
            />
          ) : (
            <TabPlaceholderView
              tabIndex={currentTab}
              onBackToDashboard={() => handleSelectTab(0)}
            />
          )}
        </main>
      </div>

      {/* 3. Mobile Fixed Bottom Navigation Bar */}
      <MobileBottomNav
        currentTab={currentTab}
        onSelectTab={handleSelectTab}
        mobileCartMode={mobileCartMode}
        onSelectCartMode={(mode) => setMobileCartMode(mode)}
        cartCount={cartItemCount}
      />

      {/* 3. Sign Out Confirmation Modal Dialog */}
      {showLogoutModal && (
        <div
          className="modal-overlay"
          onClick={() => setShowLogoutModal(false)}
        >
          <div
            className="modal-dialog"
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
          >
            <h3 className="modal-dialog__title">Sign Out Terminal</h3>
            <p className="modal-dialog__body">
              Are you sure you want to log out of {businessName}?
            </p>
            <div className="modal-dialog__actions">
              <button
                type="button"
                className="modal-btn modal-btn--cancel"
                onClick={() => setShowLogoutModal(false)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="modal-btn modal-btn--confirm"
                onClick={handleLogout}
              >
                Sign Out
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'react-toastify';
import Header from '../components/Header';
import Sidebar from '../components/Sidebar';
import DashboardView from '../views/DashboardView';
import CartView from '../views/CartView';
import SalesHistoryView from '../views/SalesHistoryView';
import CategoriesView from '../views/CategoriesView';
import ProductsView from '../views/ProductsView';
import AppointmentConfigView from '../views/AppointmentConfigView';
import AppointmentView from '../views/AppointmentView';
import StaffView from '../views/StaffView';
import AppointmentHistoryView from '../views/AppointmentHistoryView';
import TabPlaceholderView from '../views/TabPlaceholderView';
import { useAppDispatch, useAppSelector } from '../store/hooks';
import { logout } from '../features/auth/authSlice';
import '../styles/terminal.css';

export default function MainTerminalShell() {
  const dispatch = useAppDispatch();
  const navigate = useNavigate();
  const business = useAppSelector((s) => s.auth.business);

  const [currentTab, setCurrentTab] = useState<number>(0);
  const [showLogoutModal, setShowLogoutModal] = useState<boolean>(false);

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
          onSelectTab={(idx) => setCurrentTab(idx)}
        />

        <main className="terminal-viewport">
          {currentTab === 0 ? (
            <DashboardView onNavigate={(idx) => setCurrentTab(idx)} />
          ) : currentTab === 1 ? (
            <AppointmentView
              onStartService={(customer, products, appointment) => {
                setCartPreload({
                  customer,
                  products,
                  appointmentId: appointment?.id,
                  staffName: appointment?.staff_name,
                });
                setCurrentTab(4); // Switch to Cart & POS
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
              onNavigateToSalesHistory={() => setCurrentTab(5)}
            />
          ) : currentTab === 5 ? (
            <SalesHistoryView />
          ) : currentTab === 6 ? (
            <CategoriesView />
          ) : currentTab === 7 ? (
            <ProductsView />
          ) : currentTab === 8 ? (
            <AppointmentConfigView />
          ) : (
            <TabPlaceholderView
              tabIndex={currentTab}
              onBackToDashboard={() => setCurrentTab(0)}
            />
          )}
        </main>
      </div>

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

import {
  LayoutDashboard,
  Calendar,
  // History,
  ShoppingCart,
  Store,
  MoreHorizontal,
} from 'lucide-react';

interface MobileBottomNavProps {
  currentTab: number;
  onSelectTab: (index: number) => void;
  mobileCartMode?: 'pos' | 'cart';
  onSelectCartMode?: (mode: 'pos' | 'cart') => void;
  cartCount?: number;
}

export default function MobileBottomNav({
  currentTab,
  onSelectTab,
  mobileCartMode = 'pos',
  onSelectCartMode,
  cartCount = 0,
}: MobileBottomNavProps) {
  // Check active state
  const isDashboardActive = currentTab === 0;
  const isAppointmentsActive = currentTab === 1;
  // const isHistoryActive = currentTab === 3;
  const isCartActive = currentTab === 4 && mobileCartMode === 'cart';
  const isPosActive = currentTab === 4 && mobileCartMode === 'pos';
  // More is active if user is on More page (9) or on any sub-option under More (2, 5, 6, 7, 8)
  const isMoreActive =
    currentTab === 9 || [2, 5, 6, 7, 8].includes(currentTab);

  return (
    <nav className="mobile-bottom-nav" aria-label="Mobile Navigation">
      {/* 1. Dashboard */}
      <button
        type="button"
        className={`mobile-nav-item ${isDashboardActive ? 'mobile-nav-item--active' : ''
          }`}
        onClick={() => onSelectTab(0)}
      >
        {isDashboardActive && <span className="mobile-nav-item__indicator" />}
        <div className="mobile-nav-item__icon-wrap">
          <LayoutDashboard size={20} />
        </div>
        <span className="mobile-nav-item__label">Dashboard</span>
      </button>

      {/* 2. Appointments */}
      <button
        type="button"
        className={`mobile-nav-item ${isAppointmentsActive ? 'mobile-nav-item--active' : ''
          }`}
        onClick={() => onSelectTab(1)}
      >
        {isAppointmentsActive && (
          <span className="mobile-nav-item__indicator" />
        )}
        <div className="mobile-nav-item__icon-wrap">
          <Calendar size={20} />
        </div>
        <span className="mobile-nav-item__label">Appointments</span>
      </button>

      {/* 3. Appointment History */}
      {/* <button
        type="button"
        className={`mobile-nav-item ${
          isHistoryActive ? 'mobile-nav-item--active' : ''
        }`}
        onClick={() => onSelectTab(3)}
      >
        {isHistoryActive && <span className="mobile-nav-item__indicator" />}
        <div className="mobile-nav-item__icon-wrap">
          <History size={20} />
        </div>
        <span className="mobile-nav-item__label">History</span>
      </button> */}

      {/* 5. POS */}
      <button
        type="button"
        className={`mobile-nav-item ${isPosActive ? 'mobile-nav-item--active' : ''
          }`}
        onClick={() => {
          onSelectCartMode?.('pos');
          onSelectTab(4);
        }}
      >
        {isPosActive && <span className="mobile-nav-item__indicator" />}
        <div className="mobile-nav-item__icon-wrap">
          <Store size={20} />
        </div>
        <span className="mobile-nav-item__label">POS</span>
      </button>

      {/* 4. Cart */}
      <button
        type="button"
        className={`mobile-nav-item ${isCartActive ? 'mobile-nav-item--active' : ''
          }`}
        onClick={() => {
          onSelectCartMode?.('cart');
          onSelectTab(4);
        }}
      >
        {isCartActive && <span className="mobile-nav-item__indicator" />}
        <div className="mobile-nav-item__icon-wrap">
          <ShoppingCart size={20} />
          {cartCount > 0 && (
            <span className="mobile-nav-item__badge">
              {cartCount > 99 ? '99+' : cartCount}
            </span>
          )}
        </div>
        <span className="mobile-nav-item__label">Cart</span>
      </button>

      {/* 6. More */}
      <button
        type="button"
        className={`mobile-nav-item ${isMoreActive ? 'mobile-nav-item--active' : ''
          }`}
        onClick={() => onSelectTab(9)}
      >
        {isMoreActive && <span className="mobile-nav-item__indicator" />}
        <div className="mobile-nav-item__icon-wrap">
          <MoreHorizontal size={20} />
        </div>
        <span className="mobile-nav-item__label">More</span>
      </button>
    </nav>
  );
}

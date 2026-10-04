import {
  LayoutDashboard,
  Calendar,
  Users,
  History,
  ShoppingCart,
  Receipt,
  FolderTree,
  Package,
  Sliders,
  Settings,
  Grid,
  List,
} from 'lucide-react';
import { useAppDispatch, useAppSelector } from '../store/hooks';
import { setSidebarExpanded } from '../features/auth/authSlice';

export interface NavItemConfig {
  id: number;
  title: string;
  icon: React.ComponentType<{ size?: number; className?: string }>;
}

export const navItems: NavItemConfig[] = [
  { id: 0, title: 'Dashboard', icon: LayoutDashboard },
  { id: 1, title: 'Appointment', icon: Calendar },
  { id: 2, title: 'Staff', icon: Users },
  { id: 3, title: 'Appointment History', icon: History },
  { id: 4, title: 'Cart & POS', icon: ShoppingCart },
  { id: 5, title: 'Sales History', icon: Receipt },
  { id: 6, title: 'Categories', icon: FolderTree },
  { id: 7, title: 'Products', icon: Package },
  { id: 8, title: 'Appointment Config', icon: Sliders },
  { id: 9, title: 'Settings', icon: Settings },
];

interface SidebarProps {
  currentIndex: number;
  onSelectTab: (index: number) => void;
}

export default function Sidebar({ currentIndex, onSelectTab }: SidebarProps) {
  const dispatch = useAppDispatch();
  const isExpanded = useAppSelector((s) => s.auth.isSidebarExpanded);

  return (
    <aside
      className={`terminal-sidebar ${
        isExpanded ? 'terminal-sidebar--expanded' : 'terminal-sidebar--collapsed'
      }`}
    >
      {/* Top section: Menu label + View toggle or expand button */}
      <div className="sidebar-top-bar">
        {isExpanded ? (
          <>
            <span className="sidebar-top-bar__title">MENU</span>
            <div className="sidebar-view-toggle">
              <button
                type="button"
                className={`sidebar-view-toggle__btn ${
                  !isExpanded ? 'sidebar-view-toggle__btn--active' : ''
                }`}
                title="Grid View (Icons Only)"
                onClick={() => dispatch(setSidebarExpanded(false))}
              >
                <Grid size={18} />
              </button>
              <button
                type="button"
                className={`sidebar-view-toggle__btn ${
                  isExpanded ? 'sidebar-view-toggle__btn--active' : ''
                }`}
                title="List View (Full Details)"
                onClick={() => dispatch(setSidebarExpanded(true))}
              >
                <List size={18} />
              </button>
            </div>
          </>
        ) : (
          <button
            type="button"
            className="sidebar-expand-btn"
            title="Switch to List View"
            onClick={() => dispatch(setSidebarExpanded(true))}
          >
            <List size={20} />
          </button>
        )}
      </div>

      {/* Navigation List */}
      <nav className="sidebar-nav-list">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isSelected = currentIndex === item.id;

          return (
            <button
              key={item.id}
              type="button"
              className={`sidebar-nav-item ${
                isSelected ? 'sidebar-nav-item--active' : ''
              } ${!isExpanded ? 'sidebar-nav-item--collapsed' : ''}`}
              title={item.title}
              onClick={() => onSelectTab(item.id)}
            >
              <span className="sidebar-nav-item__icon">
                <Icon size={isExpanded ? 19 : 21} />
              </span>
              {isExpanded && (
                <>
                  <span className="sidebar-nav-item__title">{item.title}</span>
                  {isSelected && <span className="sidebar-nav-item__dot" />}
                </>
              )}
            </button>
          );
        })}
      </nav>
    </aside>
  );
}

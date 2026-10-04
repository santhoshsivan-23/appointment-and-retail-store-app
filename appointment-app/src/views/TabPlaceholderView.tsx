import { ArrowLeft } from 'lucide-react';
import { navItems } from '../components/Sidebar';

interface TabPlaceholderViewProps {
  tabIndex: number;
  onBackToDashboard: () => void;
}

export default function TabPlaceholderView({
  tabIndex,
  onBackToDashboard,
}: TabPlaceholderViewProps) {
  const item = navItems.find((n) => n.id === tabIndex) || {
    title: 'Terminal View',
    icon: ArrowLeft,
  };
  const Icon = item.icon;

  return (
    <div className="tab-placeholder">
      <div className="tab-placeholder__card">
        <div className="tab-placeholder__icon-wrap">
          <Icon size={28} />
        </div>
        <h2 className="tab-placeholder__title">{item.title}</h2>
        <p className="tab-placeholder__desc">
          This module is part of the next implementation milestone. In the current
          phase, Authentication, Main Header, Sidebar, and the Dashboard overview
          are active and functional.
        </p>
        <button
          type="button"
          className="tab-placeholder__back-btn"
          onClick={onBackToDashboard}
        >
          <ArrowLeft size={16} />
          <span>Back to Dashboard</span>
        </button>
      </div>
    </div>
  );
}

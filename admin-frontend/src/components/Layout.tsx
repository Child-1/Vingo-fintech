import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, Users, ArrowLeftRight, BarChart3, PiggyBank,
  Gift, Star, Megaphone, ScrollText, Settings, LogOut, ShieldCheck,
  ChevronRight, Tag, Wallet, UserCog, MessageCircle, Gavel,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { cn } from '../lib/utils';

// minRole: 'STAFF' | 'ADMIN' | 'SUPER_ADMIN'
const nav = [
  // ── Visible to all admin roles ──
  { to: '/overview',     label: 'Overview',             icon: LayoutDashboard, minRole: 'STAFF'      },
  { to: '/users',        label: 'Users',                icon: Users,           minRole: 'STAFF'      },
  { to: '/kyc',          label: 'KYC Review',           icon: ShieldCheck,     minRole: 'STAFF'      },
  { to: '/transactions', label: 'Transactions',         icon: ArrowLeftRight,  minRole: 'STAFF'      },
  { to: '/reports',      label: 'Reports',              icon: BarChart3,       minRole: 'STAFF'      },
  { to: '/thrifts',      label: 'Thrifts',              icon: PiggyBank,       minRole: 'STAFF'      },
  { to: '/myrabatags',   label: 'MyrabaTag Requests',   icon: Tag,             minRole: 'STAFF'      },
  { to: '/audit',        label: 'Audit Log',            icon: ScrollText,      minRole: 'STAFF'      },
  { to: '/system',       label: 'System',               icon: Settings,        minRole: 'STAFF'      },
  // ── ADMIN and above only ──
  { to: '/gifts',        label: 'Gift Catalog',         icon: Gift,            minRole: 'ADMIN'      },
  { to: '/points',       label: 'Points',               icon: Star,            minRole: 'ADMIN'      },
  { to: '/broadcasts',   label: 'Broadcasts',           icon: Megaphone,       minRole: 'ADMIN'      },
  { to: '/staff',        label: 'Staff & Admins',       icon: UserCog,         minRole: 'ADMIN'      },
  { to: '/support',      label: 'Support Inbox',        icon: MessageCircle,   minRole: 'STAFF'      },
  { to: '/disputes',     label: 'Disputes',             icon: Gavel,           minRole: 'STAFF'      },
  // ── SUPER_ADMIN only ──
  { to: '/balance',      label: 'Balance Adjust',       icon: Wallet,          minRole: 'SUPER_ADMIN'},
] as const;

const ROLE_RANK: Record<string, number> = { STAFF: 1, ADMIN: 2, SUPER_ADMIN: 3 };

export default function Layout() {
  const { logout, staffId, fullName, role } = useAuth();
  const myRank = ROLE_RANK[role ?? ''] ?? 0;
  const navigate = useNavigate();

  function handleLogout() {
    logout();
    navigate('/login');
  }

  return (
    <div className="flex h-screen overflow-hidden">
      {/* ── Sidebar ── */}
      <aside className="w-60 flex-shrink-0 bg-surface-card border-r border-surface-border
                        flex flex-col overflow-y-auto">
        {/* Logo */}
        <div className="px-5 py-5 border-b border-surface-border">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-brand flex items-center justify-center
                            text-white font-bold text-sm shadow-lg shadow-brand/30">M</div>
            <div>
              <p className="text-white font-bold text-sm leading-none">Myraba</p>
              <p className="text-myraba-hint text-xs mt-0.5">Admin Console</p>
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 space-y-0.5">
          {nav.filter(item => myRank >= (ROLE_RANK[item.minRole] ?? 0)).map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) => cn(
                'flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-all group',
                isActive
                  ? 'bg-brand/15 text-brand font-semibold border border-brand/20'
                  : 'text-myraba-second hover:text-white hover:bg-surface-elevated'
              )}
            >
              <Icon size={16} className="flex-shrink-0" />
              <span className="flex-1">{label}</span>
              <ChevronRight size={12} className="opacity-0 group-hover:opacity-50 transition-opacity" />
            </NavLink>
          ))}
        </nav>

        {/* User footer */}
        <div className="px-3 py-3 border-t border-surface-border">
          <div className="flex items-center gap-3 px-3 py-2 rounded-lg">
            <div className="w-7 h-7 rounded-full bg-brand/20 flex items-center justify-center
                            text-brand text-xs font-bold flex-shrink-0 border border-brand/30">
              {(fullName ?? staffId ?? '?')[0].toUpperCase()}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-white text-xs font-medium truncate">{fullName ?? staffId}</p>
              <p className="text-myraba-hint text-xs">{role}</p>
            </div>
            <button onClick={handleLogout} title="Sign out"
              className="text-myraba-hint hover:text-myraba-error transition-colors">
              <LogOut size={14} />
            </button>
          </div>
        </div>
      </aside>

      {/* ── Main content ── */}
      <main className="flex-1 overflow-y-auto bg-surface">
        <Outlet />
      </main>
    </div>
  );
}

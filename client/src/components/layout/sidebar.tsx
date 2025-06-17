import { Link, useLocation } from 'wouter';
import { Button } from '@/components/ui/button';
import { AuthManager } from '@/lib/auth';
import { AuthUser } from '@/lib/types';

interface SidebarProps {
  user: AuthUser;
}

export function Sidebar({ user }: SidebarProps) {
  const [location, setLocation] = useLocation();

  const handleLogout = () => {
    AuthManager.logout();
    setLocation('/login');
  };

  const getInitials = (name?: string) => {
    if (!name) return user.email.charAt(0).toUpperCase();
    return name.split(' ').map(n => n.charAt(0)).join('').toUpperCase();
  };

  const navItems = [
    { path: '/dashboard', label: 'Dashboard', icon: 'fas fa-tachometer-alt' },
    { path: '/emails', label: 'Email Analysis', icon: 'fas fa-envelope' },
    { path: '/tasks', label: 'Task Management', icon: 'fas fa-tasks' },
    { path: '/team', label: 'Team Analytics', icon: 'fas fa-users' },
    { path: '/reports', label: 'Reports', icon: 'fas fa-chart-bar' },
    { path: '/settings', label: 'Settings', icon: 'fas fa-cog' },
  ];

  return (
    <aside className="w-64 bg-white shadow-sm flex flex-col h-full">
      <div className="p-6 border-b border-gray-200">
        <div className="flex items-center">
          <div className="w-10 h-10 bg-blue-500 rounded-lg flex items-center justify-center">
            <i className="fas fa-chart-line text-white"></i>
          </div>
          <div className="ml-3">
            <h1 className="text-lg font-semibold text-gray-900">EmailIQ</h1>
            <p className="text-sm text-gray-500">Analytics</p>
          </div>
        </div>
      </div>
      
      <nav className="flex-1 p-4">
        <ul className="space-y-1">
          {navItems.map((item) => (
            <li key={item.path}>
              <Link href={item.path} className={`flex items-center px-3 py-2 rounded-lg transition-all ${
                location === item.path
                  ? 'bg-blue-50 text-blue-600 font-medium'
                  : 'text-gray-700 hover:bg-gray-100'
              }`}>
                <i className={`${item.icon} w-5 h-5 mr-3`}></i>
                {item.label}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
      
      <div className="p-4 border-t border-gray-200">
        <div className="flex items-center">
          <div className="w-10 h-10 bg-gradient-to-br from-blue-400 to-blue-600 rounded-full flex items-center justify-center">
            <span className="text-white font-medium text-sm">
              {getInitials(user.displayName)}
            </span>
          </div>
          <div className="ml-3 flex-1">
            <p className="text-sm font-medium text-gray-900">
              {user.displayName || user.email}
            </p>
            <p className="text-xs text-gray-500">{user.role || 'Employee'}</p>
          </div>
          <Button
            onClick={handleLogout}
            variant="ghost"
            size="sm"
            className="text-gray-400 hover:text-gray-600"
          >
            <i className="fas fa-sign-out-alt"></i>
          </Button>
        </div>
      </div>
    </aside>
  );
}

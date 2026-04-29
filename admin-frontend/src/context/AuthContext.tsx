import { createContext, useContext, useState, useEffect, type ReactNode } from 'react';
import { api } from '../lib/api';

interface AuthState {
  token: string | null;
  role: string | null;
  staffId: string | null;
  fullName: string | null;
}

interface AuthContextValue extends AuthState {
  login: (staffId: string, password: string) => Promise<string | null>;
  logout: () => void;
  isAdmin: boolean;
  isSuperAdmin: boolean;
  isValidating: boolean;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const storedToken = localStorage.getItem('myraba_admin_token');
  const [auth, setAuth] = useState<AuthState>({
    token:    storedToken,
    role:     localStorage.getItem('myraba_admin_role'),
    staffId:  localStorage.getItem('myraba_admin_staffid'),
    fullName: localStorage.getItem('myraba_admin_fullname'),
  });
  const [isValidating, setIsValidating] = useState<boolean>(!!storedToken);

  useEffect(() => {
    if (!storedToken) return;
    api.get('/api/users/me')
      .then(({ data }) => {
        const role: string = data.role ?? '';
        if (!['ADMIN', 'SUPER_ADMIN', 'STAFF'].includes(role)) {
          clearAuth();
        } else {
          setAuth(prev => ({ ...prev, role }));
        }
      })
      .catch(() => clearAuth())
      .finally(() => setIsValidating(false));
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function clearAuth() {
    setAuth({ token: null, role: null, staffId: null, fullName: null });
    ['myraba_admin_token', 'myraba_admin_role', 'myraba_admin_staffid', 'myraba_admin_fullname']
      .forEach(k => localStorage.removeItem(k));
  }

  useEffect(() => {
    if (auth.token) {
      localStorage.setItem('myraba_admin_token',   auth.token);
      localStorage.setItem('myraba_admin_role',    auth.role ?? '');
      localStorage.setItem('myraba_admin_staffid', auth.staffId ?? '');
      localStorage.setItem('myraba_admin_fullname', auth.fullName ?? '');
    } else {
      ['myraba_admin_token', 'myraba_admin_role', 'myraba_admin_staffid', 'myraba_admin_fullname']
        .forEach(k => localStorage.removeItem(k));
    }
  }, [auth]);

  async function login(staffId: string, password: string): Promise<string | null> {
    try {
      const { data } = await api.post('/admin/auth/login', { staffId, password });
      setAuth({ token: data.token, role: data.role, staffId: data.staffId, fullName: data.fullName });
      return null;
    } catch (err: any) {
      return err.response?.data?.message ?? 'Login failed. Check your Staff ID and password.';
    }
  }

  function logout() {
    clearAuth();
  }

  return (
    <AuthContext.Provider value={{
      ...auth,
      login,
      logout,
      isAdmin:      ['ADMIN', 'SUPER_ADMIN', 'STAFF'].includes(auth.role ?? ''),
      isSuperAdmin: auth.role === 'SUPER_ADMIN',
      isValidating,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be inside AuthProvider');
  return ctx;
}

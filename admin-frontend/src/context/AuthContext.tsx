import { createContext, useContext, useState, useEffect, type ReactNode } from 'react';
import { api } from '../lib/api';

interface AuthState {
  token: string | null;
  role: string | null;
  myrabaHandle: string | null;
}

interface AuthContextValue extends AuthState {
  login: (identifier: string, password: string) => Promise<string | null>;
  logout: () => void;
  isAdmin: boolean;
  isSuperAdmin: boolean;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>({
    token: localStorage.getItem('myraba_admin_token'),
    role:  localStorage.getItem('myraba_admin_role'),
    myrabaHandle: localStorage.getItem('myraba_admin_handle'),
  });

  useEffect(() => {
    // Sync to localStorage whenever auth changes
    if (auth.token) {
      localStorage.setItem('myraba_admin_token',  auth.token);
      localStorage.setItem('myraba_admin_role',   auth.role ?? '');
      localStorage.setItem('myraba_admin_handle', auth.myrabaHandle ?? '');
    } else {
      ['myraba_admin_token', 'myraba_admin_role', 'myraba_admin_handle'].forEach(k =>
        localStorage.removeItem(k)
      );
    }
  }, [auth]);

  async function login(identifier: string, password: string): Promise<string | null> {
    try {
      const { data } = await api.post('/auth/login', { identifier, password });
      const role: string = data.role ?? '';
      if (!['ADMIN', 'SUPER_ADMIN', 'STAFF'].includes(role)) {
        return 'Access denied. Admin credentials required.';
      }
      setAuth({ token: data.token, role, myrabaHandle: data.myrabaHandle });
      return null;
    } catch (err: any) {
      return err.response?.data?.message ?? 'Login failed. Check your credentials.';
    }
  }

  function logout() {
    setAuth({ token: null, role: null, myrabaHandle: null });
  }

  return (
    <AuthContext.Provider value={{
      ...auth,
      login,
      logout,
      isAdmin:      ['ADMIN', 'SUPER_ADMIN', 'STAFF'].includes(auth.role ?? ''),
      isSuperAdmin: auth.role === 'SUPER_ADMIN',
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

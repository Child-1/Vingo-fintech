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
  isValidating: boolean;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const storedToken = localStorage.getItem('myraba_admin_token');
  const [auth, setAuth] = useState<AuthState>({
    token: storedToken,
    role:  localStorage.getItem('myraba_admin_role'),
    myrabaHandle: localStorage.getItem('myraba_admin_handle'),
  });
  // True while we're verifying a stored token with the backend
  const [isValidating, setIsValidating] = useState<boolean>(!!storedToken);

  // On mount: if we have a stored token, verify it's still valid
  useEffect(() => {
    if (!storedToken) return;
    api.get('/api/users/me')
      .then(({ data }) => {
        const role: string = data.role ?? '';
        if (!['ADMIN', 'SUPER_ADMIN', 'STAFF'].includes(role)) {
          // Valid token but not an admin — clear and force login
          clearAuth();
        } else {
          setAuth(prev => ({ ...prev, role, myrabaHandle: data.myrabaHandle }));
        }
      })
      .catch(() => clearAuth())
      .finally(() => setIsValidating(false));
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function clearAuth() {
    setAuth({ token: null, role: null, myrabaHandle: null });
    ['myraba_admin_token', 'myraba_admin_role', 'myraba_admin_handle'].forEach(k =>
      localStorage.removeItem(k)
    );
  }

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

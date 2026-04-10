import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function AuthGuard() {
  const { token, isAdmin } = useAuth();
  if (!token || !isAdmin) return <Navigate to="/login" replace />;
  return <Outlet />;
}

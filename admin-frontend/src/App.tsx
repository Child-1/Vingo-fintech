import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider } from './context/AuthContext';
import AuthGuard from './components/AuthGuard';
import Layout from './components/Layout';

import LoginPage                  from './pages/LoginPage';
import CompleteRegistrationPage   from './pages/CompleteRegistrationPage';
import OverviewPage      from './pages/OverviewPage';
import UsersPage         from './pages/UsersPage';
import KycPage           from './pages/KycPage';
import TransactionsPage  from './pages/TransactionsPage';
import ReportsPage       from './pages/ReportsPage';
import ThriftsPage       from './pages/ThriftsPage';
import GiftsPage         from './pages/GiftsPage';
import PointsPage        from './pages/PointsPage';
import BroadcastsPage    from './pages/BroadcastsPage';
import MyrabaTagsPage      from './pages/MyrabaTagsPage';
import StaffPage           from './pages/StaffPage';
import AuditPage         from './pages/AuditPage';
import SystemPage        from './pages/SystemPage';
import BalancePage       from './pages/BalancePage';
import SupportPage       from './pages/SupportPage';
import DisputesPage      from './pages/DisputesPage';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
    },
  },
});

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/complete-registration" element={<CompleteRegistrationPage />} />
            <Route element={<AuthGuard />}>
              <Route element={<Layout />}>
                <Route index element={<Navigate to="/overview" replace />} />
                <Route path="overview"       element={<OverviewPage />} />
                <Route path="users"          element={<UsersPage />} />
                <Route path="kyc"            element={<KycPage />} />
                <Route path="transactions"   element={<TransactionsPage />} />
                <Route path="reports"        element={<ReportsPage />} />
                <Route path="thrifts"        element={<ThriftsPage />} />
                <Route path="gifts"          element={<GiftsPage />} />
                <Route path="points"         element={<PointsPage />} />
                <Route path="broadcasts"     element={<BroadcastsPage />} />
                <Route path="myrabatags"       element={<MyrabaTagsPage />} />
                <Route path="audit"          element={<AuditPage />} />
                <Route path="system"         element={<SystemPage />} />
                <Route path="balance"        element={<BalancePage />} />
                <Route path="staff"          element={<StaffPage />} />
                <Route path="support"        element={<SupportPage />} />
                <Route path="disputes"       element={<DisputesPage />} />
                <Route path="*"             element={<Navigate to="/overview" replace />} />
              </Route>
            </Route>
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  );
}

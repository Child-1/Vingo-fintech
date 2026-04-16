import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';
import type { DashboardStats } from '../types';
import { formatNaira, formatNumber, formatDate } from '../lib/utils';
import StatCard from '../components/StatCard';
import {
  Users, Wallet, TrendingUp, PiggyBank, ShieldAlert,
  AlertCircle, Clock, Activity,
} from 'lucide-react';
import { useState } from 'react';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, Legend, BarChart, Bar,
} from 'recharts';

export default function OverviewPage() {
  const { data: stats, isLoading } = useQuery<DashboardStats>({
    queryKey: ['dashboard-stats'],
    queryFn: () => api.get('/api/admin/dashboard/stats').then(r => r.data),
    refetchInterval: 60_000,
  });

  const { data: reportData } = useQuery({
    queryKey: ['daily-breakdown'],
    queryFn: () => api.get('/api/admin/reports/daily-breakdown').then(r => r.data),
  });

  if (isLoading) return <PageSkeleton />;

  const s = stats!;

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-xl font-semibold text-white">Overview</h1>
        <p className="text-myraba-hint text-sm mt-0.5">Real-time platform metrics</p>
      </div>

      {/* ── Alert banner ── */}
      {(s.failedTransactions24h > 0 || s.kycPending > 0 || s.pendingPayouts > 0) && (
        <div className="flex flex-wrap gap-3">
          {s.failedTransactions24h > 0 && (
            <div className="flex items-center gap-2 bg-myraba-error/10 border border-myraba-error/20 text-myraba-error text-sm rounded-lg px-4 py-2">
              <AlertCircle size={14} />
              {s.failedTransactions24h} failed transactions in last 24h
            </div>
          )}
          {s.kycPending > 0 && (
            <div className="flex items-center gap-2 bg-myraba-gold/10 border border-myraba-gold/20 text-myraba-gold text-sm rounded-lg px-4 py-2">
              <ShieldAlert size={14} />
              {s.kycPending} KYC submissions pending review
            </div>
          )}
          {s.pendingPayouts > 0 && (
            <div className="flex items-center gap-2 bg-brand/10 border border-brand/20 text-brand text-sm rounded-lg px-4 py-2">
              <Clock size={14} />
              {s.pendingPayouts} thrift payouts pending
            </div>
          )}
        </div>
      )}

      {/* ── KPI grid ── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard label="Total Users"        value={formatNumber(s.totalUsers)}        sub={`+${s.newUsersToday} today`}           icon={Users}       accent="orange" trend="up" trendLabel="New today" />
        <StatCard label="System Liquidity"   value={formatNaira(s.systemLiquidity)}    sub="Total wallet balances"                 icon={Wallet}      accent="green"  />
        <StatCard label="Total Volume"       value={formatNaira(s.totalVolume)}        sub="All-time successful"                   icon={TrendingUp}  accent="purple" />
        <StatCard label="Thrift Pool"        value={formatNaira(s.totalLockedInThrifts)} sub={`${s.activeThrifts} active plans`}  icon={PiggyBank}   accent="yellow" />
        <StatCard label="Service Fees"       value={formatNaira(s.totalServiceFees)}   sub="All-time"                              icon={Activity}    accent="green"  />
        <StatCard label="KYC Pending"        value={formatNumber(s.kycPending)}        sub="Awaiting review"                      icon={ShieldAlert} accent="yellow" trend={s.kycPending > 10 ? 'down' : 'neutral'} trendLabel={s.kycPending > 10 ? 'High backlog' : undefined} />
        <StatCard label="Pending Payouts"    value={formatNumber(s.pendingPayouts)}    sub="Thrift payouts"                       icon={Clock}       accent="orange" />
        <StatCard label="Failed Txns (24h)"  value={formatNumber(s.failedTransactions24h)} sub="Last 24 hours"                   icon={AlertCircle} accent="red"    trend={s.failedTransactions24h > 5 ? 'down' : 'neutral'} />
      </div>

      {/* ── Volume chart ── */}
      {(reportData?.data ?? reportData?.dailyBreakdown) && (
        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-white font-medium text-sm">Transaction Volume — Last 30 Days</h2>
              <p className="text-myraba-hint text-xs mt-0.5">Daily successful transaction amounts</p>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={200}>
            <AreaChart data={reportData.data ?? reportData.dailyBreakdown}>
              <defs>
                <linearGradient id="vol" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%"  stopColor="#F26522" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#F26522" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#3D3060" />
              <XAxis dataKey="date" tick={{ fill: '#6B6185', fontSize: 11 }} tickLine={false} axisLine={false} />
              <YAxis tick={{ fill: '#6B6185', fontSize: 11 }} tickLine={false} axisLine={false}
                tickFormatter={v => `₦${(v/1000).toFixed(0)}k`} />
              <Tooltip
                contentStyle={{ background: '#141128', border: '1px solid #3D3060', borderRadius: 8 }}
                labelStyle={{ color: '#B0A8C8' }}
                formatter={(v) => [formatNaira(Number(v)), 'Volume']}
              />
              <Area type="monotone" dataKey="volume" stroke="#F26522" fill="url(#vol)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* ── User distribution & growth ── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {/* Pie: user account status */}
        <div className="card">
          <h2 className="text-white font-medium text-sm mb-4">User Account Status</h2>
          <UserStatusPieChart stats={s} />
        </div>
        {/* Pie: KYC status */}
        <div className="card">
          <h2 className="text-white font-medium text-sm mb-4">KYC Status Distribution</h2>
          <KycPieChart stats={s} />
        </div>
      </div>

      {/* ── User growth chart ── */}
      <UserGrowthChart />

      {/* ── Recent transactions ── */}
      <div className="card">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-white font-medium text-sm">Recent Transactions</h2>
          <a href="/transactions" className="text-brand text-xs hover:opacity-80">View all →</a>
        </div>
        <RecentTransactions />
      </div>
    </div>
  );
}

const PIE_COLORS = ['#10B981', '#F59E0B', '#EF4444', '#6366F1', '#F26522', '#14B8A6'];

function UserStatusPieChart({ stats }: { stats: DashboardStats }) {
  const data = [
    { name: 'Active',    value: (stats.totalUsers ?? 0) - ((stats as any).frozenUsers ?? 0) - ((stats as any).suspendedUsers ?? 0) },
    { name: 'Frozen',    value: (stats as any).frozenUsers ?? 0 },
    { name: 'Suspended', value: (stats as any).suspendedUsers ?? 0 },
  ].filter(d => d.value > 0);
  if (data.length === 0) return <p className="text-myraba-hint text-sm text-center py-8">No data yet.</p>;
  return (
    <ResponsiveContainer width="100%" height={200}>
      <PieChart>
        <Pie data={data} cx="50%" cy="50%" outerRadius={70} dataKey="value" label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
          labelLine={false}>
          {data.map((_, i) => <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />)}
        </Pie>
        <Tooltip contentStyle={{ background: '#141128', border: '1px solid #3D3060', borderRadius: 8 }}
          formatter={(v: any) => [formatNumber(v), '']} />
        <Legend wrapperStyle={{ color: '#B0A8C8', fontSize: 12 }} />
      </PieChart>
    </ResponsiveContainer>
  );
}

function KycPieChart({ stats }: { stats: DashboardStats }) {
  const data = [
    { name: 'Approved', value: (stats as any).kycApproved ?? 0 },
    { name: 'Pending',  value: stats.kycPending ?? 0 },
    { name: 'Rejected', value: (stats as any).kycRejected ?? 0 },
    { name: 'None',     value: Math.max(0, (stats.totalUsers ?? 0) - ((stats as any).kycApproved ?? 0) - (stats.kycPending ?? 0) - ((stats as any).kycRejected ?? 0)) },
  ].filter(d => d.value > 0);
  if (data.length === 0) return <p className="text-myraba-hint text-sm text-center py-8">No data yet.</p>;
  const colors = ['#10B981', '#F59E0B', '#EF4444', '#6B6185'];
  return (
    <ResponsiveContainer width="100%" height={200}>
      <PieChart>
        <Pie data={data} cx="50%" cy="50%" outerRadius={70} dataKey="value"
          label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`} labelLine={false}>
          {data.map((_, i) => <Cell key={i} fill={colors[i % colors.length]} />)}
        </Pie>
        <Tooltip contentStyle={{ background: '#141128', border: '1px solid #3D3060', borderRadius: 8 }}
          formatter={(v: any) => [formatNumber(v), '']} />
        <Legend wrapperStyle={{ color: '#B0A8C8', fontSize: 12 }} />
      </PieChart>
    </ResponsiveContainer>
  );
}

const GROWTH_PERIODS = ['hourly', 'daily', 'weekly', 'monthly', 'yearly'] as const;
const GROWTH_COUNTS: Record<string, number> = { hourly: 24, daily: 30, weekly: 12, monthly: 12, yearly: 5 };
const GROWTH_BAR_COLORS = ['#6366F1', '#10B981', '#F59E0B', '#F26522', '#14B8A6'];

function UserGrowthChart() {
  const [period, setPeriod] = useState<string>('daily');
  const { data, isLoading } = useQuery({
    queryKey: ['user-growth', period],
    queryFn: () => api.get('/api/admin/users/growth', { params: { period, count: GROWTH_COUNTS[period] } }).then(r => r.data),
    staleTime: 60_000,
  });
  const chartData = data?.data ?? [];
  const colorIdx = GROWTH_PERIODS.indexOf(period as any);
  const barColor = GROWTH_BAR_COLORS[colorIdx] ?? '#6366F1';

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-4 flex-wrap gap-2">
        <div>
          <h2 className="text-white font-medium text-sm">User Growth</h2>
          <p className="text-myraba-hint text-xs mt-0.5">New registrations over time</p>
        </div>
        <div className="flex gap-1">
          {GROWTH_PERIODS.map(p => (
            <button key={p} onClick={() => setPeriod(p)}
              className={`px-2.5 py-1 rounded text-xs font-medium transition-colors ${
                period === p ? 'text-white' : 'text-myraba-hint hover:text-myraba-second'
              }`}
              style={period === p ? { backgroundColor: barColor } : {}}>
              {p.charAt(0).toUpperCase() + p.slice(1)}
            </button>
          ))}
        </div>
      </div>
      {isLoading ? <div className="h-48 animate-pulse bg-surface-elevated rounded" /> : (
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={chartData} margin={{ top: 4, right: 0, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#3D3060" vertical={false} />
            <XAxis dataKey="label" tick={{ fill: '#6B6185', fontSize: 10 }} tickLine={false} axisLine={false} />
            <YAxis tick={{ fill: '#6B6185', fontSize: 11 }} tickLine={false} axisLine={false} allowDecimals={false} />
            <Tooltip contentStyle={{ background: '#141128', border: '1px solid #3D3060', borderRadius: 8 }}
              labelStyle={{ color: '#B0A8C8' }} formatter={(v: any) => [formatNumber(v), 'New users']} />
            <Bar dataKey="count" fill={barColor} radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}

function RecentTransactions() {
  const { data } = useQuery({
    queryKey: ['recent-transactions'],
    queryFn: () => api.get('/api/admin/transactions?page=0&size=8').then(r => r.data),
  });

  if (!data?.transactions?.length) return <p className="text-myraba-hint text-sm">No transactions yet.</p>;

  return (
    <div className="overflow-x-auto">
      <table className="data-table">
        <thead>
          <tr>
            <th>ID</th><th>Type</th><th>From</th><th>To</th>
            <th>Amount</th><th>Status</th><th>Date</th>
          </tr>
        </thead>
        <tbody>
          {data.transactions.map((tx: any) => (
            <tr key={tx.id}>
              <td className="text-myraba-hint font-mono text-xs">#{tx.id}</td>
              <td><span className="badge badge-orange">{tx.type}</span></td>
              <td className="text-myraba-second">{tx.senderHandle ?? '—'}</td>
              <td className="text-myraba-second">{tx.receiverHandle ?? '—'}</td>
              <td className="text-white font-medium">{formatNaira(tx.amount)}</td>
              <td>
                <span className={tx.status === 'SUCCESS' ? 'badge-green' : tx.status === 'FAILED' ? 'badge-red' : 'badge-yellow'}>
                  {tx.status}
                </span>
              </td>
              <td className="text-myraba-hint text-xs">{formatDate(tx.createdAt)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function PageSkeleton() {
  return (
    <div className="p-6 space-y-6 animate-pulse">
      <div className="h-6 bg-surface-card rounded w-40" />
      <div className="grid grid-cols-4 gap-4">
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} className="card h-28 bg-surface-elevated" />
        ))}
      </div>
    </div>
  );
}

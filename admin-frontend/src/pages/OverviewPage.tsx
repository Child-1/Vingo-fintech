import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';
import type { DashboardStats } from '../types';
import { formatNaira, formatNumber, formatDate } from '../lib/utils';
import StatCard from '../components/StatCard';
import {
  Users, Wallet, TrendingUp, PiggyBank, ShieldAlert,
  AlertCircle, Clock, Activity,
} from 'lucide-react';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
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
      {reportData?.dailyBreakdown && (
        <div className="card">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-white font-medium text-sm">Transaction Volume — Last 30 Days</h2>
              <p className="text-myraba-hint text-xs mt-0.5">Daily successful transaction amounts</p>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={200}>
            <AreaChart data={reportData.dailyBreakdown}>
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
              <Area type="monotone" dataKey="totalAmount" stroke="#F26522" fill="url(#vol)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}

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

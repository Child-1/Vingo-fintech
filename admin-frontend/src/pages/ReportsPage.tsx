import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatNaira, formatNumber } from '../lib/utils';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  LineChart, Line, Legend, PieChart, Pie, Cell,
} from 'recharts';
import { Download } from 'lucide-react';

export default function ReportsPage() {
  const [from, setFrom] = useState('');
  const [to,   setTo]   = useState('');

  const { data: totals } = useQuery({
    queryKey: ['report-totals'],
    queryFn: () => api.get('/api/admin/reports/totals').then(r => r.data),
  });

  const { data: txSummary } = useQuery({
    queryKey: ['tx-summary'],
    queryFn: () => api.get('/api/admin/transactions/summary').then(r => r.data),
  });

  const { data: userStats } = useQuery({
    queryKey: ['user-stats-overview'],
    queryFn: () => api.get('/api/admin/users/stats/overview').then(r => r.data),
  });

  useQuery({
    queryKey: ['report-monthly'],
    queryFn: () => api.get('/api/admin/reports/monthly').then(r => r.data),
  });

  const { data: breakdown } = useQuery({
    queryKey: ['report-breakdown'],
    queryFn: () => api.get('/api/admin/reports/daily-breakdown').then(r => r.data),
  });

  const { data: rangeData, refetch: fetchRange, isFetching } = useQuery({
    queryKey: ['report-range', from, to],
    queryFn: () => api.get('/api/admin/reports/range', { params: {
      from: `${from}T00:00:00`, to: `${to}T23:59:59`
    }}).then(r => r.data),
    enabled: false,
  });

  function exportCSV() {
    if (!breakdown?.dailyBreakdown) return;
    const rows = [['Date','Volume','Transactions','Fees'],
      ...breakdown.dailyBreakdown.map((d: any) => [d.date, d.totalAmount, d.txCount, d.fees])];
    const csv = rows.map(r => r.join(',')).join('\n');
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
    a.download = `myraba-daily-report-${new Date().toISOString().slice(0,10)}.csv`;
    a.click();
  }

  const chartData = (breakdown?.data ?? breakdown?.dailyBreakdown ?? []).map((d: any) => ({
    date: d.date?.slice(5),   // MM-DD
    volume: Number(d.volume ?? d.totalAmount ?? 0),
    txCount: Number(d.count ?? d.txCount ?? 0),
    fees: Number(d.fees ?? 0),
  }));

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-white">Reports</h1>
          <p className="text-myraba-hint text-sm">Platform financial overview</p>
        </div>
        <button onClick={exportCSV} className="btn-ghost flex items-center gap-2">
          <Download size={14} /> Export 30-day CSV
        </button>
      </div>

      {/* All-time totals */}
      {totals && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            { label: 'Total Volume',      value: formatNaira(totals.allTimeVolume ?? totals.totalVolume ?? 0),      accent: 'text-myraba-success' },
            { label: 'Total Fees',        value: formatNaira(totals.allTimeFees ?? totals.totalFees ?? 0),          accent: 'text-brand' },
            { label: 'Total Users',       value: formatNumber(totals.totalUsers ?? 0),                             accent: 'text-white' },
            { label: 'System Liquidity',  value: formatNaira(totals.systemLiquidity ?? 0),                         accent: 'text-myraba-success' },
          ].map(({ label, value, accent }) => (
            <div key={label} className="card">
              <p className="text-myraba-second text-xs">{label}</p>
              <p className={`text-2xl font-bold mt-1 ${accent}`}>{value}</p>
              <p className="text-myraba-hint text-xs mt-1">All-time</p>
            </div>
          ))}
        </div>
      )}

      {/* 30-day volume bar chart */}
      {chartData.length > 0 && (
        <div className="card">
          <h2 className="text-white font-medium text-sm mb-4">Daily Volume — Last 30 Days</h2>
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={chartData} margin={{ top: 4, right: 0, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#3D3060" vertical={false} />
              <XAxis dataKey="date" tick={{ fill: '#6B6185', fontSize: 11 }} tickLine={false} axisLine={false} />
              <YAxis tick={{ fill: '#6B6185', fontSize: 11 }} tickLine={false} axisLine={false}
                tickFormatter={v => `₦${(v/1000).toFixed(0)}k`} />
              <Tooltip
                contentStyle={{ background: '#141128', border: '1px solid #3D3060', borderRadius: 8 }}
                formatter={(v: unknown) => [formatNaira(Number(v)), 'Volume']}
              />
              <Bar dataKey="volume" fill="#F26522" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Tx count + fees line chart */}
      {chartData.length > 0 && (
        <div className="card">
          <h2 className="text-white font-medium text-sm mb-4">Transactions & Fees — Last 30 Days</h2>
          <ResponsiveContainer width="100%" height={200}>
            <LineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#3D3060" />
              <XAxis dataKey="date" tick={{ fill: '#6B6185', fontSize: 11 }} tickLine={false} axisLine={false} />
              <YAxis yAxisId="left" tick={{ fill: '#6B6185', fontSize: 11 }} tickLine={false} axisLine={false} />
              <YAxis yAxisId="right" orientation="right" tick={{ fill: '#6B6185', fontSize: 11 }} tickLine={false} axisLine={false} tickFormatter={v => `₦${v}`} />
              <Tooltip contentStyle={{ background: '#141128', border: '1px solid #3D3060', borderRadius: 8 }} />
              <Legend wrapperStyle={{ color: '#B0A8C8', fontSize: 12 }} />
              <Line yAxisId="left" type="monotone" dataKey="txCount" stroke="#10B981" strokeWidth={2} dot={false} name="Txn count" />
              <Line yAxisId="right" type="monotone" dataKey="fees"    stroke="#F59E0B" strokeWidth={2} dot={false} name="Fees (₦)" />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* ── Distribution pie charts ── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {userStats && (
          <div className="card">
            <h2 className="text-white font-medium text-sm mb-4">User Status Distribution</h2>
            <ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie
                  data={[
                    { name: 'Active',    value: userStats.active    ?? 0 },
                    { name: 'Suspended', value: userStats.suspended ?? 0 },
                    { name: 'Frozen',    value: userStats.frozen    ?? 0 },
                  ].filter(d => d.value > 0)}
                  cx="50%" cy="50%" outerRadius={80} dataKey="value"
                  label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                  labelLine={false}>
                  {['#10B981','#F59E0B','#EF4444'].map((c, i) => <Cell key={i} fill={c} />)}
                </Pie>
                <Tooltip contentStyle={{ background: '#141128', border: '1px solid #3D3060', borderRadius: 8 }}
                  formatter={(v: any) => [formatNumber(v), '']} />
                <Legend wrapperStyle={{ color: '#B0A8C8', fontSize: 12 }} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        )}

        {userStats && (
          <div className="card">
            <h2 className="text-white font-medium text-sm mb-4">KYC Status Distribution</h2>
            <ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie
                  data={[
                    { name: 'Approved', value: userStats.kycApproved ?? 0 },
                    { name: 'Pending',  value: userStats.kycPending  ?? 0 },
                    { name: 'Rejected', value: userStats.kycRejected ?? 0 },
                    { name: 'No KYC',   value: Math.max(0, (userStats.total ?? 0) - (userStats.kycApproved ?? 0) - (userStats.kycPending ?? 0) - (userStats.kycRejected ?? 0)) },
                  ].filter(d => d.value > 0)}
                  cx="50%" cy="50%" outerRadius={80} dataKey="value"
                  label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                  labelLine={false}>
                  {['#10B981','#F59E0B','#EF4444','#6B6185'].map((c, i) => <Cell key={i} fill={c} />)}
                </Pie>
                <Tooltip contentStyle={{ background: '#141128', border: '1px solid #3D3060', borderRadius: 8 }}
                  formatter={(v: any) => [formatNumber(v), '']} />
                <Legend wrapperStyle={{ color: '#B0A8C8', fontSize: 12 }} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>

      {/* ── Transaction breakdown: income vs fees bar ── */}
      {txSummary && (
        <div className="card">
          <h2 className="text-white font-medium text-sm mb-4">Platform Financial Summary</h2>
          <ResponsiveContainer width="100%" height={180}>
            <BarChart layout="vertical" margin={{ top: 0, right: 20, left: 20, bottom: 0 }}
              data={[
                { name: 'Total Volume',  value: Number(txSummary.totalVolume ?? 0) },
                { name: 'Fees Collected', value: Number(txSummary.totalFees ?? 0) },
                { name: 'Pending Payouts', value: Number(txSummary.pendingPayouts ?? 0) },
              ]}>
              <CartesianGrid strokeDasharray="3 3" stroke="#3D3060" horizontal={false} />
              <XAxis type="number" tick={{ fill: '#6B6185', fontSize: 11 }} tickLine={false} axisLine={false}
                tickFormatter={v => `₦${(v/1000).toFixed(0)}k`} />
              <YAxis type="category" dataKey="name" tick={{ fill: '#B0A8C8', fontSize: 12 }} tickLine={false} axisLine={false} width={110} />
              <Tooltip contentStyle={{ background: '#141128', border: '1px solid #3D3060', borderRadius: 8 }}
                formatter={(v: any) => [formatNaira(v), '']} />
              <Bar dataKey="value" radius={[0, 4, 4, 0]}>
                {['#10B981', '#F59E0B', '#6366F1'].map((c, i) => <Cell key={i} fill={c} />)}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Custom date range */}
      <div className="card space-y-4">
        <h2 className="text-white font-medium text-sm">Custom Date Range</h2>
        <div className="flex flex-wrap gap-3 items-end">
          <div>
            <label className="text-myraba-second text-xs block mb-1">From</label>
            <input type="date" className="input w-auto" value={from} onChange={e => setFrom(e.target.value)} />
          </div>
          <div>
            <label className="text-myraba-second text-xs block mb-1">To</label>
            <input type="date" className="input w-auto" value={to} onChange={e => setTo(e.target.value)} />
          </div>
          <button className="btn-primary" disabled={!from || !to || isFetching}
            onClick={() => fetchRange()}>
            {isFetching ? 'Loading…' : 'Generate Report'}
          </button>
        </div>

        {rangeData && (
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 pt-2">
            {[
              ['Volume',        formatNaira(rangeData.totalVolume ?? 0)],
              ['Fees',          formatNaira(rangeData.totalFees ?? 0)],
              ['Transactions',  formatNumber(rangeData.totalTransactions ?? 0)],
              ['Success Rate',  `${rangeData.successRate ?? 0}%`],
            ].map(([label, value]) => (
              <div key={label} className="bg-surface-elevated rounded-lg p-3">
                <p className="text-myraba-second text-xs">{label}</p>
                <p className="text-white font-semibold mt-1">{value}</p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatDate } from '../lib/utils';
import { ShieldAlert, ChevronLeft, ChevronRight } from 'lucide-react';

const PAGE_SIZE = 25;

const ACTIONS = [
  'KYC_UPDATE','ROLE_CHANGE','USER_FREEZE','USER_SUSPEND','USER_ACTIVATE',
  'TRANSACTION_REVERSE','BALANCE_ADJUST','POINTS_GRANT','POINTS_CONVERT',
  'BROADCAST_CREATE','BROADCAST_DEACTIVATE','THRIFT_ACTIVATE','THRIFT_DEACTIVATE',
  'GIFT_ITEM_UPDATE','VINGTAG_APPROVE','VINGTAG_DENY',
];

export default function AuditPage() {
  const [adminHandle, setAdminHandle] = useState('');
  const [action,      setAction]      = useState('');
  const [from,        setFrom]        = useState('');
  const [to,          setTo]          = useState('');
  const [page,        setPage]        = useState(0);

  const params: Record<string, string> = {
    page: String(page), size: String(PAGE_SIZE),
    ...(adminHandle && { adminHandle }),
    ...(action      && { action }),
    ...(from        && { from: `${from}T00:00:00` }),
    ...(to          && { to:   `${to}T23:59:59` }),
  };

  const { data, isLoading } = useQuery({
    queryKey: ['audit-logs', params],
    queryFn: () => api.get('/api/admin/audit', { params }).then(r => r.data),
  });

  const logs  = data?.logs ?? (Array.isArray(data) ? data : []);
  const total = data?.total ?? logs.length;
  const totalPages = Math.ceil(total / PAGE_SIZE);

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-semibold text-white">Audit Log</h1>
        <p className="text-myraba-hint text-sm">{total.toLocaleString()} entries</p>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <input className="input w-auto" placeholder="Admin MyrabaTag" value={adminHandle}
          onChange={e => { setAdminHandle(e.target.value); setPage(0); }} />
        <select className="input w-auto" value={action} onChange={e => { setAction(e.target.value); setPage(0); }}>
          <option value="">All actions</option>
          {ACTIONS.map(a => <option key={a} value={a}>{a}</option>)}
        </select>
        <input type="date" className="input w-auto" value={from}
          onChange={e => { setFrom(e.target.value); setPage(0); }} />
        <input type="date" className="input w-auto" value={to}
          onChange={e => { setTo(e.target.value); setPage(0); }} />
        {(adminHandle || action || from || to) && (
          <button className="btn-ghost text-sm" onClick={() => { setAdminHandle(''); setAction(''); setFrom(''); setTo(''); setPage(0); }}>
            Clear
          </button>
        )}
      </div>

      <div className="card p-0 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr><th>Time</th><th>Admin</th><th>Action</th><th>Target</th><th>Before</th><th>After</th></tr>
            </thead>
            <tbody>
              {isLoading
                ? Array.from({ length: 10 }).map((_, i) => (
                  <tr key={i}>{Array.from({ length: 6 }).map((_, j) => (
                    <td key={j}><div className="h-4 bg-surface-elevated rounded animate-pulse w-16" /></td>
                  ))}</tr>
                ))
                : logs.length === 0
                  ? (
                    <tr>
                      <td colSpan={6}>
                        <div className="flex flex-col items-center py-12 text-center">
                          <ShieldAlert size={40} className="text-myraba-hint mb-3" />
                          <p className="text-myraba-second">No audit entries found.</p>
                        </div>
                      </td>
                    </tr>
                  )
                  : logs.map((log: any) => (
                    <tr key={log.id}>
                      <td className="text-myraba-hint text-xs whitespace-nowrap">{formatDate(log.createdAt)}</td>
                      <td className="text-myraba-second text-xs font-mono">@{log.adminHandle}</td>
                      <td>
                        <span className="badge badge-orange text-xs">{log.action}</span>
                      </td>
                      <td className="text-myraba-second text-xs">
                        {log.targetType && <span className="badge badge-gray mr-1">{log.targetType}</span>}
                        {log.targetId && <span className="font-mono">#{log.targetId}</span>}
                      </td>
                      <td className="text-myraba-hint text-xs max-w-[160px] truncate font-mono">{log.beforeValue ?? '—'}</td>
                      <td className="text-myraba-second text-xs max-w-[160px] truncate font-mono">{log.afterValue ?? '—'}</td>
                    </tr>
                  ))}
            </tbody>
          </table>
        </div>

        <div className="flex items-center justify-between px-4 py-3 border-t border-surface-border">
          <p className="text-myraba-hint text-xs">Page {page + 1} of {totalPages || 1}</p>
          <div className="flex gap-2">
            <button className="btn-ghost px-2 py-1" disabled={page === 0} onClick={() => setPage(p => p - 1)}>
              <ChevronLeft size={16} />
            </button>
            <button className="btn-ghost px-2 py-1" disabled={page >= totalPages - 1} onClick={() => setPage(p => p + 1)}>
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

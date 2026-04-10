import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import type { Transaction } from '../types';
import { formatNaira, formatDate, txStatusBadge } from '../lib/utils';
import { ChevronLeft, ChevronRight, X, RotateCcw, Download } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

const PAGE_SIZE = 20;

const TX_TYPES = ['TRANSFER','FUNDED','WITHDRAWAL','CONTRIBUTION','PAYOUT','PENALTY','ADMIN_CREDIT','ADMIN_DEBIT','REVERSAL','BILL_PAYMENT','GIFT'];

export default function TransactionsPage() {
  const qc = useQueryClient();
  const { role } = useAuth();
  const canReverse = role === 'ADMIN' || role === 'SUPER_ADMIN';

  const [type,    setType]    = useState('');
  const [status,  setStatus]  = useState('');
  const [from,    setFrom]    = useState('');
  const [to,      setTo]      = useState('');
  const [minAmt,  setMinAmt]  = useState('');
  const [maxAmt,  setMaxAmt]  = useState('');
  const [page,    setPage]    = useState(0);
  const [selected, setSelected] = useState<Transaction | null>(null);
  const [reverseReason, setReverseReason] = useState('');
  const [showReverseDialog, setShowReverseDialog] = useState(false);

  const params: Record<string, string> = {
    page: String(page), size: String(PAGE_SIZE),
    ...(type   && { type }),
    ...(status && { status }),
    ...(from   && { from: `${from}T00:00:00` }),
    ...(to     && { to:   `${to}T23:59:59` }),
    ...(minAmt && { minAmount: minAmt }),
    ...(maxAmt && { maxAmount: maxAmt }),
  };

  const { data, isLoading } = useQuery({
    queryKey: ['admin-transactions', params],
    queryFn: () => api.get('/api/admin/transactions', { params }).then(r => r.data),
  });

  const { data: summary } = useQuery({
    queryKey: ['tx-summary'],
    queryFn: () => api.get('/api/admin/transactions/summary').then(r => r.data),
  });

  const reverse = useMutation({
    mutationFn: ({ id, reason }: { id: number; reason: string }) =>
      api.post(`/api/admin/transactions/${id}/reverse`, { reason }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-transactions'] });
      setShowReverseDialog(false);
      setSelected(null);
      setReverseReason('');
    },
  });

  const txs: Transaction[] = data?.transactions ?? [];
  const total = data?.total ?? 0;
  const totalPages = Math.ceil(total / PAGE_SIZE);

  function exportCSV() {
    const rows = [
      ['ID','Type','Sender','Receiver','Amount','Fee','Status','Date','Description'],
      ...txs.map(t => [t.id, t.type, t.senderHandle ?? '', t.receiverHandle ?? '',
        t.amount, t.fee ?? '', t.status, t.createdAt, t.description ?? '']),
    ];
    const csv = rows.map(r => r.join(',')).join('\n');
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
    a.download = `myraba-transactions-${new Date().toISOString().slice(0,10)}.csv`;
    a.click();
  }

  return (
    <div className="p-6 space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-white">Transactions</h1>
          <p className="text-myraba-hint text-sm">{total.toLocaleString()} total</p>
        </div>
        <div className="flex gap-3">
          {summary && (
            <div className="flex gap-4 text-center text-sm">
              <div><p className="text-myraba-hint text-xs">Total volume</p>
                <p className="font-semibold text-myraba-success">{formatNaira(summary.totalVolume)}</p></div>
              <div><p className="text-myraba-hint text-xs">Fees</p>
                <p className="font-semibold">{formatNaira(summary.totalFees)}</p></div>
              <div><p className="text-myraba-hint text-xs">Failed (24h)</p>
                <p className="font-semibold text-myraba-error">{summary.failedLast24h}</p></div>
            </div>
          )}
          <button onClick={exportCSV} className="btn-ghost flex items-center gap-2">
            <Download size={14} /> Export CSV
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <select className="input w-auto" value={type} onChange={e => { setType(e.target.value); setPage(0); }}>
          <option value="">All types</option>
          {TX_TYPES.map(t => <option key={t} value={t}>{t}</option>)}
        </select>
        <select className="input w-auto" value={status} onChange={e => { setStatus(e.target.value); setPage(0); }}>
          <option value="">All statuses</option>
          <option value="SUCCESS">SUCCESS</option>
          <option value="FAILED">FAILED</option>
          <option value="PENDING">PENDING</option>
        </select>
        <input type="date" className="input w-auto" value={from} onChange={e => { setFrom(e.target.value); setPage(0); }} />
        <input type="date" className="input w-auto" value={to}   onChange={e => { setTo(e.target.value);   setPage(0); }} />
        <input type="number" className="input w-28" placeholder="Min ₦" value={minAmt}
          onChange={e => { setMinAmt(e.target.value); setPage(0); }} />
        <input type="number" className="input w-28" placeholder="Max ₦" value={maxAmt}
          onChange={e => { setMaxAmt(e.target.value); setPage(0); }} />
        {(type || status || from || to || minAmt || maxAmt) && (
          <button className="btn-ghost" onClick={() => { setType(''); setStatus(''); setFrom(''); setTo(''); setMinAmt(''); setMaxAmt(''); setPage(0); }}>
            Clear filters
          </button>
        )}
      </div>

      {/* Table */}
      <div className="card p-0 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="data-table">
            <thead>
              <tr>
                <th>ID</th><th>Type</th><th>From</th><th>To</th>
                <th>Amount</th><th>Fee</th><th>Status</th><th>Date</th>
              </tr>
            </thead>
            <tbody>
              {isLoading
                ? Array.from({ length: 10 }).map((_, i) => (
                  <tr key={i}>{Array.from({ length: 8 }).map((_, j) => (
                    <td key={j}><div className="h-4 bg-surface-elevated rounded animate-pulse w-16" /></td>
                  ))}</tr>
                ))
                : txs.map(tx => (
                  <tr key={tx.id} onClick={() => setSelected(tx)} className="cursor-pointer">
                    <td className="font-mono text-myraba-hint text-xs">#{tx.id}</td>
                    <td><span className="badge badge-orange text-xs">{tx.type}</span></td>
                    <td className="text-myraba-second text-xs">{tx.senderHandle ?? '—'}</td>
                    <td className="text-myraba-second text-xs">{tx.receiverHandle ?? '—'}</td>
                    <td className="text-white font-medium">{formatNaira(tx.amount)}</td>
                    <td className="text-myraba-hint text-xs">{tx.fee ? formatNaira(tx.fee) : '—'}</td>
                    <td><span className={txStatusBadge(tx.status)}>{tx.status}</span></td>
                    <td className="text-myraba-hint text-xs">{formatDate(tx.createdAt)}</td>
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

      {/* Detail drawer */}
      {selected && (
        <div className="fixed inset-0 z-50 flex" onClick={() => setSelected(null)}>
          <div className="flex-1 bg-black/50 backdrop-blur-sm" />
          <div className="w-[440px] bg-surface-card border-l border-surface-border overflow-y-auto"
               onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between px-6 py-4 border-b border-surface-border sticky top-0 bg-surface-card z-10">
              <h2 className="font-semibold text-white">Transaction #{selected.id}</h2>
              <button onClick={() => setSelected(null)} className="text-myraba-second hover:text-white"><X size={18} /></button>
            </div>

            <div className="p-6 space-y-4">
              <div className="flex items-center gap-3">
                <span className="badge badge-orange text-sm">{selected.type}</span>
                <span className={txStatusBadge(selected.status)}>{selected.status}</span>
              </div>

              <div className="text-3xl font-bold text-white">{formatNaira(selected.amount)}</div>
              {selected.fee && <p className="text-myraba-hint text-sm">Fee: {formatNaira(selected.fee)}</p>}

              <div className="space-y-3 text-sm">
                {[
                  ['From',        selected.senderHandle ?? '—'],
                  ['To',          selected.receiverHandle ?? '—'],
                  ['Description', selected.description ?? '—'],
                  ['Date',        formatDate(selected.createdAt)],
                ].map(([k, v]) => (
                  <div key={k} className="flex justify-between">
                    <span className="text-myraba-hint">{k}</span>
                    <span className="text-white text-right max-w-[280px] truncate">{v}</span>
                  </div>
                ))}
              </div>

              {canReverse && selected.status === 'SUCCESS' &&
               ['TRANSFER','FUNDED','ADMIN_CREDIT'].includes(selected.type) && (
                <div className="pt-2">
                  {!showReverseDialog ? (
                    <button className="btn-danger w-full flex items-center justify-center gap-2"
                      onClick={() => setShowReverseDialog(true)}>
                      <RotateCcw size={14} /> Reverse Transaction
                    </button>
                  ) : (
                    <div className="space-y-3">
                      <p className="text-myraba-gold text-xs">⚠ This will refund the sender and deduct from the receiver. This action is audited.</p>
                      <textarea className="input h-20 resize-none" placeholder="Reason for reversal (required)"
                        value={reverseReason} onChange={e => setReverseReason(e.target.value)} />
                      <div className="flex gap-2">
                        <button className="btn-ghost flex-1" onClick={() => setShowReverseDialog(false)}>Cancel</button>
                        <button className="btn-danger flex-1"
                          disabled={!reverseReason.trim() || reverse.isPending}
                          onClick={() => reverse.mutate({ id: selected.id, reason: reverseReason })}>
                          {reverse.isPending ? 'Reversing…' : 'Confirm Reverse'}
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

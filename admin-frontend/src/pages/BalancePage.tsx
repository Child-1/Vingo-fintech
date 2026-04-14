import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatNaira } from '../lib/utils';
import { AlertTriangle, Wallet } from 'lucide-react';

type Direction = 'CREDIT' | 'DEBIT';

export default function BalancePage() {
  const [myrabaHandle, setVingHandle] = useState('');
  const [amount,     setAmount]     = useState('');
  const [direction,  setDirection]  = useState<Direction>('CREDIT');
  const [reason,     setReason]     = useState('');
  const [confirmed,  setConfirmed]  = useState(false);

  const adjust = useMutation({
    mutationFn: () =>
      api.post('/api/admin/balance/adjust', {
        myrabaHandle,
        amount: direction === 'DEBIT' ? -Number(amount) : Number(amount),
        reason,
      }),
    onSuccess: () => {
      setVingHandle('');
      setAmount('');
      setDirection('CREDIT');
      setReason('');
      setConfirmed(false);
    },
  });

  const isValid = myrabaHandle.trim() && Number(amount) > 0 && reason.trim();

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-semibold text-white">Balance Adjustment</h1>
        <p className="text-myraba-hint text-sm">SUPER_ADMIN — manually credit or debit any wallet</p>
      </div>

      <div className="max-w-lg space-y-5">
        {/* Warning banner */}
        <div className="flex items-start gap-3 bg-myraba-gold/10 border border-myraba-gold/30 rounded-xl p-4">
          <AlertTriangle size={18} className="text-myraba-gold flex-shrink-0 mt-0.5" />
          <div className="text-sm">
            <p className="text-myraba-gold font-medium">Privileged action</p>
            <p className="text-myraba-gold/80 mt-0.5">
              Every adjustment is written to the immutable audit log with your admin handle,
              the target wallet, amount, direction, and reason. There is no undo.
            </p>
          </div>
        </div>

        <div className="card space-y-4">
          {/* Direction toggle */}
          <div>
            <label className="text-myraba-second text-xs block mb-2">Direction</label>
            <div className="flex gap-2">
              {(['CREDIT', 'DEBIT'] as Direction[]).map(d => (
                <button
                  key={d}
                  onClick={() => setDirection(d)}
                  className={`flex-1 py-2 rounded-lg text-sm font-medium border transition-colors ${
                    direction === d
                      ? d === 'CREDIT'
                        ? 'bg-myraba-success/20 border-myraba-success/50 text-myraba-success'
                        : 'bg-myraba-error/20 border-myraba-error/50 text-myraba-error'
                      : 'border-surface-border text-myraba-second hover:text-white'
                  }`}>
                  {d === 'CREDIT' ? '+ Credit' : '− Debit'}
                </button>
              ))}
            </div>
          </div>

          {/* MyrabaTag */}
          <div>
            <label className="text-myraba-second text-xs block mb-1">User MyrabaTag</label>
            <input
              className="input"
              placeholder="e.g. johndoe (without @)"
              value={myrabaHandle}
              onChange={e => setVingHandle(e.target.value)}
            />
          </div>

          {/* Amount */}
          <div>
            <label className="text-myraba-second text-xs block mb-1">Amount (₦)</label>
            <input
              className="input"
              type="number"
              min="1"
              placeholder="0.00"
              value={amount}
              onChange={e => setAmount(e.target.value)}
            />
            {Number(amount) > 0 && (
              <p className="text-myraba-hint text-xs mt-1">
                = {formatNaira(Number(amount))}
              </p>
            )}
          </div>

          {/* Reason */}
          <div>
            <label className="text-myraba-second text-xs block mb-1">Reason (required)</label>
            <textarea
              className="input h-20 resize-none"
              placeholder="e.g. Refund for failed withdrawal ref #12345, approved by ops team"
              value={reason}
              onChange={e => setReason(e.target.value)}
            />
          </div>

          {/* Preview */}
          {isValid && (
            <div className="bg-surface-elevated rounded-lg p-3 text-sm space-y-1">
              <p className="text-myraba-second text-xs uppercase tracking-wider mb-2">Preview</p>
              <div className="flex justify-between">
                <span className="text-myraba-hint">Action</span>
                <span className={direction === 'CREDIT' ? 'text-myraba-success font-medium' : 'text-myraba-error font-medium'}>
                  {direction} {formatNaira(Number(amount))}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-myraba-hint">Wallet</span>
                <span className="text-white font-mono">@{myrabaHandle}</span>
              </div>
              <div className="flex justify-between gap-4">
                <span className="text-myraba-hint flex-shrink-0">Reason</span>
                <span className="text-myraba-second text-right text-xs">{reason}</span>
              </div>
            </div>
          )}

          {/* Confirm checkbox */}
          {isValid && (
            <label className="flex items-center gap-2 cursor-pointer select-none">
              <input
                type="checkbox"
                checked={confirmed}
                onChange={e => setConfirmed(e.target.checked)}
                className="w-4 h-4 rounded accent-brand-500"
              />
              <span className="text-myraba-second text-sm">
                I understand this is irreversible and will be audited.
              </span>
            </label>
          )}

          <button
            className={`w-full font-medium px-4 py-2 rounded-lg transition-colors text-sm
              disabled:opacity-50 disabled:cursor-not-allowed
              ${direction === 'CREDIT'
                ? 'bg-myraba-success/80 hover:bg-myraba-success text-white'
                : 'bg-myraba-error/80 hover:bg-myraba-error text-white'}`}
            disabled={!isValid || !confirmed || adjust.isPending}
            onClick={() => adjust.mutate()}
          >
            {adjust.isPending
              ? 'Processing…'
              : `Confirm ${direction === 'CREDIT' ? 'Credit' : 'Debit'}`}
          </button>

          {adjust.isSuccess && (
            <p className="text-myraba-success text-sm text-center">
              Adjustment applied successfully.
            </p>
          )}
          {adjust.isError && (
            <p className="text-myraba-error text-sm text-center">
              Failed — check the MyrabaTag and try again.
            </p>
          )}
        </div>

        {/* Info card */}
        <div className="card flex items-start gap-3">
          <Wallet size={16} className="text-myraba-hint flex-shrink-0 mt-0.5" />
          <div className="text-xs text-myraba-hint space-y-1">
            <p>Credits increase the user's wallet balance immediately.</p>
            <p>Debits reduce it — the operation will fail if the resulting balance would go negative.</p>
            <p>Both directions create a ADMIN_CREDIT or ADMIN_DEBIT transaction record visible to the user.</p>
          </div>
        </div>
      </div>
    </div>
  );
}

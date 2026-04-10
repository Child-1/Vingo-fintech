import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatNaira, formatNumber } from '../lib/utils';
import { Activity, Database, Cpu, CheckCircle2, XCircle, RefreshCw } from 'lucide-react';

function StatusDot({ ok }: { ok: boolean }) {
  return ok
    ? <CheckCircle2 size={16} className="text-myraba-success flex-shrink-0" />
    : <XCircle size={16} className="text-myraba-error flex-shrink-0" />;
}

export default function SystemPage() {
  const qc = useQueryClient();

  const { data: health, isLoading: healthLoading, refetch: refetchHealth } = useQuery({
    queryKey: ['system-health'],
    queryFn: () => api.get('/api/admin/system/health').then(r => r.data),
    refetchInterval: 30_000,
  });

  const { data: liquidity, isLoading: liqLoading, refetch: refetchLiq } = useQuery({
    queryKey: ['system-liquidity'],
    queryFn: () => api.get('/api/admin/system/liquidity').then(r => r.data),
  });

  const resolveDefaults = useMutation({
    mutationFn: () => api.post('/api/admin/thrifts/resolve-defaults'),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['system-health'] }),
  });

  function refetchAll() {
    refetchHealth();
    refetchLiq();
  }

  const isHealthy = health?.status === 'UP' || health?.status === 'OK';

  return (
    <div className="p-6 space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold text-white">System</h1>
          <p className="text-myraba-hint text-sm">Health &amp; liquidity overview</p>
        </div>
        <button className="btn-ghost flex items-center gap-2" onClick={refetchAll}>
          <RefreshCw size={14} /> Refresh
        </button>
      </div>

      {/* Health banner */}
      <div className={`card flex items-center gap-3 ${
        healthLoading ? '' : isHealthy ? 'border-myraba-success/30 bg-myraba-success/5' : 'border-myraba-error/30 bg-myraba-error/5'
      }`}>
        <Activity size={20} className={isHealthy ? 'text-myraba-success' : 'text-myraba-error'} />
        <div>
          <p className="text-white font-medium text-sm">
            {healthLoading ? 'Checking health…' : isHealthy ? 'All systems operational' : 'System issues detected'}
          </p>
          {health?.message && <p className="text-myraba-second text-xs mt-0.5">{health.message}</p>}
        </div>
        {!healthLoading && (
          <span className={`ml-auto badge ${isHealthy ? 'badge-green' : 'badge-red'}`}>
            {health?.status ?? 'UNKNOWN'}
          </span>
        )}
      </div>

      {/* Health components */}
      {health?.components && (
        <div className="card space-y-3">
          <h2 className="text-white font-medium text-sm">Components</h2>
          <div className="space-y-2">
            {Object.entries(health.components).map(([key, val]: [string, any]) => (
              <div key={key} className="flex items-center justify-between py-1.5">
                <div className="flex items-center gap-2">
                  {key.toLowerCase().includes('db') || key.toLowerCase().includes('database')
                    ? <Database size={14} className="text-myraba-second" />
                    : <Cpu size={14} className="text-myraba-second" />}
                  <span className="text-myraba-second text-sm capitalize">{key}</span>
                </div>
                <div className="flex items-center gap-2">
                  {val?.details && (
                    <span className="text-myraba-hint text-xs">{JSON.stringify(val.details)}</span>
                  )}
                  <StatusDot ok={val?.status === 'UP' || val === 'UP'} />
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Liquidity */}
      <div className="card space-y-4">
        <h2 className="text-white font-medium text-sm">Platform Liquidity</h2>
        {liqLoading ? (
          <p className="text-myraba-hint text-sm">Loading…</p>
        ) : liquidity ? (
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {[
              { label: 'Total Wallet Balances', value: formatNaira(liquidity.totalWalletBalance ?? 0), accent: 'text-myraba-success' },
              { label: 'Total Users',           value: formatNumber(liquidity.totalUsers ?? 0),        accent: 'text-white' },
              { label: 'Active Wallets',        value: formatNumber(liquidity.activeWallets ?? 0),     accent: 'text-brand' },
              { label: 'Thrift Pool Locked',    value: formatNaira(liquidity.thriftPoolLocked ?? 0),  accent: 'text-myraba-gold' },
            ].map(({ label, value, accent }) => (
              <div key={label} className="bg-surface-elevated rounded-lg p-4">
                <p className="text-myraba-second text-xs">{label}</p>
                <p className={`text-xl font-bold mt-1 ${accent}`}>{value}</p>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-myraba-hint text-sm">No liquidity data available.</p>
        )}
      </div>

      {/* Operations */}
      <div className="card space-y-4">
        <h2 className="text-white font-medium text-sm">Manual Operations</h2>
        <div className="flex flex-wrap gap-3">
          <div className="flex flex-col gap-1">
            <p className="text-myraba-second text-xs">Thrift Defaults</p>
            <button
              className="btn-ghost flex items-center gap-2 text-sm"
              disabled={resolveDefaults.isPending}
              onClick={() => resolveDefaults.mutate()}>
              <RefreshCw size={13} className={resolveDefaults.isPending ? 'animate-spin' : ''} />
              {resolveDefaults.isPending ? 'Resolving…' : 'Resolve Pending Defaults'}
            </button>
            {resolveDefaults.isSuccess && <p className="text-myraba-success text-xs">Done.</p>}
          </div>
        </div>
      </div>
    </div>
  );
}

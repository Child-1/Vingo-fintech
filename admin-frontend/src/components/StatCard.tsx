import type { FC, SVGProps } from 'react';
import { cn } from '../lib/utils';

type IconComponent = FC<SVGProps<SVGSVGElement> & { size?: number | string }>;

interface Props {
  label: string;
  value: string | number;
  sub?: string;
  icon: IconComponent;
  trend?: 'up' | 'down' | 'neutral';
  trendLabel?: string;
  accent?: 'orange' | 'green' | 'yellow' | 'red' | 'purple' | 'blue';
}

const accentMap = {
  orange: 'bg-brand/15 text-brand border border-brand/20',
  green:  'bg-myraba-success/15 text-myraba-success border border-myraba-success/20',
  yellow: 'bg-myraba-gold/15 text-myraba-gold border border-myraba-gold/20',
  red:    'bg-myraba-error/15 text-myraba-error border border-myraba-error/20',
  purple: 'bg-purple/15 text-purple border border-purple/20',
  blue:   'bg-myraba-info/15 text-myraba-info border border-myraba-info/20',
};

export default function StatCard({ label, value, sub, icon: Icon, trend, trendLabel, accent = 'orange' }: Props) {
  return (
    <div className="card flex flex-col gap-3">
      <div className="flex items-start justify-between">
        <p className="text-myraba-second text-sm">{label}</p>
        <span className={cn('w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0', accentMap[accent])}>
          <Icon size={18} />
        </span>
      </div>
      <div>
        <p className="text-2xl font-bold text-white leading-none">{value}</p>
        {sub && <p className="text-myraba-hint text-xs mt-1">{sub}</p>}
      </div>
      {trendLabel && (
        <p className={cn('text-xs font-medium', trend === 'up' ? 'text-myraba-success' : trend === 'down' ? 'text-myraba-error' : 'text-myraba-hint')}>
          {trend === 'up' ? '↑' : trend === 'down' ? '↓' : '—'} {trendLabel}
        </p>
      )}
    </div>
  );
}

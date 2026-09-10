'use client';

import { motion } from 'framer-motion';
import type { RankRow } from '@/lib/leaderboard';
import { TrophyIcon } from './TrophyIcon';

const MEDAL_COLOR = ['#f5c343', '#c7d0dd', '#f0a04b'];

/** A local, clearly-labeled ladder (see buildLocalLeaderboard) — not a real
 * cross-device backend ranking yet. */
export function RankTable({ rows }: { rows: RankRow[] }) {
  return (
    <div className="mt-8">
      <div className="mb-2 flex items-center justify-between">
        <span className="text-xs font-bold uppercase tracking-wider text-textDim [text-shadow:0_1px_3px_rgba(0,0,0,.8)]">Season ladder</span>
        <span className="text-xs text-textFaint [text-shadow:0_1px_3px_rgba(0,0,0,.8)]">Local preview</span>
      </div>
      <div className="overflow-hidden rounded-2xl border border-stroke/70 bg-surface/35 backdrop-blur-md">
        {rows.slice(0, 10).map((row, i) => (
          <motion.div
            key={`${row.name}-${i}`}
            initial={{ opacity: 0, x: -8 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: i * 0.03 }}
            className={`flex items-center justify-between px-4 py-2.5 text-sm ${row.isPlayer ? 'bg-gold/15' : i % 2 ? 'bg-bgAlt/20' : ''} ${
              i > 0 ? 'border-t border-stroke/60' : ''
            }`}
          >
            <div className="flex items-center gap-3">
              <span className="w-6 text-center font-black" style={{ color: MEDAL_COLOR[i] ?? '#5d6b82' }}>
                {i + 1}
              </span>
              <span className={`font-bold ${row.isPlayer ? 'text-gold' : 'text-text'}`}>
                {row.name}
                {row.isPlayer ? ' (You)' : ''}
              </span>
            </div>
            <span className="flex items-center gap-1 font-black text-teal">
              <TrophyIcon size={14} /> {row.trophies}
            </span>
          </motion.div>
        ))}
      </div>
    </div>
  );
}

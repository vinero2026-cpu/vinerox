'use client';

import { motion } from 'framer-motion';
import type { RankRow } from '@/lib/leaderboard';
import { TrophyIcon } from './TrophyIcon';

const MEDAL_COLOR = ['#f5c343', '#c7d0dd', '#f0a04b'];

function RankRowItem({ row, rank, index, topBorder = true }: { row: RankRow; rank: number; index: number; topBorder?: boolean }) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -8 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ delay: index * 0.03 }}
      className={`flex items-center justify-between px-4 py-2.5 text-sm ${row.isPlayer ? 'bg-gold/15' : index % 2 ? 'bg-bgAlt/20' : ''} ${topBorder ? 'border-t border-stroke/60' : ''}`}
    >
      <div className="flex items-center gap-3">
        <span className="w-6 text-center font-black" style={{ color: MEDAL_COLOR[rank - 1] ?? '#5d6b82' }}>
          {rank}
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
  );
}

/** A local, clearly-labeled ladder (see buildLocalLeaderboard) — not a real
 * cross-device backend ranking yet. The player is always visible: if their
 * rank falls outside the top 10, their row is pinned below a "···" divider
 * instead of silently disappearing off the truncated list. */
export function RankTable({ rows }: { rows: RankRow[] }) {
  const top = rows.slice(0, 10);
  const playerRank = rows.findIndex((r) => r.isPlayer);
  const playerInTop = playerRank >= 0 && playerRank < 10;

  return (
    <div className="mt-8">
      <div className="mb-2 flex items-center justify-between">
        <span className="text-xs font-bold uppercase tracking-wider text-textDim [text-shadow:0_1px_3px_rgba(0,0,0,.8)]">Season ladder</span>
        <span className="text-xs text-textFaint [text-shadow:0_1px_3px_rgba(0,0,0,.8)]">Local preview</span>
      </div>
      <div className="overflow-hidden rounded-2xl border border-stroke/70 bg-surface/35 backdrop-blur-md">
        {top.map((row, i) => (
          <RankRowItem key={`${row.name}-${i}`} row={row} rank={i + 1} index={i} topBorder={i > 0} />
        ))}
        {!playerInTop && playerRank >= 0 && (
          <>
            <div className="border-t border-stroke/60 bg-bgAlt/30 py-1 text-center text-xs tracking-widest text-textFaint">···</div>
            <RankRowItem row={rows[playerRank]!} rank={playerRank + 1} index={10} topBorder={false} />
          </>
        )}
      </div>
    </div>
  );
}

'use client';

import { motion } from 'framer-motion';
import type { Profile, Wallet } from '@/lib/types';
import { tierProgress } from '@/lib/economy';
import { buildLocalLeaderboard } from '@/lib/leaderboard';
import { RankTable } from './RankTable';
import { TrophyIcon } from './TrophyIcon';

interface Props {
  profile: Profile;
  wallet: Wallet;
}

/** Dedicated ladder screen — split out of the lobby so trophies/rank have
 * their own focused page instead of competing for space with match setup. */
export function RankView({ profile, wallet }: Props) {
  const { tier, next, pct } = tierProgress(wallet.trophies);
  const leaderboard = buildLocalLeaderboard(profile.id, profile.name, wallet.trophies);

  return (
    <div className="mx-auto min-h-dvh max-w-2xl px-5 py-8 pb-32">
      <h1 className="font-display flex items-center gap-2 text-2xl font-black">
        <TrophyIcon size={26} /> Rank
      </h1>
      <p className="mt-1 text-sm text-textDim">Climb the ladder and chase the next tier.</p>

      <div className="mt-6 rounded-2xl border border-teal/40 bg-gradient-to-br from-teal/15 via-surface/50 to-bgAlt/50 p-5 backdrop-blur-md">
        <div className="flex items-center justify-between">
          <span className="text-xs font-bold uppercase tracking-wider text-textDim">Current tier</span>
          <span className="font-display text-lg font-black text-teal">{tier}</span>
        </div>
        <div className="mt-3 h-2.5 w-full overflow-hidden rounded-full border border-stroke/70 bg-surface shadow-inner">
          <motion.div
            className="h-full rounded-full bg-gradient-to-r from-teal to-gold"
            initial={{ width: 0 }}
            animate={{ width: `${Math.max(3, pct * 100)}%` }}
            transition={{ duration: 0.8, ease: 'easeOut' }}
          />
        </div>
        {next && <div className="mt-1 text-right text-xs text-textFaint">Next: {next}</div>}
        <div className="mt-3 flex items-center gap-1.5 font-black text-gold">
          <TrophyIcon size={16} /> {wallet.trophies}
        </div>
      </div>

      <RankTable rows={leaderboard} />
    </div>
  );
}

'use client';

import { motion } from 'framer-motion';
import type { MilestoneReward } from '@/lib/milestones';
import { CoinIcon } from './CoinIcon';

interface Props {
  title: string;
  track: MilestoneReward[];
  matchesPlayed: number;
  claimedMilestones: number[];
  onClaim: (reward: MilestoneReward) => void;
  /** Premium track is shown fully (as a preview) but can't be claimed yet —
   * there's no real payment processor wired up, so we don't fake a working
   * purchase; see ShopView for the same "coming soon" honesty policy. */
  locked?: boolean;
  accent?: string;
}

function rewardChip(m: MilestoneReward) {
  if (m.coins) return { icon: <CoinIcon size={10} />, text: `${m.coins}` };
  if (m.boost) return { icon: m.boost.kind === 'overdrive' ? '⚡' : '🛡️', text: `+${m.boost.amount}` };
  if (m.shardAmount) return { icon: '🧩', text: `+${m.shardAmount}` };
  if (m.banner) return { icon: '🎗️', text: 'Frame' };
  return { icon: '🎁', text: '' };
}

/** Frameless horizontal carousel — the more matches you play, the further
 * your marker travels, unlocking rewards at each stop. No boxed panel, just
 * floating nodes with snap-scrolling over the page background. */
export function RewardTrack({ title, track, matchesPlayed, claimedMilestones, onClaim, locked = false, accent = '#f5c343' }: Props) {
  const trackMax = track[track.length - 1]!.at;

  return (
    <div className="mt-6">
      <div className="mb-2 flex items-center justify-between">
        <span className="text-xs font-bold uppercase tracking-wider text-textDim [text-shadow:0_1px_3px_rgba(0,0,0,.8)]">
          {title}
          {locked && <span className="ml-2 rounded-full border border-stroke px-1.5 py-0.5 text-[9px] normal-case text-textFaint">🔒 Coming soon</span>}
        </span>
        <span className="text-xs text-textFaint [text-shadow:0_1px_3px_rgba(0,0,0,.8)]">{matchesPlayed} matches played</span>
      </div>

      <div className="scrollbar-hide relative snap-x snap-mandatory overflow-x-auto pb-3 pt-6" style={{ maskImage: 'linear-gradient(90deg, transparent, black 5%, black 95%, transparent)' }}>
        <div className="relative flex min-w-max items-center gap-0 px-4">
          <div className="absolute left-4 right-4 top-[32px] h-1 rounded-full bg-bgAlt/70" />
          <motion.div
            className="absolute left-4 top-[32px] h-1 rounded-full"
            style={{ background: `linear-gradient(90deg, ${accent}, #2fe0c8)`, maxWidth: 'calc(100% - 32px)' }}
            initial={{ width: 0 }}
            animate={{ width: `${Math.min(100, (matchesPlayed / trackMax) * 100)}%` }}
            transition={{ duration: 0.8, ease: 'easeOut' }}
          />
          {track.map((m) => {
            const reached = matchesPlayed >= m.at;
            const claimed = !locked && claimedMilestones.includes(m.at);
            const chip = rewardChip(m);
            const claimable = reached && !claimed && !locked;
            return (
              <div key={m.at} className="relative z-10 flex w-24 shrink-0 snap-center flex-col items-center gap-1 text-center">
                <motion.button
                  whileHover={claimable ? { scale: 1.1 } : undefined}
                  whileTap={claimable ? { scale: 0.94 } : undefined}
                  onClick={() => claimable && onClaim(m)}
                  disabled={!claimable}
                  className="grid h-11 w-11 place-items-center rounded-full border-2 text-lg backdrop-blur-md transition"
                  style={{
                    borderColor: claimed ? '#2fe0c8' : reached && !locked ? accent : '#2a3140',
                    background: claimed ? 'rgba(47,224,200,.18)' : reached && !locked ? `${accent}33` : 'rgba(17,22,31,.55)',
                    boxShadow: claimable ? `0 0 16px ${accent}80` : 'none',
                    opacity: locked ? 0.55 : reached ? 1 : 0.5,
                  }}
                >
                  {claimed ? '✓' : locked ? '🔒' : reached ? m.icon : '🔒'}
                </motion.button>
                <span className="text-[10px] font-bold uppercase text-textFaint [text-shadow:0_1px_3px_rgba(0,0,0,.8)]">{m.at} games</span>
                <span className="flex items-center gap-1 text-[10px] font-black [text-shadow:0_1px_3px_rgba(0,0,0,.8)]" style={{ color: accent }}>
                  {chip.icon} {chip.text}
                </span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

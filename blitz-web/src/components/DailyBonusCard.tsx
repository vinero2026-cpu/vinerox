'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { useMemo, useState } from 'react';
import { DAILY_REWARDS, calendarDayDiff, type DailyReward } from '@/lib/dailyBonus';
import { CoinIcon } from './CoinIcon';

interface Props {
  lastDailyClaim: number | null;
  dailyStreak: number;
  onClaim: () => DailyReward | null;
}

/** Home-page "come back tomorrow" card — a 7-day reward strip with a big
 * glowing Claim button when a new calendar day has started. */
export function DailyBonusCard({ lastDailyClaim, dailyStreak, onClaim }: Props) {
  const [justClaimed, setJustClaimed] = useState<DailyReward | null>(null);
  const claimedToday = lastDailyClaim != null && calendarDayDiff(lastDailyClaim, Date.now()) === 0;
  const upcomingDay = useMemo(() => {
    if (claimedToday) return dailyStreak;
    const consecutive = lastDailyClaim != null && calendarDayDiff(lastDailyClaim, Date.now()) === 1;
    return consecutive ? (dailyStreak % DAILY_REWARDS.length) + 1 : 1;
  }, [claimedToday, dailyStreak, lastDailyClaim]);

  const handleClaim = () => {
    const reward = onClaim();
    if (reward) setJustClaimed(reward);
    setTimeout(() => setJustClaimed(null), 2200);
  };

  return (
    <div className="mt-6 rounded-2xl border border-gold/40 bg-gradient-to-br from-gold/15 via-surface/50 to-bgAlt/50 p-4 backdrop-blur-md">
      <div className="flex items-center justify-between">
        <div className="text-xs font-bold uppercase tracking-wider text-textDim">Daily bonus</div>
        <div className="text-xs font-bold text-gold">Day {upcomingDay} / {DAILY_REWARDS.length}</div>
      </div>

      <div className="mt-3 flex items-center gap-1.5">
        {DAILY_REWARDS.map((r) => {
          const done = claimedToday ? r.day <= dailyStreak : r.day < upcomingDay;
          const isNext = r.day === upcomingDay;
          return (
            <div
              key={r.day}
              className="grid flex-1 place-items-center gap-1 rounded-xl border py-2 text-center transition"
              style={{
                borderColor: isNext ? '#f5c343' : done ? '#f5c34366' : '#232b3a',
                background: isNext ? 'rgba(245,195,67,.18)' : done ? 'rgba(245,195,67,.06)' : 'transparent',
                boxShadow: isNext ? '0 0 16px rgba(245,195,67,.35)' : 'none',
              }}
            >
              <span className="text-base">{done && !isNext ? '✅' : r.icon}</span>
              <span className="text-[10px] font-bold text-textFaint">+{r.coins}</span>
            </div>
          );
        })}
      </div>

      <button
        onClick={handleClaim}
        disabled={claimedToday}
        className="mt-3 w-full rounded-xl bg-gradient-to-r from-gold to-goldDeep py-2.5 text-sm font-black uppercase tracking-wide text-black transition disabled:opacity-40"
      >
        {claimedToday ? 'Come back tomorrow' : `Claim Day ${upcomingDay} bonus`}
      </button>

      <AnimatePresence>
        {justClaimed && (
          <motion.div
            initial={{ opacity: 0, y: 8, scale: 0.9 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -8 }}
            className="mt-2 flex items-center justify-center gap-1.5 text-sm font-black text-gold"
          >
            <CoinIcon size={16} /> +{justClaimed.coins} Vinerox! {justClaimed.boost && `+${justClaimed.boost.amount} ${justClaimed.boost.kind}`}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

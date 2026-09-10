'use client';

import { motion } from 'framer-motion';
import { AnimatedNumber } from './AnimatedNumber';
import { TrophyIcon } from './TrophyIcon';

interface Props {
  stake: number;
  onConfirm: () => void;
  onBack: () => void;
}

/** Dedicated screen that dramatizes the wager before queueing — the "what's
 * on the line" moment, separate from the loadout and queue steps. */
export function PrizePotView({ stake, onConfirm, onBack }: Props) {
  const pot = stake * 2;

  return (
    <div className="relative flex min-h-dvh flex-col items-center justify-center overflow-hidden px-6">
      <div
        className="pointer-events-none absolute inset-0"
        style={{ background: 'radial-gradient(circle at 50% 32%, rgba(245,195,67,.28), transparent 60%)' }}
      />
      <button onClick={onBack} className="absolute left-5 top-6 text-sm text-textDim transition hover:text-text">
        ← Back
      </button>

      <motion.div animate={{ y: [0, -10, 0] }} transition={{ duration: 2.4, repeat: Infinity }} className="drop-shadow-[0_0_30px_rgba(245,195,67,.5)]">
        <TrophyIcon size={72} />
      </motion.div>

      <div className="mt-4 text-xs font-black uppercase tracking-[0.35em] text-gold">Winner takes all</div>
      <motion.div
        animate={{ textShadow: ['0 0 20px rgba(245,195,67,.4)', '0 0 44px rgba(245,195,67,.75)', '0 0 20px rgba(245,195,67,.4)'] }}
        transition={{ duration: 1.8, repeat: Infinity }}
        className="font-display mt-2 text-6xl font-black text-gold"
      >
        <AnimatedNumber value={pot} /> V
      </motion.div>

      <div className="mt-8 flex items-center gap-4 text-center">
        <div className="rounded-2xl border border-stroke bg-surface/50 px-5 py-3 backdrop-blur-md">
          <div className="text-[10px] uppercase text-textFaint">Your stake</div>
          <div className="font-display text-xl font-black text-text">{stake} V</div>
        </div>
        <div className="text-lg font-black text-textFaint">+</div>
        <div className="rounded-2xl border border-stroke bg-surface/50 px-5 py-3 backdrop-blur-md">
          <div className="text-[10px] uppercase text-textFaint">Rival stake</div>
          <div className="font-display text-xl font-black text-text">{stake} V</div>
        </div>
      </div>

      <motion.button
        whileHover={{ scale: 1.03 }}
        whileTap={{ scale: 0.97 }}
        onClick={onConfirm}
        className="mt-10 w-full max-w-xs rounded-2xl bg-gradient-to-r from-gold to-goldDeep py-4 text-lg font-black uppercase text-black shadow-[0_0_36px_rgba(245,195,67,.5)]"
      >
        Confirm wager
      </motion.button>
      <p className="mt-3 max-w-xs text-center text-[11px] text-textFaint">Losing forfeits your stake. Winning claims the full pot.</p>
    </div>
  );
}

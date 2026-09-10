'use client';

import { motion } from 'framer-motion';
import type { MatchOutcome } from '@/lib/types';

interface Props {
  outcome: MatchOutcome;
  coinDelta: number;
  trophyDelta: number;
  gotChest: boolean;
  onContinue: () => void;
}

export function ResultOverlay({ outcome, coinDelta, trophyDelta, gotChest, onContinue }: Props) {
  const title = outcome === 'win' ? 'VICTORY' : outcome === 'loss' ? 'ROUND LOST' : 'DRAW';
  const color = outcome === 'win' ? '#28e07f' : outcome === 'loss' ? '#ff4d5e' : '#9aa5b8';

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/70 px-6">
      <motion.div
        initial={{ opacity: 0, scale: 0.85 }}
        animate={{ opacity: 1, scale: 1 }}
        className="w-full max-w-sm rounded-3xl border p-6 text-center"
        style={{ borderColor: `${color}88`, backgroundColor: '#11161f' }}
      >
        <div className="font-display text-3xl font-black" style={{ color }}>
          {title}
        </div>
        <div className="mt-4 flex justify-center gap-6 text-sm">
          <div>
            <div className="font-display text-2xl font-black text-gold">
              {coinDelta >= 0 ? '+' : ''}
              {coinDelta}
            </div>
            <div className="text-textFaint">Vinerox</div>
          </div>
          <div>
            <div className="font-display text-2xl font-black text-teal">
              {trophyDelta >= 0 ? '+' : ''}
              {trophyDelta}
            </div>
            <div className="text-textFaint">Trophies</div>
          </div>
        </div>
        {gotChest && <div className="mt-4 text-sm font-bold text-gold">📦 A new reward chest is waiting in your lobby!</div>}
        <button
          onClick={onContinue}
          className="mt-6 w-full rounded-xl bg-gradient-to-r from-gold to-goldDeep py-3 font-black uppercase text-black"
        >
          Back to lobby
        </button>
      </motion.div>
    </div>
  );
}

'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { characterFor, RARITY_COLOR } from '@/lib/characters';
import type { LayerId } from '@/lib/types';

interface Props {
  cast: { id: LayerId; key: number } | null;
}

/** The signature "cast" moment for a character ability: the avatar rockets
 * to center and throws a shockwave ring at the chart. No name/caption text —
 * the dock button already shows which ability is active, so a redundant
 * banner would just cover the chart. */
export function AbilityCastOverlay({ cast }: Props) {
  const char = cast ? characterFor(cast.id) : null;
  const color = char ? RARITY_COLOR[char.rarity] : '#f5c343';

  return (
    <AnimatePresence>
      {char && (
        <motion.div key={cast!.key} className="pointer-events-none absolute inset-0 z-20 grid place-items-center overflow-hidden">
          <motion.div
            initial={{ scale: 0, opacity: 0.9 }}
            animate={{ scale: 7, opacity: 0 }}
            transition={{ duration: 0.85, ease: 'easeOut' }}
            className="absolute h-20 w-20 rounded-full"
            style={{ border: `3px solid ${color}` }}
          />
          <motion.div
            initial={{ scale: 0, opacity: 0.7 }}
            animate={{ scale: 4.5, opacity: 0 }}
            transition={{ duration: 0.85, ease: 'easeOut', delay: 0.08 }}
            className="absolute h-20 w-20 rounded-full"
            style={{ border: `2px solid ${color}` }}
          />
          <motion.div
            initial={{ scale: 0.2, opacity: 0, y: 40, rotate: -25 }}
            animate={{ scale: [0.2, 1.3, 0.5], opacity: [0, 1, 0], y: [40, 0, -30], rotate: [-25, 0, 10] }}
            transition={{ duration: 0.7, times: [0, 0.45, 1], ease: 'easeOut' }}
            className="text-5xl"
            style={{ filter: `drop-shadow(0 0 22px ${color})` }}
          >
            {char.avatar}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { characterFor, RARITY_COLOR } from '@/lib/characters';
import type { LayerId } from '@/lib/types';

interface Props {
  cast: { id: LayerId; key: number } | null;
}

/** The signature "cast" moment for a character ability: the avatar rockets
 * to center, throws a shockwave ring at the chart, and a banner names the
 * indicator it just conjured — e.g. "The Oracle casts RSI". */
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
            initial={{ scale: 0.2, opacity: 0, y: 60, rotate: -25 }}
            animate={{ scale: [0.2, 1.8, 0.5], opacity: [0, 1, 0], y: [60, 0, -40], rotate: [-25, 0, 10] }}
            transition={{ duration: 0.9, times: [0, 0.45, 1], ease: 'easeOut' }}
            className="text-7xl"
            style={{ filter: `drop-shadow(0 0 26px ${color})` }}
          >
            {char.avatar}
          </motion.div>
          <motion.div
            initial={{ opacity: 0, y: 10, scale: 0.9 }}
            animate={{ opacity: [0, 1, 1, 0], y: 0, scale: 1 }}
            transition={{ duration: 1.1, times: [0, 0.2, 0.75, 1] }}
            className="absolute bottom-8 rounded-full border px-4 py-1.5 text-xs font-black uppercase tracking-wide backdrop-blur-sm"
            style={{ borderColor: color, color, backgroundColor: '#05070ce6' }}
          >
            {char.name} casts {char.shortName}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { characterFor, RARITY_COLOR, statsForLevel } from '@/lib/characters';
import type { LayerId } from '@/lib/types';

interface Props {
  activeLayers: LayerId[];
  characterLevels: Partial<Record<LayerId, number>>;
}

/** Persistent (not a one-off flash) feedback for every currently-active
 * ability: a soft pulsing border tinted to the character's rarity color for
 * the whole time it's active, plus a stacked chip that spells out exactly
 * what it's contributing (icon + name + "+N%"). Both disappear the instant
 * the ability expires, via AnimatePresence keyed on activeLayers. */
export function ActiveAbilityAura({ activeLayers, characterLevels }: Props) {
  return (
    <>
      <AnimatePresence>
        {activeLayers.map((id) => {
          const color = RARITY_COLOR[characterFor(id).rarity];
          return (
            <motion.div
              key={id}
              initial={{ opacity: 0 }}
              animate={{ opacity: [0.3, 0.65, 0.3] }}
              exit={{ opacity: 0 }}
              transition={{ duration: 1.8, repeat: Infinity, ease: 'easeInOut' }}
              className="pointer-events-none absolute inset-0 rounded-2xl"
              style={{ boxShadow: `inset 0 0 44px ${color}55, inset 0 0 6px ${color}` }}
            />
          );
        })}
      </AnimatePresence>
      {/* Left side, so it never collides with the right-side indicator cast dock. */}
      <div className="pointer-events-none absolute left-3 top-1/2 z-10 flex -translate-y-1/2 flex-col items-start gap-1.5">
        <AnimatePresence>
          {activeLayers.map((id) => {
            const char = characterFor(id);
            const color = RARITY_COLOR[char.rarity];
            const bonus = statsForLevel(id, characterLevels[id] ?? 1).bonus;
            return (
              <motion.div
                key={id}
                initial={{ opacity: 0, x: -24, scale: 0.8 }}
                animate={{ opacity: 1, x: 0, scale: 1 }}
                exit={{ opacity: 0, x: -24, scale: 0.8 }}
                className="flex items-center gap-1 rounded-full border px-2 py-0.5 font-display text-[11px] font-black backdrop-blur-sm"
                style={{ borderColor: color, color, backgroundColor: '#05070ce6', boxShadow: `0 0 12px ${color}66` }}
              >
                <span>{char.avatar}</span>
                <span>{char.shortName}</span>
                <span>+{Math.round(bonus * 100)}%</span>
              </motion.div>
            );
          })}
        </AnimatePresence>
      </div>
    </>
  );
}

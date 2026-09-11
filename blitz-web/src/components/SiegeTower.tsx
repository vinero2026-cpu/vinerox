'use client';

import { motion, AnimatePresence } from 'framer-motion';

interface Props {
  /** 0..1 — structural integrity remaining. Drives both height and crack overlay. */
  hpFraction: number;
  accent: string;
  align: 'left' | 'right';
  /** Bumped to a new number on every hit — replays the white flash + debris puff. */
  hitKey: number | null;
  label: string;
}

const MAX_HEIGHT = 168;
const MIN_HEIGHT = 30;

/** A player's corporate tower in the "Tower Siege" battle visualization —
 * shrinks toward rubble as its owner takes damage, cracks appear as HP
 * drops, and a white flash + debris puff plays on every hit. Pure CSS/SVG,
 * no real building/logo likeness. */
export function SiegeTower({ hpFraction, accent, align, hitKey, label }: Props) {
  const clamped = Math.max(0, Math.min(1, hpFraction));
  const height = MIN_HEIGHT + (MAX_HEIGHT - MIN_HEIGHT) * clamped;
  const floors = Math.max(2, Math.round((height / MAX_HEIGHT) * 9));
  const crackOpacity = (1 - clamped) * 0.85;

  return (
    <div className={`pointer-events-none absolute bottom-0 z-10 flex flex-col items-center ${align === 'left' ? 'left-1' : 'right-1'}`}>
      <motion.div
        animate={{ height }}
        transition={{ type: 'spring', stiffness: 110, damping: 16 }}
        className="relative w-8 overflow-hidden rounded-t-md border-x border-t"
        style={{
          borderColor: `${accent}99`,
          background: `linear-gradient(180deg, ${accent}30, #05070cf0)`,
          boxShadow: `0 0 14px ${accent}44`,
        }}
      >
        <div className="absolute inset-0 grid grid-cols-2 content-start gap-[3px] p-1">
          {Array.from({ length: floors * 2 }).map((_, i) => (
            <div key={i} className="h-1.5 rounded-[1px]" style={{ background: `${accent}55` }} />
          ))}
        </div>
        {/* crack lines — more visible the lower the HP */}
        <svg className="absolute inset-0 h-full w-full" viewBox="0 0 32 100" preserveAspectRatio="none" style={{ opacity: crackOpacity }}>
          <path d="M4 0 L14 38 L6 55 L18 100" stroke="#ff4d5e" strokeWidth={1.4} fill="none" />
          <path d="M28 10 L20 40 L27 70" stroke="#ff4d5e" strokeWidth={1.1} fill="none" />
        </svg>
        <AnimatePresence>
          {hitKey != null && (
            <motion.div
              key={hitKey}
              initial={{ opacity: 0.95 }}
              animate={{ opacity: 0 }}
              transition={{ duration: 0.45 }}
              className="absolute inset-0 bg-white"
            />
          )}
        </AnimatePresence>
      </motion.div>
      <AnimatePresence>
        {hitKey != null && (
          <motion.div
            key={`debris-${hitKey}`}
            initial={{ opacity: 1, y: 0 }}
            animate={{ opacity: 0, y: 14 }}
            transition={{ duration: 0.55 }}
            className="absolute -top-1 flex gap-0.5"
          >
            {[0, 1, 2].map((i) => (
              <span key={i} className="h-1 w-1 rounded-[1px]" style={{ background: accent }} />
            ))}
          </motion.div>
        )}
      </AnimatePresence>
      <div className="mt-1 h-1 w-8 rounded-full" style={{ background: `${accent}30` }} />
      <span className="mt-0.5 text-[7px] font-black uppercase tracking-wide" style={{ color: accent }}>
        {label}
      </span>
    </div>
  );
}

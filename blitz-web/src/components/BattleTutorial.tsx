'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { useState } from 'react';

interface Props {
  onDone: () => void;
}

const STEPS = [
  {
    title: 'The objective',
    body: 'Attack by making successful trades to destroy their tower before time runs out.',
    anchor: 'top-[40%]',
  },
  {
    title: 'The actions',
    body: 'Tap UP or DOWN the instant you read the chart — a correct call fires straight at their tower.',
    anchor: 'bottom-24',
  },
  {
    title: 'The visual translation',
    body: 'That green/red bar under your name is your PnL — watch it grow to see yourself winning ground in real time.',
    anchor: 'top-24',
  },
];

/** Mandatory-but-skippable 3-step first-time tutorial for the Blitz battle
 * screen — a dimmed backdrop with a floating tooltip card pointing at the
 * relevant screen region for each step (real spotlight cutouts would need
 * per-step exact element coordinates; this keeps the same intuitive effect
 * with a much simpler/robust implementation). */
export function BattleTutorial({ onDone }: Props) {
  const [step, setStep] = useState(0);
  const s = STEPS[step]!;
  const isLast = step === STEPS.length - 1;

  return (
    <div className="absolute inset-0 z-50 bg-black/55 backdrop-blur-[2px]">
      {/* Centering lives on this static wrapper — framer-motion writes its own
          `transform` on the animated child below, which would otherwise clobber
          a Tailwind translate-x utility placed on the very same element. */}
      <div className={`absolute left-1/2 w-[86%] max-w-sm -translate-x-1/2 ${s.anchor}`}>
        <AnimatePresence mode="wait">
          <motion.div
            key={step}
            initial={{ opacity: 0, y: 12, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -12, scale: 0.96 }}
            transition={{ duration: 0.22 }}
            className="rounded-2xl border border-gold/50 bg-[#0b0f18f2] p-4 shadow-[0_20px_50px_-16px_rgba(0,0,0,.8)]"
          >
            <div className="mb-2 flex items-center gap-1.5">
              {STEPS.map((_, i) => (
                <span key={i} className="h-1.5 flex-1 rounded-full" style={{ background: i <= step ? '#f5c343' : 'rgba(255,255,255,.15)' }} />
              ))}
            </div>
            <div className="font-display text-sm font-black uppercase tracking-wide text-gold">
              {step + 1}. {s.title}
            </div>
            <p className="mt-1.5 text-sm leading-snug text-text">{s.body}</p>
            <div className="mt-3 flex items-center justify-between">
              <button onClick={onDone} className="text-xs font-bold uppercase tracking-wide text-textFaint">
                Skip
              </button>
              <button
                onClick={() => (isLast ? onDone() : setStep((v) => v + 1))}
                className="rounded-full bg-gradient-to-b from-gold to-goldDeep px-4 py-1.5 font-display text-xs font-black uppercase text-black"
              >
                {isLast ? "Let's go" : 'Next'}
              </button>
            </div>
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
}

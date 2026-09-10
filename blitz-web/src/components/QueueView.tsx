'use client';

import { motion } from 'framer-motion';

export function QueueView({ secondsLeft, onCancel }: { secondsLeft: number; onCancel: () => void }) {
  return (
    <div className="grid min-h-dvh place-items-center px-6">
      <div className="text-center">
        <motion.div
          animate={{ rotate: 360 }}
          transition={{ repeat: Infinity, duration: 2.2, ease: 'linear' }}
          className="mx-auto grid h-24 w-24 place-items-center rounded-full border-4 border-teal/30 border-t-teal"
        >
          <span className="text-3xl">📡</span>
        </motion.div>
        <h1 className="font-display mt-6 text-2xl font-black uppercase tracking-wide">Searching the arena</h1>
        <p className="mt-2 text-sm text-textDim">Human rival or CPU fallback in {secondsLeft}s</p>
        <button onClick={onCancel} className="mt-8 rounded-xl border border-stroke px-6 py-2 text-sm font-bold text-textDim">
          Cancel
        </button>
      </div>
    </div>
  );
}

'use client';

import { motion } from 'framer-motion';
import { ASSETS } from '@/lib/types';
import { colorForTicker } from '@/lib/tickerColors';
import { MasterIcon } from './NavIcons';

/** Placeholder hub for a future live feed from the real VINEROX MASTER stock
 * scanner (vinero.app/stocks) — shows the same tickers Blitz already uses as
 * a preview strip until that integration is wired up. */
export function MasterView() {
  return (
    <div className="mx-auto flex min-h-dvh max-w-lg flex-col items-center justify-center px-6 py-10 pb-32 text-center">
      <motion.div
        animate={{ boxShadow: ['0 0 0px rgba(47,224,200,.3)', '0 0 30px rgba(47,224,200,.5)', '0 0 0px rgba(47,224,200,.3)'] }}
        transition={{ duration: 2.4, repeat: Infinity }}
        className="grid h-24 w-24 place-items-center rounded-3xl border border-teal/60 bg-gradient-to-br from-teal/20 to-bgAlt text-teal"
      >
        <MasterIcon size={44} />
      </motion.div>
      <h1 className="font-display mt-6 text-2xl font-black">Master</h1>
      <p className="mt-2 text-sm text-textDim">
        Live prices and scores from the VINEROX MASTER scanner will surface here — the same feed that powers vinero.app/stocks.
      </p>

      <div className="mt-6 flex flex-wrap justify-center gap-2">
        {ASSETS.map((t) => (
          <span
            key={t}
            className="rounded-full border px-3 py-1 text-xs font-black"
            style={{ borderColor: `${colorForTicker(t)}66`, color: colorForTicker(t) }}
          >
            {t}
          </span>
        ))}
      </div>

      <span className="mt-6 rounded-full border border-stroke px-3 py-1 text-xs font-bold uppercase tracking-wide text-textFaint">
        Coming soon
      </span>
    </div>
  );
}

'use client';

import { motion } from 'framer-motion';
import { LeagueIcon } from './NavIcons';

/** Placeholder hub for seasonal leagues/clans — wired into the bottom nav now
 * so the tab exists, with league content to follow in a later pass. */
export function LeagueView() {
  return (
    <div className="mx-auto flex min-h-dvh max-w-lg flex-col items-center justify-center px-6 py-10 pb-32 text-center">
      <motion.div
        animate={{ boxShadow: ['0 0 0px rgba(192,132,252,.3)', '0 0 30px rgba(192,132,252,.5)', '0 0 0px rgba(192,132,252,.3)'] }}
        transition={{ duration: 2.4, repeat: Infinity }}
        className="grid h-24 w-24 place-items-center rounded-3xl border border-[#c084fc]/60 bg-gradient-to-br from-[#c084fc]/20 to-bgAlt text-[#c084fc]"
      >
        <LeagueIcon size={44} />
      </motion.div>
      <h1 className="font-display mt-6 text-2xl font-black">League</h1>
      <p className="mt-2 text-sm text-textDim">
        Seasonal clans, group standings, and league-exclusive rewards are on the way. Keep climbing the Rank ladder in the
        meantime — your trophy tier will carry over.
      </p>
      <span className="mt-4 rounded-full border border-stroke px-3 py-1 text-xs font-bold uppercase tracking-wide text-textFaint">
        Coming soon
      </span>
    </div>
  );
}

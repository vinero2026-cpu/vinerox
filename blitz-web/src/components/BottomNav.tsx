'use client';

import { motion } from 'framer-motion';
import { CompeteIcon, HomeIcon, LeagueIcon, RankIcon, ShopIcon } from './NavIcons';

export type NavStage = 'lobby' | 'shop' | 'rank' | 'league' | 'master';

interface Props {
  active: NavStage;
  onNavigate: (stage: NavStage) => void;
  onCompete: () => void;
}

const SIDE_ITEMS: { id: NavStage; label: string; Icon: typeof HomeIcon }[] = [
  { id: 'lobby', label: 'Home', Icon: HomeIcon },
  { id: 'shop', label: 'Shop', Icon: ShopIcon },
];

const RIGHT_ITEMS: { id: NavStage; label: string; Icon: typeof HomeIcon }[] = [
  { id: 'rank', label: 'Rank', Icon: RankIcon },
  { id: 'league', label: 'League', Icon: LeagueIcon },
];

/** Fixed bottom navigation bar shown across every hub screen (home/shop/rank/
 * league/master) — Clash-style with an elevated round COMPETE button dead
 * center that kicks off the loadout → pot → queue → match flow. */
export function BottomNav({ active, onNavigate, onCompete }: Props) {
  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 flex justify-center pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-2">
      <div className="flex items-end gap-1 rounded-3xl border border-stroke bg-surface/70 px-2 pb-2 pt-2 shadow-[0_14px_40px_-12px_rgba(0,0,0,.7)] backdrop-blur-md">
        {SIDE_ITEMS.map(({ id, label, Icon }) => (
          <NavButton key={id} label={label} active={active === id} onClick={() => onNavigate(id)}>
            <Icon size={21} />
          </NavButton>
        ))}

        <motion.button
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.93 }}
          onClick={onCompete}
          className="relative -mt-7 grid h-16 w-16 shrink-0 place-items-center rounded-full bg-gradient-to-b from-gold to-goldDeep text-black shadow-[0_10px_28px_-6px_rgba(245,195,67,.7)]"
        >
          <span className="absolute inset-0 animate-pulseGlow rounded-full" style={{ boxShadow: '0 0 0 3px rgba(245,195,67,.35)' }} />
          <CompeteIcon size={26} />
          <span className="absolute -bottom-4 text-[9px] font-black uppercase tracking-wide text-gold">Compete</span>
        </motion.button>

        {RIGHT_ITEMS.map(({ id, label, Icon }) => (
          <NavButton key={id} label={label} active={active === id} onClick={() => onNavigate(id)}>
            <Icon size={21} />
          </NavButton>
        ))}
      </div>
    </nav>
  );
}

function NavButton({ label, active, onClick, children }: { label: string; active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <motion.button
      onClick={onClick}
      whileTap={{ scale: 0.9 }}
      className="relative grid w-14 place-items-center gap-0.5 rounded-2xl px-1 py-1.5 transition"
      style={{ color: active ? '#2fe0c8' : '#7c879c' }}
    >
      {active && (
        <motion.div
          layoutId="navActivePill"
          transition={{ type: 'spring', stiffness: 420, damping: 34 }}
          className="absolute inset-0 rounded-2xl"
          style={{ background: 'rgba(47,224,200,.12)' }}
        />
      )}
      <span className="relative">{children}</span>
      <span className="relative text-[9px] font-black uppercase tracking-wide">{label}</span>
    </motion.button>
  );
}

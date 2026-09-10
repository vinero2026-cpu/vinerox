'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { PlayerBanner } from './PlayerBanner';
import { TrophyIcon } from './TrophyIcon';
import type { BannerId } from '@/lib/types';

interface Side {
  name: string;
  avatar: string;
  avatarImage?: string;
  countryCode?: string;
  trophies: number;
  banner?: BannerId;
  tag?: { label: string; color: string };
}

interface Props {
  asset: string;
  stake: number;
  me: Side;
  opponent: Side;
  onDone: () => void;
}

const INTRO_MS = 2400;

/** Pre-battle reveal — shows both banners and a big VS medal before the
 * chart appears, mirroring the "who am I facing" moment of arena games. */
export function MatchIntroView({ asset, stake, me, opponent, onDone }: Props) {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const doneTimer = setTimeout(onDone, INTRO_MS);
    const readyTimer = setTimeout(() => setReady(true), 150);
    return () => {
      clearTimeout(doneTimer);
      clearTimeout(readyTimer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="relative flex min-h-dvh flex-col items-center justify-center overflow-hidden" onClick={onDone}>
      <div
        className="absolute inset-0"
        style={{ background: 'linear-gradient(160deg, #ff4d5e2e 0%, #05070c 45%, #05070c 55%, #28e07f26 100%)' }}
      />
      <div
        className="pointer-events-none absolute inset-0 opacity-40"
        style={{ backgroundImage: 'repeating-linear-gradient(135deg, rgba(255,255,255,.03) 0px, rgba(255,255,255,.03) 2px, transparent 2px, transparent 40px)' }}
      />

      <div className="relative z-10 flex w-full max-w-md flex-col gap-10 px-6">
        <PlayerBanner
          name={opponent.name}
          avatar={opponent.avatar}
          avatarImage={opponent.avatarImage}
          countryCode={opponent.countryCode}
          trophies={opponent.trophies}
          bannerId={opponent.banner}
          tag={opponent.tag}
          mirror
          size="lg"
        />

        <motion.div
          initial={{ scale: 0.3, opacity: 0, rotate: -12 }}
          animate={ready ? { scale: 1, opacity: 1, rotate: 0 } : {}}
          transition={{ type: 'spring', stiffness: 220, damping: 14 }}
          className="relative mx-auto grid h-24 w-24 place-items-center"
          style={{
            clipPath: 'polygon(50% 0%, 95% 25%, 95% 75%, 50% 100%, 5% 75%, 5% 25%)',
            background: 'linear-gradient(160deg, #3a8bff, #0b1a33)',
            border: '3px solid #f5c343',
            boxShadow: '0 0 40px rgba(245,195,67,.6)',
          }}
        >
          <span className="font-display text-2xl font-black italic text-white">VS</span>
        </motion.div>

        <PlayerBanner name={me.name} avatar={me.avatar} avatarImage={me.avatarImage} countryCode={me.countryCode} trophies={me.trophies} bannerId={me.banner} size="lg" />
      </div>

      <div className="relative z-10 mt-8 text-center">
        <div className="flex items-center justify-center gap-1.5 text-xs font-black uppercase tracking-[0.3em] text-textDim [text-shadow:0_1px_4px_rgba(0,0,0,.9)]">
          {asset} · <TrophyIcon size={13} /> pot {stake * 2} V
        </div>
        <div className="mt-2 text-xs text-textFaint [text-shadow:0_1px_4px_rgba(0,0,0,.9)]">Tap to skip</div>
      </div>
    </div>
  );
}

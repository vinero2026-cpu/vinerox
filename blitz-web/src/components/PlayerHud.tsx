'use client';

import { motion } from 'framer-motion';
import { avatarAccent } from '@/lib/identity';
import { AnimatedNumber } from './AnimatedNumber';
import { AvatarGlyph } from './AvatarGlyph';
import { FlagIcon } from './FlagIcon';

interface Props {
  name: string;
  flag: string;
  countryCode?: string;
  avatar: string;
  pnl: number;
  leading: boolean;
  align?: 'left' | 'right';
  /** Live momentum reaction badge on the avatar corner — purely cosmetic,
   * derived from how the match is currently going for this side. */
  mood?: 'cheer' | 'panic' | 'neutral';
}

const MOOD_EMOJI: Record<'cheer' | 'panic', string> = { cheer: '🔥', panic: '😰' };

/** Minimal, symmetric player card: flag + avatar + name + live P&L% with a
 * glowing progress bar underneath showing how close that side is to the win
 * side (purely visual, derived from the same pnl value). */
export function PlayerHud({ name, flag, countryCode, avatar, pnl, leading, align = 'left', mood = 'neutral' }: Props) {
  const color = leading ? '#28e07f' : '#ff4d5e';
  const [ac1, ac2] = avatarAccent(avatar);
  // Normalizes a typical pnl swing range onto a 0-100% bar fill.
  const barPct = Math.max(4, Math.min(100, ((pnl + 2) / 4) * 100));
  return (
    <motion.div
      animate={{ boxShadow: leading ? `0 0 18px 1px ${color}55` : `0 0 8px 0px ${color}2a` }}
      className="relative flex items-center gap-1.5 overflow-hidden rounded-lg border px-2 py-1 backdrop-blur-sm"
      style={{
        borderColor: `${color}88`,
        background: `linear-gradient(135deg, ${color}1c, rgba(17,22,31,0.85))`,
        flexDirection: align === 'right' ? 'row-reverse' : 'row',
      }}
    >
      <motion.div
        animate={{ boxShadow: [`0 0 0px 0px ${color}55`, `0 0 10px 2px ${color}55`, `0 0 0px 0px ${color}55`] }}
        transition={{ repeat: Infinity, duration: 2.2 }}
        className="relative grid h-7 w-7 shrink-0 place-items-center overflow-visible rounded-full text-sm"
        style={{ border: `1.5px solid ${color}aa`, background: `radial-gradient(circle at 35% 30%, ${ac1}55, ${ac2})` }}
      >
        <div className="h-full w-full overflow-hidden rounded-full">
          <AvatarGlyph avatar={avatar} className="h-full w-full" />
        </div>
        {mood !== 'neutral' && (
          <motion.span
            key={mood}
            initial={{ scale: 0, opacity: 0 }}
            animate={{ scale: [1, 1.25, 1], opacity: 1 }}
            transition={{ duration: 1.1, repeat: Infinity }}
            className="absolute -bottom-1 -right-1 text-[10px] leading-none"
          >
            {MOOD_EMOJI[mood]}
          </motion.span>
        )}
      </motion.div>
      <div className={align === 'right' ? 'text-right' : ''}>
        <div className="flex items-center gap-1 font-display text-[10px] font-bold">
          {align === 'right' ? (
            <>
              <span>{name}</span>
              {countryCode ? <FlagIcon code={countryCode} className="h-3.5 w-5 border border-black/30 shadow-sm" /> : flag && <span>{flag}</span>}
            </>
          ) : (
            <>
              {countryCode ? <FlagIcon code={countryCode} className="h-3.5 w-5 border border-black/30 shadow-sm" /> : flag && <span>{flag}</span>}
              <span>{name}</span>
            </>
          )}
        </div>
        <div className="font-display text-sm font-extrabold" style={{ color }}>
          <AnimatedNumber value={pnl} format={(v) => `${v >= 0 ? '+' : ''}${v.toFixed(2)}%`} />
        </div>
        <div className="mt-0.5 h-1 w-14 overflow-hidden rounded-full bg-bgAlt/70">
          <motion.div
            className="h-full rounded-full"
            animate={{ width: `${barPct}%`, boxShadow: `0 0 6px ${color}` }}
            transition={{ duration: 0.4 }}
            style={{ background: color, marginInlineStart: align === 'right' ? 'auto' : 0 }}
          />
        </div>
      </div>
    </motion.div>
  );
}


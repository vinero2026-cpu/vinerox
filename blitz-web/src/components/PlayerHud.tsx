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
}

/** Minimal, symmetric player card: flag + avatar + name + live P&L% — no
 * extra captions/progress bars, so both sides read as identical windows. */
export function PlayerHud({ name, flag, countryCode, avatar, pnl, leading, align = 'left' }: Props) {
  const color = leading ? '#28e07f' : '#ff4d5e';
  const [ac1, ac2] = avatarAccent(avatar);
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
        className="grid h-7 w-7 shrink-0 place-items-center overflow-hidden rounded-full text-sm"
        style={{ border: `1.5px solid ${color}aa`, background: `radial-gradient(circle at 35% 30%, ${ac1}55, ${ac2})` }}
      >
        <AvatarGlyph avatar={avatar} className="h-full w-full" />
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
      </div>
    </motion.div>
  );
}


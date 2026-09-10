'use client';

import { motion } from 'framer-motion';
import { avatarAccent } from '@/lib/identity';
import { AnimatedNumber } from './AnimatedNumber';
import { FlagIcon } from './FlagIcon';

interface Props {
  name: string;
  flag: string;
  countryCode?: string;
  avatar: string;
  pnl: number;
  leading: boolean;
  align?: 'left' | 'right';
  tag?: { label: string; color: string };
}

export function PlayerHud({ name, flag, countryCode, avatar, pnl, leading, align = 'left', tag }: Props) {
  const color = leading ? '#28e07f' : '#ff4d5e';
  const [ac1, ac2] = avatarAccent(avatar);
  return (
    <motion.div
      animate={{ boxShadow: leading ? `0 0 24px 2px ${color}66` : `0 0 12px 0px ${color}33` }}
      className="relative flex items-center gap-3 overflow-hidden rounded-2xl border px-3 py-2 backdrop-blur-sm"
      style={{
        borderColor: `${color}88`,
        background: `linear-gradient(135deg, ${color}1c, rgba(17,22,31,0.85))`,
        flexDirection: align === 'right' ? 'row-reverse' : 'row',
      }}
    >
      <motion.div
        animate={{ boxShadow: [`0 0 0px 0px ${color}55`, `0 0 14px 3px ${color}55`, `0 0 0px 0px ${color}55`] }}
        transition={{ repeat: Infinity, duration: 2.2 }}
        className="grid h-10 w-10 place-items-center rounded-full text-xl"
        style={{ border: `1.5px solid ${color}aa`, background: `radial-gradient(circle at 35% 30%, ${ac1}55, ${ac2})` }}
      >
        {avatar}
      </motion.div>
      <div className={align === 'right' ? 'text-right' : ''}>
        <div className="flex items-center gap-1.5 text-xs font-bold">
          {align === 'right' ? (
            <>
              <span>{name}</span>
              {countryCode ? <FlagIcon code={countryCode} className="h-4 w-6 border border-black/30 shadow-sm" /> : flag && <span>{flag}</span>}
            </>
          ) : (
            <>
              {countryCode ? <FlagIcon code={countryCode} className="h-4 w-6 border border-black/30 shadow-sm" /> : flag && <span>{flag}</span>}
              <span>{name}</span>
            </>
          )}
        </div>
        {tag && (
          <div
            className="mt-0.5 inline-block rounded-full px-1.5 py-0.5 text-[9px] font-black uppercase tracking-wide"
            style={{ color: tag.color, backgroundColor: `${tag.color}22`, border: `1px solid ${tag.color}55` }}
          >
            {tag.label}
          </div>
        )}
        <div className="font-display text-lg font-extrabold" style={{ color }}>
          <AnimatedNumber value={pnl} format={(v) => `${v >= 0 ? '+' : ''}${v.toFixed(2)}%`} />
        </div>
        <div className="mt-1 h-1.5 w-24 overflow-hidden rounded-full bg-bgAlt">
          <motion.div
            className="h-full rounded-full"
            style={{ backgroundColor: color }}
            animate={{ width: `${Math.min(100, Math.max(4, (Math.abs(pnl) / 5) * 100))}%` }}
            transition={{ duration: 0.5, ease: 'easeOut' }}
          />
        </div>
      </div>
    </motion.div>
  );
}


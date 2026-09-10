'use client';

import { motion } from 'framer-motion';
import { BANNER_CATALOG, type BannerId } from '@/lib/types';
import { avatarAccent } from '@/lib/identity';
import { bannerPatternCss, bannerPatternSize } from '@/lib/bannerPatterns';
import { AnimatedNumber } from './AnimatedNumber';
import { FlagIcon } from './FlagIcon';
import { TrophyIcon } from './TrophyIcon';

interface Props {
  name: string;
  avatar: string;
  avatarImage?: string;
  countryCode?: string;
  trophies: number;
  bannerId?: BannerId;
  mirror?: boolean;
  size?: 'sm' | 'lg';
  tag?: { label: string; color: string };
}

/** Clash-style angled ribbon card with a medallion avatar — the shared
 * "player identity" component used in the lobby, match intro, and results. */
export function PlayerBanner({ name, avatar, avatarImage, countryCode, trophies, bannerId = 'default', mirror = false, size = 'lg', tag }: Props) {
  const banner = BANNER_CATALOG.find((b) => b.id === bannerId) ?? BANNER_CATALOG[0]!;
  const big = size === 'lg';
  const [ac1, ac2] = avatarAccent(avatar);

  return (
    <div className={`relative flex items-center ${mirror ? 'flex-row-reverse' : ''} ${big ? 'gap-4' : 'gap-2'}`}>
      <motion.div
        initial={{ opacity: 0, x: mirror ? 40 : -40 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ type: 'spring', stiffness: 120, damping: 16 }}
        className={`relative flex-1 overflow-hidden ${big ? 'py-4 pl-6 pr-10' : 'py-2 pl-3 pr-5'}`}
        style={{
          clipPath: mirror ? 'polygon(10% 0, 100% 0, 100% 100%, 0% 100%)' : 'polygon(0 0, 90% 0, 100% 100%, 0% 100%)',
          background: `linear-gradient(${mirror ? '135deg' : '-135deg'}, ${banner.colors[0]}, ${banner.colors[1]})`,
          border: `2px solid ${banner.border}`,
          boxShadow: `0 10px 24px -10px ${banner.border}80`,
        }}
      >
        <div
          className="pointer-events-none absolute inset-0"
          style={{ backgroundImage: bannerPatternCss(banner.pattern, banner.border), backgroundSize: bannerPatternSize(banner.pattern) }}
        />
        <div className={mirror ? 'relative text-right' : 'relative'}>
          <div
            className={`font-display truncate font-black uppercase tracking-wide text-white ${big ? 'text-xl' : 'text-sm'}`}
            style={{ textShadow: '0 2px 4px rgba(0,0,0,.6)' }}
          >
            {name}
          </div>
          {tag && (
            <div
              className="mt-0.5 inline-block rounded-full px-1.5 py-0.5 text-[9px] font-black uppercase"
              style={{ color: tag.color, backgroundColor: `${tag.color}22`, border: `1px solid ${tag.color}66` }}
            >
              {tag.label}
            </div>
          )}
          <div className={`mt-1 flex items-center gap-1 font-black text-gold ${mirror ? 'justify-end' : ''} ${big ? 'text-lg' : 'text-xs'}`}>
            <TrophyIcon size={big ? 18 : 14} /> <AnimatedNumber value={trophies} />
          </div>
        </div>
      </motion.div>
      <div className={`relative shrink-0 ${big ? 'h-20 w-20' : 'h-10 w-10'}`}>
        <motion.div
          initial={{ scale: 0.5, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ type: 'spring', stiffness: 200, damping: 14, delay: 0.1 }}
          className={`grid h-full w-full place-items-center overflow-hidden rounded-full ${big ? 'text-4xl' : 'text-xl'}`}
          style={{
            background: avatarImage ? `radial-gradient(circle, ${banner.colors[0]}, ${banner.colors[1]})` : `radial-gradient(circle at 35% 30%, ${ac1}55, ${ac2})`,
            border: `3px solid ${banner.border}`,
            boxShadow: `0 0 24px ${banner.border}70`,
          }}
        >
          {avatarImage ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={avatarImage} alt={name} className="h-full w-full object-cover" />
          ) : (
            avatar
          )}
        </motion.div>
        {countryCode && (
          <span
            className={`absolute -bottom-1 grid place-items-center overflow-hidden rounded-md border-2 border-bgAlt shadow-[0_2px_8px_rgba(0,0,0,.6)] ${
              mirror ? '-left-1' : '-right-1'
            } ${big ? 'h-6 w-8' : 'h-4 w-5'}`}
          >
            <FlagIcon code={countryCode} className="h-full w-full" />
          </span>
        )}
      </div>
    </div>
  );
}

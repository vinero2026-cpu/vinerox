'use client';

import { AnimatePresence, motion } from 'framer-motion';

export interface CoinBurst {
  id: number;
  x: number;
  y: number;
  icon?: string;
  count?: number;
}

/** Animated particle burst anchored at a screen position — reused for coin
 * payouts and boost-activation "thrills" (overdrive/shield) via the icon prop. */
export function CoinFountain({ bursts }: { bursts: CoinBurst[] }) {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-visible">
      <AnimatePresence>
        {bursts.map((burst) => {
          const icon = burst.icon ?? '🪙';
          const count = burst.count ?? 8;
          return (
            <div key={burst.id} className="absolute" style={{ left: burst.x, top: burst.y }}>
              {Array.from({ length: count }).map((_, i) => {
                const angle = (i / count) * Math.PI * 2;
                const dx = Math.cos(angle) * (24 + Math.random() * 30);
                return (
                  <motion.span
                    key={i}
                    className="coin-particle absolute text-lg"
                    style={{ ['--dx-start' as string]: `${dx * 0.3}px`, ['--dx-end' as string]: `${dx}px` }}
                  >
                    {icon}
                  </motion.span>
                );
              })}
            </div>
          );
        })}
      </AnimatePresence>
    </div>
  );
}


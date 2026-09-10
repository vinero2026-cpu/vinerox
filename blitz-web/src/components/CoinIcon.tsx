'use client';

import { motion } from 'framer-motion';

interface Props {
  size?: number;
  className?: string;
}

/** A spinning gold coin with a "V" for Vinerox — the currency's visual mark
 * wherever the balance is shown. */
export function CoinIcon({ size = 28, className }: Props) {
  return (
    <motion.div
      className={className}
      style={{
        width: size,
        height: size,
        borderRadius: '9999px',
        background: 'radial-gradient(circle at 35% 30%, #fff7d6, #f5c343 55%, #c9902a 100%)',
        boxShadow: '0 0 10px rgba(245,195,67,.6), inset 0 0 3px rgba(0,0,0,.35)',
        display: 'grid',
        placeItems: 'center',
        border: '1.5px solid #c9902a',
      }}
      animate={{ scaleX: [1, 0.15, 1] }}
      transition={{ duration: 2.4, repeat: Infinity, ease: 'easeInOut' }}
    >
      <span className="font-display font-black text-black" style={{ fontSize: size * 0.5, lineHeight: 1 }}>
        V
      </span>
    </motion.div>
  );
}

'use client';

import { motion } from 'framer-motion';

interface Props {
  flipped: boolean;
  front: React.ReactNode;
  back: React.ReactNode;
  className?: string;
}

/** A fixed-size 3D card flip — front/back share the exact same box, so
 * revealing extra info never stretches or reflows the surrounding layout. */
export function FlipCard({ flipped, front, back, className }: Props) {
  return (
    <div className={className} style={{ perspective: 1200 }}>
      <motion.div
        animate={{ rotateY: flipped ? 180 : 0 }}
        transition={{ duration: 0.5, ease: 'easeInOut' }}
        className="relative h-full w-full"
        style={{ transformStyle: 'preserve-3d' }}
      >
        <div className="absolute inset-0" style={{ backfaceVisibility: 'hidden' }}>
          {front}
        </div>
        <div className="absolute inset-0" style={{ backfaceVisibility: 'hidden', transform: 'rotateY(180deg)' }}>
          {back}
        </div>
      </motion.div>
    </div>
  );
}

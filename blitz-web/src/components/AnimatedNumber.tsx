'use client';

import { useEffect } from 'react';
import { motion, useMotionValue, useTransform, animate } from 'framer-motion';

interface Props {
  value: number;
  format?: (v: number) => string;
  className?: string;
  duration?: number;
}

/** Smoothly tweens between values instead of snapping — used for balances,
 * trophies and live P&L so every change reads as motion, not a jump-cut. */
export function AnimatedNumber({ value, format, className, duration = 0.6 }: Props) {
  const mv = useMotionValue(value);
  const text = useTransform(mv, (v) => (format ? format(v) : Math.round(v).toString()));

  useEffect(() => {
    const controls = animate(mv, value, { duration, ease: 'easeOut' });
    return () => controls.stop();
  }, [value, mv, duration]);

  return <motion.span className={className}>{text}</motion.span>;
}

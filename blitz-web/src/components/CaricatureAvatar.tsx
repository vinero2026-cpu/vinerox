'use client';

import { useId } from 'react';
import { motion } from 'framer-motion';
import { caricatureById, type CaricatureDef, type HairStyle, type FacialHair, type Eyewear, type Headwear } from '@/lib/caricatures';
import { QUIRKS, seededFraction, type PartAnim } from '@/lib/avatarQuirks';

/** Darkens a #rrggbb hex color by `amount` (0-1) for shading/gradient stops. */
function shade(hex: string, amount: number): string {
  const n = parseInt(hex.replace('#', ''), 16);
  const r = Math.max(0, Math.min(255, ((n >> 16) & 255) * (1 - amount)));
  const g = Math.max(0, Math.min(255, ((n >> 8) & 255) * (1 - amount)));
  const b = Math.max(0, Math.min(255, (n & 255) * (1 - amount)));
  return `#${[r, g, b].map((v) => Math.round(v).toString(16).padStart(2, '0')).join('')}`;
}

function Hair({ style, color }: { style: HairStyle; color: string }) {
  switch (style) {
    case 'bald':
      return null;
    case 'slick':
      return <path d="M20 40 Q50 10 80 40 Q80 24 50 20 Q20 24 20 40 Z" fill={color} />;
    case 'afro':
      return <circle cx="50" cy="38" r="34" fill={color} />;
    case 'mohawk':
      return <path d="M44 8 Q50 4 56 8 L58 40 Q50 34 42 40 Z" fill={color} />;
    case 'curly':
      return (
        <>
          <circle cx="26" cy="30" r="9" fill={color} />
          <circle cx="40" cy="20" r="10" fill={color} />
          <circle cx="60" cy="20" r="10" fill={color} />
          <circle cx="74" cy="30" r="9" fill={color} />
        </>
      );
    case 'bun':
      return (
        <>
          <path d="M20 42 Q50 12 80 42 Q80 26 50 22 Q20 26 20 42 Z" fill={color} />
          <circle cx="50" cy="10" r="8" fill={color} />
        </>
      );
    case 'spiky':
      return (
        <path
          d="M22 38 L30 16 L38 34 L46 12 L54 34 L62 12 L70 34 L78 38 Q50 20 22 38 Z"
          fill={color}
        />
      );
    case 'bob':
      return <path d="M18 44 Q18 8 50 8 Q82 8 82 44 L82 58 Q74 40 50 40 Q26 40 18 58 Z" fill={color} />;
    default:
      return null;
  }
}

/** Adult jawline shadow — gives the round cartoon head real chin/cheek
 * definition instead of a flat baby-face, drawn under any facial hair. */
function JawShadow({ skin }: { skin: string }) {
  const dark = shade(skin, 0.22);
  return <path d="M28 62 Q50 90 72 62 Q64 78 50 80 Q36 78 28 62 Z" fill={dark} opacity={0.35} />;
}

function FacialHairPart({ type, color, patternId }: { type: FacialHair; color: string; patternId: string }) {
  switch (type) {
    case 'none':
      return null;
    case 'stubble':
      return (
        <>
          <defs>
            <pattern id={patternId} patternUnits="userSpaceOnUse" width="3.4" height="3.4">
              <circle cx="1" cy="1" r="0.55" fill={color} opacity={0.8} />
            </pattern>
          </defs>
          <path d="M26 60 Q50 88 74 60 Q66 78 50 80 Q34 78 26 60 Z" fill={`url(#${patternId})`} opacity={0.65} />
        </>
      );
    case 'mustache':
      return <path d="M38 66 Q50 74 62 66 Q56 62 50 65 Q44 62 38 66 Z" fill={color} />;
    case 'goatee':
      return (
        <>
          <path d="M38 66 Q50 72 62 66 Q56 63 50 65 Q44 63 38 66 Z" fill={color} />
          <path d="M42 72 Q50 84 58 72 Q54 76 50 76 Q46 76 42 72 Z" fill={color} />
        </>
      );
    case 'full':
      return <path d="M22 58 Q22 84 50 86 Q78 84 78 58 Q78 74 50 76 Q22 74 22 58 Z" fill={color} />;
    default:
      return null;
  }
}

function EyewearPart({ type, accent }: { type: Eyewear; accent: string }) {
  switch (type) {
    case 'none':
      return null;
    case 'round':
      return (
        <g fill="none" stroke="#161616" strokeWidth="2.5">
          <circle cx="38" cy="52" r="9" />
          <circle cx="62" cy="52" r="9" />
          <line x1="47" y1="52" x2="53" y2="52" />
        </g>
      );
    case 'aviator':
      return (
        <g>
          <path d="M28 47 h20 v11 a10 10 0 0 1 -20 0 Z" fill={`${accent}cc`} stroke="#161616" strokeWidth="2" />
          <path d="M52 47 h20 v11 a10 10 0 0 1 -20 0 Z" fill={`${accent}cc`} stroke="#161616" strokeWidth="2" />
          <line x1="48" y1="49" x2="52" y2="49" stroke="#161616" strokeWidth="2" />
        </g>
      );
    case 'monocle':
      return (
        <g fill="none" stroke="#d6b34a" strokeWidth="2.5">
          <circle cx="62" cy="52" r="9" />
          <line x1="62" y1="61" x2="60" y2="78" />
        </g>
      );
    default:
      return null;
  }
}

function HeadwearPart({ type, accent }: { type: Headwear; accent: [string, string] }) {
  switch (type) {
    case 'none':
      return null;
    case 'cap':
      return (
        <g>
          <path d="M18 34 Q50 6 82 34 L82 30 Q50 -2 18 30 Z" fill={accent[0]} />
          <path d="M78 32 Q94 32 96 40 Q84 38 76 36 Z" fill={accent[0]} />
        </g>
      );
    case 'tophat':
      return (
        <g>
          <rect x="30" y="-4" width="40" height="26" rx="3" fill={accent[1]} />
          <rect x="18" y="16" width="64" height="8" rx="3" fill={accent[1]} />
        </g>
      );
    case 'beanie':
      return <path d="M18 32 Q50 2 82 32 L82 40 Q50 30 18 40 Z" fill={accent[0]} />;
    case 'bandana':
      return (
        <g>
          <path d="M18 30 Q50 8 82 30 L82 24 Q50 4 18 24 Z" fill={accent[0]} />
          <circle cx="50" cy="17" r="3" fill={accent[1]} />
        </g>
      );
    case 'visor':
      return <path d="M20 34 Q50 26 80 34 L78 40 Q50 34 22 40 Z" fill={accent[0]} />;
    default:
      return null;
  }
}

interface Props {
  id: string;
  className?: string;
}

/** Applies a PartAnim (or nothing, for static parts) to a motion.g wrapper. */
function part(anim: PartAnim | undefined) {
  return anim ? { animate: anim.animate, transition: anim.transition } : {};
}

/** Renders one of the fully-invented CARICATURES personas as a stylized
 * big-head cartoon SVG with shaded/gradient skin and a unique looping "quirk"
 * animation per character, for a more grown-up, more alive look. Purely
 * fictional characters — no real person's likeness is depicted, by design
 * (see caricatures.ts header comment). */
export function CaricatureAvatar({ id, className }: Props) {
  const uid = useId().replace(/[:]/g, '');
  const def: CaricatureDef =
    caricatureById(id) ?? { id: 'car_rookie', name: 'Rookie', skin: '#ffdbac', hairColor: '#d6a341', hairStyle: 'curly', facialHair: 'none', eyewear: 'none', headwear: 'none', accent: ['#f5c343', '#8a5a12'] };
  const skinGradId = `skin-${uid}`;
  const stubbleId = `stubble-${uid}`;
  const skinDark = shade(def.skin, 0.18);
  const quirk = QUIRKS[def.id] ?? {};
  const seed = seededFraction(def.id);
  // fall back to a gentle idle blink whenever the character's own quirk doesn't already animate that eye
  const idleBlinkL = quirk.eyeL ?? { animate: { scaleY: [1, 1, 0.1, 1] }, transition: { duration: 3.4 + seed, repeat: Infinity, repeatDelay: 1.6 + seed * 2, ease: 'easeInOut', delay: seed * 2 } };
  const idleBlinkR = quirk.eyeR ?? idleBlinkL;

  return (
    <svg viewBox="0 0 100 100" className={className} role="img" aria-label={def.name}>
      <defs>
        <radialGradient id={skinGradId} cx="38%" cy="30%" r="75%">
          <stop offset="0%" stopColor={def.skin} />
          <stop offset="70%" stopColor={def.skin} />
          <stop offset="100%" stopColor={skinDark} />
        </radialGradient>
      </defs>
      <motion.g style={{ transformOrigin: '50px 58px' }} {...part(quirk.head)}>
        <motion.g style={{ transformOrigin: '18px 58px' }} {...part(quirk.earL)}>
          <circle cx="20" cy="58" r="7" fill={def.skin} />
        </motion.g>
        <motion.g style={{ transformOrigin: '82px 58px' }} {...part(quirk.earR)}>
          <circle cx="80" cy="58" r="7" fill={def.skin} />
        </motion.g>
        <motion.g style={{ transformOrigin: '50px 30px' }} {...part(quirk.hair)}>
          <Hair style={def.hairStyle} color={def.hairColor} />
        </motion.g>
        <ellipse cx="50" cy="54" rx="28" ry="30" fill={`url(#${skinGradId})`} />
        {/* soft forehead sheen for a less flat, more "alive" look */}
        <ellipse cx="40" cy="38" rx="12" ry="8" fill="#ffffff" opacity={0.12} />
        {def.facialHair !== 'full' && <JawShadow skin={def.skin} />}
        <motion.g style={{ transformOrigin: '37px 45px' }} {...part(quirk.browL)}>
          <rect x="30" y="43" width="14" height="4" rx="2" fill={def.hairColor} transform="rotate(-8 37 45)" />
        </motion.g>
        <motion.g style={{ transformOrigin: '63px 45px' }} {...part(quirk.browR)}>
          <rect x="56" y="43" width="14" height="4" rx="2" fill={def.hairColor} transform="rotate(8 63 45)" />
        </motion.g>
        <motion.g style={{ transformOrigin: '38px 52px' }} animate={idleBlinkL.animate} transition={idleBlinkL.transition}>
          <circle cx="38" cy="52" r="6" fill="#fff" />
          <circle cx="38" cy="52" r="3" fill="#1a1a1a" />
        </motion.g>
        <motion.g style={{ transformOrigin: '62px 52px' }} animate={idleBlinkR.animate} transition={idleBlinkR.transition}>
          <circle cx="62" cy="52" r="6" fill="#fff" />
          <circle cx="62" cy="52" r="3" fill="#1a1a1a" />
        </motion.g>
        <path d="M50 54 q-2 8 0 10 q3 1 5 0" stroke="#00000055" fill="none" strokeWidth="2" strokeLinecap="round" />
        <motion.g style={{ transformOrigin: '50px 72px' }} {...part(quirk.mouth)}>
          <path d="M40 70 q10 8 20 0" stroke="#5a2a1a" fill="none" strokeWidth="3" strokeLinecap="round" />
        </motion.g>
        <motion.g style={{ transformOrigin: '50px 74px' }} {...part(quirk.facialHair)}>
          <FacialHairPart type={def.facialHair} color={def.hairColor} patternId={stubbleId} />
        </motion.g>
        <motion.g style={{ transformOrigin: '50px 52px' }} {...part(quirk.eyewear)}>
          <EyewearPart type={def.eyewear} accent={def.accent[0]} />
        </motion.g>
      </motion.g>
      <motion.g style={{ transformOrigin: '50px 18px' }} {...part(quirk.headwear)}>
        <HeadwearPart type={def.headwear} accent={def.accent} />
      </motion.g>
    </svg>
  );
}

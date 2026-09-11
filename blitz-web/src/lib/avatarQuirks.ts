/**
 * Per-persona idle "quirk" animations for CaricatureAvatar — a small,
 * comedic, looping tic unique to each of the 16 CARICATURES so avatars feel
 * alive instead of a static drawing. Framer-motion `animate`/`transition`
 * fragments, applied to specific sub-parts of the SVG (see CaricatureAvatar.tsx).
 */
export interface PartAnim {
  animate: Record<string, Array<number | string>>;
  transition?: Record<string, unknown>;
}

export interface QuirkSet {
  head?: PartAnim;
  hair?: PartAnim;
  facialHair?: PartAnim;
  headwear?: PartAnim;
  browL?: PartAnim;
  browR?: PartAnim;
  eyeL?: PartAnim;
  eyeR?: PartAnim;
  earL?: PartAnim;
  earR?: PartAnim;
  mouth?: PartAnim;
  eyewear?: PartAnim;
}

const loop = (duration: number, repeatDelay: number, ease: string = 'easeInOut') => ({ duration, repeat: Infinity, repeatDelay, ease });

export const QUIRKS: Record<string, QuirkSet> = {
  // The Bull: sniffs and gives a little head-butt nod, mustache flaps.
  car_bull: {
    head: { animate: { rotate: [0, -4, 0], y: [0, 3, 0] }, transition: loop(0.6, 3.2) },
    facialHair: { animate: { scaleY: [1, 1.25, 1, 1.2, 1] }, transition: loop(0.6, 3.2) },
  },
  // The Bear: a big lazy yawn — eyes squeeze shut, mouth stretches wide.
  car_bear: {
    mouth: { animate: { scaleY: [1, 2.4, 1] }, transition: loop(1.1, 4) },
    eyeL: { animate: { scaleY: [1, 0.1, 1] }, transition: loop(1.1, 4) },
    eyeR: { animate: { scaleY: [1, 0.1, 1] }, transition: loop(1.1, 4) },
  },
  // The Shark: a smug slow head tilt while the aviators catch the light.
  car_shark: {
    head: { animate: { rotate: [0, 6, 0, -3, 0] }, transition: loop(1.6, 2.4) },
    eyewear: { animate: { opacity: [0.5, 1, 0.5] }, transition: loop(1.6, 2.4) },
  },
  // The Fox: mischievous eyebrow waggle with a matching ear twitch.
  car_fox: {
    browL: { animate: { rotate: [-8, -18, -8] }, transition: loop(0.45, 2) },
    browR: { animate: { rotate: [8, 18, 8] }, transition: loop(0.45, 2) },
    earL: { animate: { rotate: [0, 14, 0] }, transition: loop(0.45, 2) },
    earR: { animate: { rotate: [0, -14, 0] }, transition: loop(0.45, 2) },
  },
  // The Analyst: nervously pushes the glasses back up the nose.
  car_owl: {
    eyewear: { animate: { y: [0, 3, 0, 3, 0] }, transition: loop(0.5, 3) },
    eyeL: { animate: { scaleY: [1, 0.1, 1] }, transition: loop(0.15, 3.6) },
    eyeR: { animate: { scaleY: [1, 0.1, 1] }, transition: loop(0.15, 3.6) },
  },
  // The Rookie: cap nods down over the eyes like dozing off, then a wink.
  car_rookie: {
    headwear: { animate: { y: [0, 5, 0] }, transition: loop(0.7, 3) },
    eyeL: { animate: { scaleY: [1, 0.1, 1] }, transition: loop(0.2, 2.6) },
  },
  // The Maverick: mohawk vibrates like static, one eyebrow raises.
  car_maverick: {
    hair: { animate: { rotate: [0, -4, 4, -3, 0] }, transition: loop(0.3, 2.5) },
    browL: { animate: { y: [0, -3, 0] }, transition: loop(0.3, 2.5) },
  },
  // The Duchess: the monocle pops off with a "boing" and springs back on.
  car_duchess: {
    eyewear: { animate: { y: [0, -12, 0], scale: [1, 0.75, 1] }, transition: loop(0.5, 3.2) },
    hair: { animate: { y: [0, -2, 0] }, transition: loop(0.5, 3.2) },
  },
  // The Sensei: a slow zen nod with a gently swaying beard.
  car_sensei: {
    head: { animate: { rotate: [0, 7, 0] }, transition: loop(1.8, 2.2, 'easeInOut') },
    facialHair: { animate: { rotate: [-2, 2, -2] }, transition: loop(1.8, 2.2) },
  },
  // The Rocket: an excited bobble-head with a flashing visor.
  car_rocket: {
    head: { animate: { rotate: [0, -3, 3, -2, 0] }, transition: loop(0.35, 1.8) },
    headwear: { animate: { opacity: [1, 0.55, 1] }, transition: loop(0.35, 1.8) },
  },
  // Diamond Hands: chews the goatee while the aviators glint.
  car_diamond: {
    facialHair: { animate: { scaleX: [1, 1.12, 0.94, 1] }, transition: loop(0.6, 2.6) },
    eyewear: { animate: { opacity: [0.55, 1, 0.55] }, transition: loop(0.6, 2.6) },
  },
  // The Whale: a gentleman's bow, tipping the top hat forward.
  car_whale: {
    head: { animate: { rotate: [0, 9, 0], y: [0, 4, 0] }, transition: loop(1, 3.6) },
    headwear: { animate: { rotate: [0, 9, 0], y: [0, 4, 0] }, transition: loop(1, 3.6) },
    facialHair: { animate: { scaleX: [1, 1.08, 1] }, transition: loop(1, 3.6) },
  },
  // The Hustler: bandana flutters in an invisible breeze, one brow smirks.
  car_hustler: {
    headwear: { animate: { rotate: [0, -4, 4, -2, 0] }, transition: loop(0.5, 2.2) },
    browL: { animate: { rotate: [0, -10, 0] }, transition: loop(0.5, 2.2) },
  },
  // The Legend: tips the top hat and twirls the mustache.
  car_legend: {
    headwear: { animate: { rotate: [0, -16, 0], y: [0, -6, 0] }, transition: loop(0.7, 3.4) },
    facialHair: { animate: { rotate: [0, 10, -10, 0] }, transition: loop(0.7, 3.4) },
  },
  // The Wolf: the afro jiggles like jelly, goatee wags along.
  car_wolf: {
    hair: { animate: { scale: [1, 1.06, 0.96, 1] }, transition: loop(0.5, 2.4) },
    facialHair: { animate: { rotate: [-4, 4, -4] }, transition: loop(0.5, 2.4) },
  },
  // The Scout: the beanie bobs while blinking rapidly, curious and alert.
  car_scout: {
    headwear: { animate: { y: [0, -4, 0, -4, 0] }, transition: loop(0.6, 2.2) },
    eyeL: { animate: { scaleY: [1, 0.1, 1, 0.1, 1] }, transition: loop(0.6, 2.2) },
    eyeR: { animate: { scaleY: [1, 0.1, 1, 0.1, 1] }, transition: loop(0.6, 2.2) },
  },
};

/** Deterministic 0..1 pseudo-random value from a string id, used to desync
 * the generic idle blink so avatars don't all blink in lockstep. */
export function seededFraction(id: string): number {
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) >>> 0;
  return (h % 1000) / 1000;
}

/**
 * Original, fictional "trader persona" caricature avatars — NOT likenesses of
 * any real person (no celebrities, no public figures). Purely invented
 * characters built from generic facial-feature parameters so CaricatureAvatar
 * can render them as stylized big-head cartoon SVGs.
 */
export type HairStyle = 'bald' | 'slick' | 'afro' | 'mohawk' | 'curly' | 'bun' | 'spiky' | 'bob';
export type FacialHair = 'none' | 'stubble' | 'mustache' | 'goatee' | 'full';
export type Eyewear = 'none' | 'round' | 'aviator' | 'monocle';
export type Headwear = 'none' | 'cap' | 'tophat' | 'beanie' | 'bandana' | 'visor';

export interface CaricatureDef {
  id: string;
  name: string;
  skin: string;
  hairColor: string;
  hairStyle: HairStyle;
  facialHair: FacialHair;
  eyewear: Eyewear;
  headwear: Headwear;
  /** two-tone halo gradient, same shape as identity.ts AVATAR_ACCENTS */
  accent: [string, string];
}

export const CARICATURES: CaricatureDef[] = [
  { id: 'car_bull', name: 'The Bull', skin: '#e0ac69', hairColor: '#241a12', hairStyle: 'slick', facialHair: 'mustache', eyewear: 'none', headwear: 'none', accent: ['#ff6b4a', '#4a1608'] },
  { id: 'car_bear', name: 'The Bear', skin: '#c68642', hairColor: '#3a2a1a', hairStyle: 'bald', facialHair: 'full', eyewear: 'none', headwear: 'none', accent: ['#7a5a3a', '#241a10'] },
  { id: 'car_shark', name: 'The Shark', skin: '#f1c27d', hairColor: '#101018', hairStyle: 'slick', facialHair: 'stubble', eyewear: 'aviator', headwear: 'none', accent: ['#5eb4ff', '#0c2a45'] },
  { id: 'car_fox', name: 'The Fox', skin: '#ffdbac', hairColor: '#b5501a', hairStyle: 'spiky', facialHair: 'goatee', eyewear: 'none', headwear: 'none', accent: ['#ff8a4c', '#7a2e0e'] },
  { id: 'car_owl', name: 'The Analyst', skin: '#e0ac69', hairColor: '#5a4a3a', hairStyle: 'bald', facialHair: 'none', eyewear: 'round', headwear: 'none', accent: ['#a78bfa', '#241a3d'] },
  { id: 'car_rookie', name: 'The Rookie', skin: '#ffdbac', hairColor: '#d6a341', hairStyle: 'curly', facialHair: 'none', eyewear: 'none', headwear: 'cap', accent: ['#f5c343', '#8a5a12'] },
  { id: 'car_maverick', name: 'The Maverick', skin: '#8d5524', hairColor: '#111111', hairStyle: 'mohawk', facialHair: 'stubble', eyewear: 'none', headwear: 'none', accent: ['#22d3ee', '#0c2f36'] },
  { id: 'car_duchess', name: 'The Duchess', skin: '#f1c27d', hairColor: '#241a12', hairStyle: 'bun', facialHair: 'none', eyewear: 'monocle', headwear: 'none', accent: ['#f472b6', '#3d0f26'] },
  { id: 'car_sensei', name: 'The Sensei', skin: '#e0ac69', hairColor: '#d6d6d6', hairStyle: 'bald', facialHair: 'full', eyewear: 'round', headwear: 'none', accent: ['#4ade80', '#0f3d24'] },
  { id: 'car_rocket', name: 'The Rocket', skin: '#c68642', hairColor: '#1c1c1c', hairStyle: 'spiky', facialHair: 'stubble', eyewear: 'none', headwear: 'visor', accent: ['#7fb8ff', '#153a5c'] },
  { id: 'car_diamond', name: 'Diamond Hands', skin: '#5c3a21', hairColor: '#0c0c0c', hairStyle: 'bald', facialHair: 'goatee', eyewear: 'aviator', headwear: 'none', accent: ['#2fe0c8', '#0c2622'] },
  { id: 'car_whale', name: 'The Whale', skin: '#ffdbac', hairColor: '#2b1b12', hairStyle: 'bald', facialHair: 'mustache', eyewear: 'none', headwear: 'tophat', accent: ['#38bdf8', '#0c2a45'] },
  { id: 'car_hustler', name: 'The Hustler', skin: '#8d5524', hairColor: '#111111', hairStyle: 'bob', facialHair: 'stubble', eyewear: 'none', headwear: 'bandana', accent: ['#facc15', '#3a2a05'] },
  { id: 'car_legend', name: 'The Legend', skin: '#e0ac69', hairColor: '#d6d6d6', hairStyle: 'slick', facialHair: 'mustache', eyewear: 'none', headwear: 'tophat', accent: ['#e879f9', '#33103d'] },
  { id: 'car_wolf', name: 'The Wolf', skin: '#f1c27d', hairColor: '#3a3a3a', hairStyle: 'afro', facialHair: 'goatee', eyewear: 'none', headwear: 'none', accent: ['#8fa0b8', '#2a3140'] },
  { id: 'car_scout', name: 'The Scout', skin: '#c68642', hairColor: '#241a12', hairStyle: 'curly', facialHair: 'none', eyewear: 'round', headwear: 'beanie', accent: ['#84cc16', '#1f2e05'] },
];

export function caricatureById(id: string): CaricatureDef | undefined {
  return CARICATURES.find((c) => c.id === id);
}

export function isCaricatureId(avatar: string): boolean {
  return avatar.startsWith('car_');
}

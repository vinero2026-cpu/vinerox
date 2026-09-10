/** Deterministic string hash so a given profile id always seeds the same
 * local leaderboard spread — not random on every render. */
function hashSeed(input: string): number {
  let h = 2166136261;
  for (let i = 0; i < input.length; i++) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const RIVAL_NAMES = [
  'Nova', 'Zarek', 'Kestrel', 'Orin', 'Talia', 'Bramwell', 'Yuki', 'Solstice',
  'Vex', 'Marlowe', 'Indra', 'Cobalt', 'Haze', 'Rune', 'Petra', 'Onyx', 'Sable', 'Quill',
];

export interface RankRow {
  name: string;
  trophies: number;
  isPlayer: boolean;
}

/**
 * There is no live cross-device backend leaderboard yet (see README). This
 * builds a believable local ladder seeded by the player's own id, with the
 * player's real trophy count correctly inserted by rank — clearly labeled
 * as a local preview in the UI, not presented as a real global ranking.
 */
export function buildLocalLeaderboard(profileId: string, playerName: string, playerTrophies: number): RankRow[] {
  const rand = mulberry32(hashSeed(profileId));
  const rivalCount = 14;
  const rivals: RankRow[] = Array.from({ length: rivalCount }, (_, i) => {
    const base = RIVAL_NAMES[Math.floor(rand() * RIVAL_NAMES.length)]!;
    const name = rand() < 0.4 ? `${base}${Math.floor(rand() * 99)}` : base;
    const spread = (rand() - 0.5) * 900 + (i - rivalCount / 2) * 45;
    const trophies = Math.max(0, Math.round(playerTrophies + spread));
    return { name, trophies, isPlayer: false };
  });
  const all = [...rivals, { name: playerName, trophies: playerTrophies, isPlayer: true }];
  all.sort((a, b) => b.trophies - a.trophies);
  return all;
}

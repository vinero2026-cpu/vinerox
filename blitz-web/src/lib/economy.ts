import type { RankTier, Wallet, MatchOutcome, RewardDrop, ChestDef, LayerId, BannerId } from './types';

/** Trophy thresholds mirror a Clash-style ladder: wider bands at the top. */
const TIER_THRESHOLDS: [RankTier, number][] = [
  ['Bronze', 0],
  ['Silver', 300],
  ['Gold', 800],
  ['Platinum', 1500],
  ['Diamond', 2500],
  ['Vinerox Master', 4000],
];

export function tierForTrophies(trophies: number): RankTier {
  let tier: RankTier = 'Bronze';
  for (const [name, min] of TIER_THRESHOLDS) {
    if (trophies >= min) tier = name;
  }
  return tier;
}

export function tierProgress(trophies: number): { tier: RankTier; next: RankTier | null; pct: number } {
  const idx = TIER_THRESHOLDS.findIndex(([, min]) => trophies < min);
  const currentIdx = idx === -1 ? TIER_THRESHOLDS.length - 1 : Math.max(0, idx - 1);
  const current = TIER_THRESHOLDS[currentIdx]!;
  const next = TIER_THRESHOLDS[currentIdx + 1] ?? null;
  if (!next) return { tier: current[0], next: null, pct: 1 };
  const span = next[1] - current[1];
  const pct = span <= 0 ? 1 : Math.min(1, Math.max(0, (trophies - current[1]) / span));
  return { tier: current[0], next: next[0], pct };
}

/**
 * Trophy delta uses a light ELO-style curve so beating a stronger field pays
 * more, and losing while trailing costs less — keeps the ladder engaging
 * instead of purely win/lose flat +/-30.
 */
export function trophyDelta(outcome: MatchOutcome, trophies: number): number {
  const base = 24;
  const tierDrag = Math.min(14, Math.floor(trophies / 400));
  if (outcome === 'win') return base + Math.max(0, 6 - tierDrag);
  if (outcome === 'loss') return -(base - Math.min(10, tierDrag));
  return 0;
}

export function coinDelta(outcome: MatchOutcome, stake: number): number {
  if (outcome === 'win') return stake; // winner takes the opponent's matching stake
  if (outcome === 'loss') return -stake;
  return 0;
}

export function settleMatch(wallet: Wallet, outcome: MatchOutcome, stake: number): { wallet: Wallet; trophyDelta: number; coinDelta: number } {
  const tDelta = trophyDelta(outcome, wallet.trophies);
  const cDelta = coinDelta(outcome, stake);
  const next: Wallet = {
    coins: Math.max(0, wallet.coins + cDelta),
    trophies: Math.max(0, wallet.trophies + tDelta),
    wins: wallet.wins + (outcome === 'win' ? 1 : 0),
    losses: wallet.losses + (outcome === 'loss' ? 1 : 0),
    draws: wallet.draws + (outcome === 'draw' ? 1 : 0),
  };
  return { wallet: next, trophyDelta: tDelta, coinDelta: cDelta };
}

const RARE_LAYERS: LayerId[] = ['heatmap', 'sentiment', 'orderflow', 'fibonacci'];
const RARE_BANNERS: BannerId[] = ['bronze_ribbon', 'silver_crest', 'golden_aegis', 'diamond_throne', 'legend_laurel'];

export function rollChestReward(kind: ChestDef['kind'], unlockedLayers: LayerId[], rand: () => number = Math.random): RewardDrop {
  const base = kind === 'free' ? 40 : kind === 'win' ? 70 : 150;
  const coins = base + Math.floor(rand() * base * 0.8);
  const rareRoll = rand();
  const layer = kind === 'milestone' && rareRoll < 0.35 ? RARE_LAYERS[Math.floor(rand() * RARE_LAYERS.length)] : undefined;
  const bannerRoll = rand();
  const banner = !layer && bannerRoll < (kind === 'milestone' ? 0.3 : kind === 'win' ? 0.12 : 0.05) ? RARE_BANNERS[Math.floor(rand() * RARE_BANNERS.length)] : undefined;

  // Character shards for a random equipped-eligible character, always on top of coins.
  const shardPool = unlockedLayers.length > 0 ? unlockedLayers : (['bollinger'] as LayerId[]);
  const shardCharacter = shardPool[Math.floor(rand() * shardPool.length)];
  const shardAmount = kind === 'milestone' ? 3 + Math.floor(rand() * 4) : kind === 'win' ? 2 + Math.floor(rand() * 3) : 1 + Math.floor(rand() * 2);

  return { coins, layer, banner, shardCharacter, shardAmount };
}

export function newChest(kind: ChestDef['kind'], delayMs = 0): ChestDef {
  return { id: `chest_${Date.now()}_${Math.floor(Math.random() * 1e6)}`, kind, readyAt: Date.now() + delayMs, opened: false };
}

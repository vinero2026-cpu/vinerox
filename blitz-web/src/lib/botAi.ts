import { mulberry32 } from './match-sim';
import type { BannerId } from './types';

/**
 * Bot skill is a 0..1 dial derived from the human's own rank, so a Bronze
 * player and a Diamond player both get a "fair" bot instead of one that
 * always dominates or always folds.
 */
export function botDifficultyForTrophies(trophies: number): number {
  const normalized = Math.min(1, trophies / 3000);
  // Keep a floor and ceiling so the bot is never a total pushover or unbeatable.
  return Math.min(0.92, Math.max(0.18, 0.28 + normalized * 0.6));
}

export interface BotTier {
  name: string;
  avatar: string;
  color: string;
  minTrophies: number;
  banner: BannerId;
}

/** Named opponent identities so a fallback match still feels like it has a
 * real rival on the other side of the table, scaled to the player's rank. */
export const BOT_TIERS: BotTier[] = [
  { name: 'Rookie Bot', avatar: '🥉', color: '#9aa5b8', minTrophies: 0, banner: 'default' },
  { name: 'Trader Bot', avatar: '🥈', color: '#c7d0dd', minTrophies: 300, banner: 'bronze_ribbon' },
  { name: 'Pro Bot', avatar: '🥇', color: '#f5c343', minTrophies: 800, banner: 'golden_aegis' },
  { name: 'Elite Bot', avatar: '💎', color: '#2fe0c8', minTrophies: 1500, banner: 'diamond_throne' },
  { name: 'Legend Bot', avatar: '👑', color: '#c084fc', minTrophies: 2500, banner: 'legend_laurel' },
];

export function botTierForTrophies(trophies: number): BotTier {
  let tier = BOT_TIERS[0]!;
  for (const t of BOT_TIERS) if (trophies >= t.minTrophies) tier = t;
  return tier;
}

export interface BotState {
  pnl: number;
}


/**
 * One bot decision per tick. `difficulty` is the chance the bot reads the
 * market correctly; misreads cost it pnl just like a human miscall does.
 */
export function botTick(state: BotState, difficulty: number, seed: number, tickIndex: number, actualUp: boolean): BotState {
  const rand = mulberry32(seed ^ (tickIndex * 7919));
  // Bots don't call every single second — occasional hesitation reads human.
  const acts = rand() < 0.82;
  if (!acts) return state;
  const guessesUp = rand() < difficulty ? actualUp : !actualUp;
  const correct = guessesUp === actualUp;
  const magnitude = 0.35 + rand() * 0.4;
  return { pnl: state.pnl + (correct ? magnitude : -magnitude * 0.55) };
}

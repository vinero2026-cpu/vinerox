import type { BannerId, LayerId } from './types';

export interface MilestoneReward {
  at: number;
  label: string;
  coins?: number;
  banner?: BannerId;
  shardCharacter?: LayerId;
  shardAmount?: number;
  boost?: { kind: 'overdrive' | 'shield'; amount: number };
  icon: string;
}

/** Free progression track keyed off total matches played (wins+losses+draws)
 * — the more you play, the more you earn. Kept deliberately modest (starts
 * at 10 V) and varied — small coin drips, character shards and bonus match
 * boosts rather than a handful of big coin dumps. */
export const MILESTONE_TRACK: MilestoneReward[] = [
  { at: 1, label: 'First Blitz', coins: 10, icon: '🎮' },
  { at: 3, label: 'Warming Up', shardCharacter: 'bollinger', shardAmount: 2, icon: '📈' },
  { at: 5, label: 'Regular', boost: { kind: 'overdrive', amount: 1 }, icon: '⚡' },
  { at: 10, label: 'Committed', coins: 25, shardCharacter: 'volume', shardAmount: 2, icon: '🎖️' },
  { at: 15, label: 'Grinder', boost: { kind: 'shield', amount: 1 }, icon: '🛡️' },
  { at: 20, label: 'Veteran', coins: 35, banner: 'bronze_ribbon', icon: '🏅' },
  { at: 30, label: 'Elite Trader', shardCharacter: 'sentiment', shardAmount: 2, icon: '🔥' },
  { at: 50, label: 'Arena Legend', coins: 60, boost: { kind: 'overdrive', amount: 2 }, icon: '👑' },
];

/** Premium track — same milestones, bigger/rarer rewards. Visible to everyone
 * as a preview of what's behind the (not-yet-purchasable) Premium Pass; see
 * ShopView for why we don't fake a working "buy" button without a real
 * payment processor wired up. */
export const PREMIUM_TRACK: MilestoneReward[] = [
  { at: 1, label: 'First Blitz+', coins: 40, icon: '🎮' },
  { at: 3, label: 'Warming Up+', shardCharacter: 'bollinger', shardAmount: 5, icon: '📈' },
  { at: 5, label: 'Regular+', boost: { kind: 'overdrive', amount: 2 }, icon: '⚡' },
  { at: 10, label: 'Committed+', coins: 120, banner: 'silver_crest', icon: '🎖️' },
  { at: 15, label: 'Grinder+', boost: { kind: 'shield', amount: 2 }, icon: '🛡️' },
  { at: 20, label: 'Veteran+', coins: 200, shardCharacter: 'orderflow', shardAmount: 5, icon: '🏅' },
  { at: 30, label: 'Elite Trader+', banner: 'diamond_throne', icon: '🔥' },
  { at: 50, label: 'Arena Legend+', coins: 500, banner: 'legend_laurel', icon: '👑' },
];


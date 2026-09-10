import type { LayerId } from './types';

export type Rarity = 'common' | 'rare' | 'epic' | 'legendary';

export const RARITY_COLOR: Record<Rarity, string> = {
  common: '#c7d0dd',
  rare: '#f0a04b',
  epic: '#a970ff',
  legendary: '#ff6bd6',
};

export interface CharacterDef {
  id: LayerId;
  /** Short technical indicator label shown above the character name, e.g. "RSI". */
  shortName: string;
  name: string;
  avatar: string;
  title: string;
  rarity: Rarity;
  /** Plain-language "explain it to a kid" description: what it measures,
   * why it helps, what info it adds — shown when tapping the level badge. */
  explain: string;
}

/** Each cockpit instrument is fronted by a character whose "spell" is that
 * indicator's visual effect on the chart — the flavor layer over the same
 * analytics engine already in TradingChart.tsx. */
export const CHARACTER_CATALOG: CharacterDef[] = [
  {
    id: 'bollinger',
    shortName: 'BOLLINGER',
    name: 'The Channeler',
    avatar: '🧙‍♂️',
    title: 'Conjures the volatility channel',
    rarity: 'common',
    explain:
      'Bollinger Bands draw a stretchy tunnel around the price. A wide tunnel means the price is bouncing around a lot; a narrow tunnel means things are calm. When the price pokes outside the tunnel, it often snaps back — that\u2019s your clue for which way to call.',
  },
  {
    id: 'volume',
    shortName: 'VOLUME',
    name: 'The Excavator',
    avatar: '⛏️',
    title: 'Digs up the volume bars',
    rarity: 'common',
    explain:
      'Volume measures how many trades are happening \u2014 like how loud the crowd is cheering. Tall bars mean lots of people are trading right now, which usually means the next move will be a bigger one.',
  },
  {
    id: 'vwap',
    shortName: 'VWAP',
    name: 'The Anchor',
    avatar: '⚓',
    title: 'Locks in the fair-value line',
    rarity: 'rare',
    explain:
      'VWAP is the \u201cfair price\u201d line \u2014 the average price everyone has paid today. Above the line, buyers are winning the tug-of-war; below the line, sellers are winning. It tells you which team currently has the upper hand.',
  },
  {
    id: 'macd',
    shortName: 'MACD',
    name: 'The Momentum Monk',
    avatar: '🥋',
    title: 'Channels the momentum cross',
    rarity: 'rare',
    explain:
      'MACD compares a fast-moving average and a slow-moving average. When the fast one catches up and crosses the slow one, it often means the direction is about to change \u2014 like the moment a runner overtakes the leader in a race.',
  },
  {
    id: 'rsi',
    shortName: 'RSI',
    name: 'The Oracle',
    avatar: '🔮',
    title: 'Reads overbought and oversold',
    rarity: 'rare',
    explain:
      'RSI is like a speedometer for the price, from 0 to 100. Above 70 means it\u2019s going \u201ctoo fast\u201d (overbought) and might slow down soon. Below 30 means it\u2019s \u201ctoo slow\u201d (oversold) and might speed back up.',
  },
  {
    id: 'fibonacci',
    shortName: 'FIBONACCI',
    name: 'The Golden Archer',
    avatar: '🏹',
    title: 'Marks the retracement levels',
    rarity: 'epic',
    explain:
      'Fibonacci levels are invisible steps traders like to bounce off, based on a number pattern found all over nature. When the price pulls back after a move, it often pauses at one of these steps before continuing.',
  },
  {
    id: 'heatmap',
    shortName: 'HEATMAP',
    name: 'The Pyromancer',
    avatar: '🔥',
    title: 'Summons the call/put heat clouds',
    rarity: 'epic',
    explain:
      'The heatmap paints the background green or red depending on how many traders are feeling bullish (up) or bearish (down) right now \u2014 like a mood ring for the whole crowd watching the chart.',
  },
  {
    id: 'orderflow',
    shortName: 'ORDER FLOW',
    name: 'The Tide Warden',
    avatar: '🌊',
    title: 'Commands the buy/sell pressure',
    rarity: 'legendary',
    explain:
      'Order Flow counts who is pushing harder right now \u2014 buyers or sellers \u2014 like an arm-wrestling match. The side with more pressure usually wins the next few seconds of price action.',
  },
  {
    id: 'sentiment',
    shortName: 'SENTIMENT',
    name: 'The Seer',
    avatar: '👁️',
    title: 'Scries the crowd sentiment radar',
    rarity: 'legendary',
    explain:
      'The Sentiment Radar listens to everyone\u2019s mood at once and shows which way the crowd is leaning. If most people are feeling \u201cup\u201d, the price often follows that crowd for a little while.',
  },
];

export function characterFor(id: LayerId): CharacterDef {
  return CHARACTER_CATALOG.find((c) => c.id === id) ?? CHARACTER_CATALOG[0]!;
}


interface BaseStats {
  durationSec: number;
  cooldownSec: number;
  bonus: number;
}

/** Rarer/costlier instruments hit harder but stay active for less time and
 * recharge slower — a glass-cannon curve so no single pick dominates. */
const BASE_STATS: Record<LayerId, BaseStats> = {
  bollinger: { durationSec: 20, cooldownSec: 15, bonus: 0.03 },
  volume: { durationSec: 20, cooldownSec: 15, bonus: 0.03 },
  vwap: { durationSec: 18, cooldownSec: 16, bonus: 0.035 },
  macd: { durationSec: 16, cooldownSec: 18, bonus: 0.04 },
  rsi: { durationSec: 16, cooldownSec: 18, bonus: 0.04 },
  fibonacci: { durationSec: 14, cooldownSec: 20, bonus: 0.045 },
  heatmap: { durationSec: 14, cooldownSec: 20, bonus: 0.05 },
  orderflow: { durationSec: 12, cooldownSec: 22, bonus: 0.055 },
  sentiment: { durationSec: 12, cooldownSec: 24, bonus: 0.06 },
};

export const MAX_CHARACTER_LEVEL = 5;

export interface CharacterStats {
  durationSec: number;
  cooldownSec: number;
  bonus: number;
}

/** Leveling up (Clash-Royale style, paid in Vinerox + shards) extends how
 * long the ability stays active, shortens its recharge, and sharpens its
 * bonus. */
export function statsForLevel(id: LayerId, level: number): CharacterStats {
  const base = BASE_STATS[id] ?? BASE_STATS.bollinger!;
  const lvl = Math.max(1, Math.min(MAX_CHARACTER_LEVEL, level));
  const step = lvl - 1;
  return {
    durationSec: base.durationSec + step * 1.5,
    cooldownSec: Math.max(4, base.cooldownSec - step * 1.2),
    bonus: +(base.bonus + step * 0.008).toFixed(3),
  };
}

export function upgradeCost(level: number): number {
  return 60 + Math.max(1, level) * 70;
}

/** Shards required to unlock the *next* level — collected from chests, shown
 * as a Clash-Royale-style progress fraction on the character card. */
export function shardsRequired(level: number): number {
  return Math.max(1, level) * 4;
}


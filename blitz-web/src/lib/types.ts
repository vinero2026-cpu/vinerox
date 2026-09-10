export type LayerId =
  | 'bollinger'
  | 'volume'
  | 'heatmap'
  | 'sentiment'
  | 'vwap'
  | 'macd'
  | 'rsi'
  | 'fibonacci'
  | 'orderflow';

export interface LayerDef {
  id: LayerId;
  name: string;
  description: string;
  cost: number;
}

/** The cockpit's full instrument pool — players pick up to 3 into a loadout. */
export const LAYER_CATALOG: LayerDef[] = [
  { id: 'bollinger', name: 'Bollinger Bands', description: 'Volatility channel that widens and tightens around the price.', cost: 0 },
  { id: 'volume', name: 'Volume Profile', description: '3D volume bars rising from the base of the chart.', cost: 0 },
  { id: 'vwap', name: 'VWAP Line', description: 'Volume-weighted average price — the market\u2019s fair-value anchor.', cost: 80 },
  { id: 'macd', name: 'MACD Momentum', description: 'Momentum histogram and signal cross along the base.', cost: 120 },
  { id: 'rsi', name: 'RSI Gauge', description: 'Live overbought/oversold dial reading the last moves.', cost: 120 },
  { id: 'fibonacci', name: 'Fibonacci Levels', description: 'Retracement levels traders watch for reversals.', cost: 160 },
  { id: 'heatmap', name: 'Call/Put Heatmap', description: 'Background color clouds showing market weight.', cost: 150 },
  { id: 'orderflow', name: 'Order Flow Pressure', description: 'Buy vs. sell pressure bars pulsing at the chart edges.', cost: 220 },
  { id: 'sentiment', name: 'Crowd Sentiment Radar', description: 'Live pulse meter of what the crowd is calling.', cost: 300 },
];

export type RankTier = 'Bronze' | 'Silver' | 'Gold' | 'Platinum' | 'Diamond' | 'Vinerox Master';

export type BannerId = 'default' | 'bronze_ribbon' | 'silver_crest' | 'golden_aegis' | 'diamond_throne' | 'legend_laurel';

export type BannerPattern = 'plain' | 'diagonal' | 'lattice' | 'sunburst' | 'facet' | 'arcs';

export interface BannerDef {
  id: BannerId;
  name: string;
  colors: [string, string];
  border: string;
  pattern: BannerPattern;
}

/** Collectible player-card frames, awarded from chests — purely cosmetic.
 * Each one also carries a distinct background `pattern` (see PlayerBanner's
 * BANNER_PATTERN_CSS) so frames read as different designs, not just recolors. */
export const BANNER_CATALOG: BannerDef[] = [
  { id: 'default', name: 'Arena Recruit', colors: ['#232b3a', '#11161f'], border: '#3a4558', pattern: 'plain' },
  { id: 'bronze_ribbon', name: 'Bronze Ribbon', colors: ['#8a5a2c', '#3a2410'], border: '#c9902a', pattern: 'diagonal' },
  { id: 'silver_crest', name: 'Silver Crest', colors: ['#8fa0b8', '#1c232f'], border: '#c7d0dd', pattern: 'lattice' },
  { id: 'golden_aegis', name: 'Golden Aegis', colors: ['#f5c343', '#3a2b06'], border: '#f5c343', pattern: 'sunburst' },
  { id: 'diamond_throne', name: 'Diamond Throne', colors: ['#2fe0c8', '#0c2622'], border: '#2fe0c8', pattern: 'facet' },
  { id: 'legend_laurel', name: "Legend's Laurel", colors: ['#c084fc', '#241030'], border: '#c084fc', pattern: 'arcs' },
];

export interface Profile {
  id: string;
  name: string;
  avatar: string;
  /** Optional uploaded/captured photo (data URL) — takes priority over the emoji avatar when present. */
  avatarImage?: string;
  flag: string;
  countryCode: string;
  createdAt: number;
}

export interface Wallet {
  coins: number;
  trophies: number;
  wins: number;
  losses: number;
  draws: number;
}

export interface ChestDef {
  id: string;
  kind: 'free' | 'win' | 'milestone';
  readyAt: number;
  opened: boolean;
}

export interface RewardDrop {
  coins: number;
  layer?: LayerId;
  banner?: BannerId;
  shardCharacter?: LayerId;
  shardAmount?: number;
}

export type MatchOutcome = 'win' | 'loss' | 'draw';

export interface MatchStartRequest {
  profileId: string;
  stake: number;
  loadout: LayerId[];
}

export interface MatchStartResponse {
  matchId: string;
  seed: number;
  asset: string;
  opponent: {
    id: string;
    name: string;
    flag: string;
    isBot: boolean;
    botDifficulty?: number;
    tierColor?: string;
    banner?: BannerId;
  };
  durationSeconds: number;
}

export interface MatchResultRequest {
  matchId: string;
  profileId: string;
  outcome: MatchOutcome;
  myPnl: number;
  opponentPnl: number;
  stake: number;
}

export interface MatchResultResponse {
  wallet: Wallet;
  trophyDelta: number;
  coinDelta: number;
  chest?: ChestDef;
}

export const ASSETS = ['NVDA', 'TSLA', 'AAPL', 'AMD', 'META', 'MSFT', 'AMZN'] as const;

export const MATCH_DURATION_SECONDS = 120;
export const BOT_FALLBACK_SECONDS = 7;

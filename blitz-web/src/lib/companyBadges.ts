import { colorForTicker } from './tickerColors';

export interface CompanyBadge {
  ticker: string;
  monogram: string;
  color: string;
}

/**
 * A curated "top companies" set for the background badges. These are
 * ORIGINAL circular monograms (a single bold letter on a brand-colored
 * gradient, like a generic fintech watchlist icon) — not a reproduction of
 * any company's actual logo artwork. Recreating real corporate logos
 * (the Apple mark, Google's "G", Tesla's T-shield, Nvidia's eye mark, etc.)
 * risks trademark/copyright infringement and false endorsement, especially
 * on a wagering-style product, and no such logo assets exist in this repo
 * (assets/crests are generic unrelated fan-club emblems).
 */
export const TOP_COMPANIES: CompanyBadge[] = [
  { ticker: 'AAPL', monogram: 'A', color: colorForTicker('AAPL') },
  { ticker: 'GOOGL', monogram: 'G', color: colorForTicker('GOOGL') },
  { ticker: 'NVDA', monogram: 'N', color: colorForTicker('NVDA') },
  { ticker: 'TSLA', monogram: 'T', color: colorForTicker('TSLA') },
  { ticker: 'MSFT', monogram: 'M', color: colorForTicker('MSFT') },
  { ticker: 'AMZN', monogram: 'Az', color: colorForTicker('AMZN') },
  { ticker: 'META', monogram: 'Mt', color: colorForTicker('META') },
  { ticker: 'NFLX', monogram: 'Nf', color: colorForTicker('NFLX') },
  { ticker: 'AMD', monogram: 'Ad', color: colorForTicker('AMD') },
];

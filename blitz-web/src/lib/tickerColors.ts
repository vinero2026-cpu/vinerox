/**
 * Brand-associated accent colors for real tickers — used to color ticker
 * TEXT/badges (factual market data), not to reproduce any company's actual
 * logo artwork. See README "Known limitations" for why: recreating real
 * corporate logos (Tesla/Apple/Google/etc.) risks trademark infringement
 * and false endorsement, especially on a wagering-style product, and no
 * such logo assets exist anywhere in this repo (checked assets/crests —
 * those are generic fan-club emblems, unrelated to real companies).
 */
export const TICKER_COLORS: Record<string, string> = {
  TSLA: '#e82127',
  GOOGL: '#4285f4',
  AAPL: '#a6a6a6',
  AMZN: '#ff9900',
  MSFT: '#8a8a8a',
  NVDA: '#76b900',
  META: '#0668e1',
  NFLX: '#e50914',
  AMD: '#ed1c24',
  JPM: '#5a2d81',
  V: '#1a1f71',
  MA: '#eb5b25',
  DIS: '#113ccf',
  KO: '#f40009',
  PEP: '#004b93',
  WMT: '#0071ce',
  XOM: '#c8102e',
  BA: '#0033a0',
  INTC: '#0071c5',
  ORCL: '#f80000',
};

export const BACKGROUND_TICKERS = Object.keys(TICKER_COLORS);

export function colorForTicker(ticker: string): string {
  return TICKER_COLORS[ticker] ?? '#9aa5b8';
}

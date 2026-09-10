/** Deterministic PRNG (mulberry32) so a given match seed renders identically
 * for both players and the server-side settlement check. */
export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export interface PriceTick {
  t: number;
  price: number;
  sentiment: number; // -1..1, drives background mood + heatmap layer
}

/** One shared random-walk price generator drives the visual chart for every
 * viewer of a match; player calls are graded against the *next* tick's move. */
export class MatchSimulator {
  private rand: () => number;
  public price: number;
  public sentiment = 0;
  public history: PriceTick[] = [];

  constructor(seed: number, startPrice = 100 + (seed % 80)) {
    this.rand = mulberry32(seed);
    this.price = startPrice;
    this.history.push({ t: 0, price: this.price, sentiment: 0 });
  }

  /** Advances the shared chart by one second; returns whether the move was up. */
  tick(t: number): { up: boolean; price: number } {
    const drift = (this.rand() - 0.49) * 2.4;
    this.sentiment = Math.max(-1, Math.min(1, this.sentiment * 0.9 + drift * 0.18));
    this.price = Math.max(1, this.price + drift);
    this.history.push({ t, price: this.price, sentiment: this.sentiment });
    return { up: drift >= 0, price: this.price };
  }
}

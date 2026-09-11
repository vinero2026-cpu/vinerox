/**
 * Daily "come back tomorrow" login bonus — a 7-day reward cycle that resets
 * the streak if a calendar day is skipped. Deliberately modest amounts, same
 * "no big prizes" policy as the milestone reward track.
 */
export interface DailyReward {
  day: number;
  coins: number;
  boost?: { kind: 'overdrive' | 'shield'; amount: number };
  icon: string;
}

export const DAILY_REWARDS: DailyReward[] = [
  { day: 1, coins: 15, icon: '💰' },
  { day: 2, coins: 20, icon: '💰' },
  { day: 3, coins: 25, boost: { kind: 'overdrive', amount: 1 }, icon: '⚡' },
  { day: 4, coins: 35, icon: '💰' },
  { day: 5, coins: 45, boost: { kind: 'shield', amount: 1 }, icon: '🛡️' },
  { day: 6, coins: 60, icon: '💰' },
  { day: 7, coins: 100, boost: { kind: 'shield', amount: 1 }, icon: '🎁' },
];

/** Local-calendar-day integer key (not a raw 24h window) so claiming late at
 * night and again the next morning still counts as consecutive days. */
function dayKey(ts: number): number {
  const d = new Date(ts);
  return Math.floor(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86400000);
}

export function isSameCalendarDay(a: number, b: number): boolean {
  return dayKey(a) === dayKey(b);
}

export function calendarDayDiff(from: number, to: number): number {
  return dayKey(to) - dayKey(from);
}

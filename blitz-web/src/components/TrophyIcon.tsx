'use client';

interface Props {
  className?: string;
  size?: number;
}

/** A single reusable trophy glyph so every "trophies" display in the app —
 * lobby card, rank table, banners, match HUD — renders the exact same icon. */
export function TrophyIcon({ className, size = 20 }: Props) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className={className} aria-hidden="true">
      <defs>
        <linearGradient id="trophyGold" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#fff3c4" />
          <stop offset="55%" stopColor="#f5c343" />
          <stop offset="100%" stopColor="#c9902a" />
        </linearGradient>
      </defs>
      <path
        d="M7 3h10v3.2c0 3.6-2.2 6.3-5 6.9v2.4h2.3a1 1 0 0 1 1 1V18H8.7v-1.5a1 1 0 0 1 1-1H12v-2.4c-2.8-.6-5-3.3-5-6.9V3Z"
        fill="url(#trophyGold)"
      />
      <path
        d="M5 4H3.5a1 1 0 0 0-1 1.2l.4 2A4 4 0 0 0 6 10.2 8.6 8.6 0 0 1 5 6V4Zm14 0h1.5a1 1 0 0 1 1 1.2l-.4 2A4 4 0 0 1 18 10.2 8.6 8.6 0 0 0 19 6V4Z"
        fill="#c9902a"
      />
      <rect x="7.5" y="19" width="9" height="2" rx="1" fill="#c9902a" />
    </svg>
  );
}

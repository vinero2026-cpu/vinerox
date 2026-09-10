/** Shared stroke-style icon set for the bottom navigation bar — kept in one
 * file so every nav icon has a consistent weight/rounding. */

interface IconProps {
  size?: number;
  className?: string;
}

export function ShopIcon({ size = 22, className }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
      <path d="M4 9l1.2-4.4A2 2 0 0 1 7.13 3h9.74a2 2 0 0 1 1.93 1.6L20 9" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" />
      <path d="M4 9h16v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V9Z" stroke="currentColor" strokeWidth={1.8} strokeLinejoin="round" />
      <path d="M9 13a3 3 0 0 0 6 0" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" />
    </svg>
  );
}

export function RankIcon({ size = 22, className }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
      <path d="M4 21V13h4v8M10 21V7h4v14M16 21v-5h4v5" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" />
      <path d="M12 3l1.4 2.9 3.2.4-2.3 2.3.6 3.2L12 10.3l-2.9 1.5.6-3.2L7.4 6.3l3.2-.4L12 3Z" fill="currentColor" />
    </svg>
  );
}

export function CompeteIcon({ size = 30, className }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
      <path d="M13 2 4 13h6l-1 9 9-11h-6l1-9Z" fill="currentColor" />
    </svg>
  );
}

export function LeagueIcon({ size = 22, className }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
      <path
        d="M12 2 4 5v6c0 5 3.4 8.4 8 10 4.6-1.6 8-5 8-10V5l-8-3Z"
        stroke="currentColor"
        strokeWidth={1.8}
        strokeLinejoin="round"
      />
      <path d="M9 12l2 2 4-4" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

export function MasterIcon({ size = 22, className }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
      <path d="M3 17l5-6 4 3 5-7 4 5" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" />
      <path d="M3 20h18" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" />
    </svg>
  );
}

export function HomeIcon({ size = 22, className }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" className={className}>
      <path d="M4 11.5 12 4l8 7.5" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" />
      <path d="M6 10v9a1 1 0 0 0 1 1h4v-6h2v6h4a1 1 0 0 0 1-1v-9" stroke="currentColor" strokeWidth={1.8} strokeLinejoin="round" />
    </svg>
  );
}

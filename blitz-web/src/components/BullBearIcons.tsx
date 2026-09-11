interface IconProps {
  size?: number;
  className?: string;
}

/** Frontal bull head with bold curved horns — simplified/thick-stroke so it
 * still reads clearly at small button sizes. The UP/bull call button face. */
export function BullFaceIcon({ size = 26, className }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill="none" className={className}>
      <path
        d="M15 16C9 15 5 10 7 4c4 0 8 3 9 8"
        stroke="currentColor"
        strokeWidth={4}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M33 16c6-1 10-6 8-12-4 0-8 3-9 8"
        stroke="currentColor"
        strokeWidth={4}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M11 24c0-8 6-13 13-13s13 5 13 13c0 6-3 10-5 12 1 1 1.6 2.4 1.6 3.8 0 4-4.3 6.2-9.6 6.2s-9.6-2.2-9.6-6.2c0-1.4.6-2.8 1.6-3.8-2-2-5-6-5-12Z"
        fill="currentColor"
      />
      <ellipse cx="24" cy="35" rx="7.5" ry="5.5" fill="black" fillOpacity={0.28} />
      <ellipse cx="20.5" cy="35.5" rx="1.6" ry="2.1" fill="currentColor" />
      <ellipse cx="27.5" cy="35.5" rx="1.6" ry="2.1" fill="currentColor" />
      <circle cx="17.5" cy="23" r="2.3" fill="black" fillOpacity={0.55} />
      <circle cx="30.5" cy="23" r="2.3" fill="black" fillOpacity={0.55} />
    </svg>
  );
}

/** Front-facing angry bear head — round ears, a furrowed unibrow and an open
 * snarl, thick-stroke so it stays readable at small button sizes. The
 * DOWN/bear call button face. */
export function BearFaceIcon({ size = 26, className }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill="none" className={className}>
      <circle cx="10.5" cy="11" r="6.5" fill="currentColor" />
      <circle cx="37.5" cy="11" r="6.5" fill="currentColor" />
      <circle cx="10.5" cy="11" r="3" fill="black" fillOpacity={0.3} />
      <circle cx="37.5" cy="11" r="3" fill="black" fillOpacity={0.3} />
      <path
        d="M10 21c0-7 6.3-12 14-12s14 5 14 12c0 6.2-2.7 10.6-5.9 13.4 1 1.3 1.6 2.9 1.6 4.6 0 4.4-4.3 8-9.7 8s-9.7-3.6-9.7-8c0-1.7.6-3.3 1.6-4.6C12.7 31.6 10 27.2 10 21Z"
        fill="currentColor"
      />
      <path d="M15 20.5c2.5-2.3 6-2.3 9-.7 3-1.6 6.5-1.6 9 .7" stroke="black" strokeOpacity={0.55} strokeWidth={3} strokeLinecap="round" />
      <circle cx="18" cy="24.5" r="2" fill="black" fillOpacity={0.6} />
      <circle cx="30" cy="24.5" r="2" fill="black" fillOpacity={0.6} />
      <path d="M15 34c3 3.5 15 3.5 18 0v3c0 3-4 6.5-9 6.5s-9-3.5-9-6.5v-3Z" fill="black" fillOpacity={0.55} />
      <path d="M20 34.5l1 3M28 34.5l-1 3" stroke="white" strokeOpacity={0.9} strokeWidth={1.8} strokeLinecap="round" />
    </svg>
  );
}

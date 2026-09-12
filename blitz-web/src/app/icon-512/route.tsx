import { ImageResponse } from 'next/og';

export const contentType = 'image/png';
export const size = { width: 512, height: 512 };

/** App icon for the PWA manifest / Android launcher — an original bolt
 * monogram on the game's own gradient, no third-party artwork. */
export function GET() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'linear-gradient(155deg, #0b0f18 0%, #141b2b 55%, #1c2540 100%)',
        }}
      >
        <div style={{ fontSize: 288, lineHeight: 1, color: '#f5c343', display: 'flex' }}>⚡</div>
      </div>
    ),
    size,
  );
}

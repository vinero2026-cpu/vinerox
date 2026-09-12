import type { MetadataRoute } from 'next';

/** PWA manifest, served at /blitz/manifest.webmanifest (basePath-prefixed
 * automatically by Next.js). Required for the Android TWA wrapper to
 * recognize this as an installable app and to size/display it correctly. */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'VINEROX Blitz Arena',
    short_name: 'Blitz Arena',
    description: '2-minute head-to-head financial esports.',
    start_url: '/blitz',
    scope: '/blitz',
    display: 'standalone',
    orientation: 'portrait-primary',
    background_color: '#0b0f18',
    theme_color: '#0b0f18',
    icons: [
      { src: '/blitz/icon-192', sizes: '192x192', type: 'image/png', purpose: 'any' },
      { src: '/blitz/icon-512', sizes: '512x512', type: 'image/png', purpose: 'any' },
      { src: '/blitz/icon-maskable-512', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
    ],
  };
}

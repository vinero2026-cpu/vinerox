import type { Metadata } from 'next';
import { Baloo_2, Inter } from 'next/font/google';
import './globals.css';

const displayFont = Baloo_2({ subsets: ['latin'], weight: ['600', '700', '800'], variable: '--font-display' });
const bodyFont = Inter({ subsets: ['latin'], weight: ['400', '500', '600', '700', '800'], variable: '--font-body' });

export const metadata: Metadata = {
  title: 'VINEROX Blitz Arena',
  description: '2-minute head-to-head financial esports — vinero.app/blitz',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${displayFont.variable} ${bodyFont.variable}`}>
      <body className="min-h-dvh bg-bg text-text font-body antialiased">{children}</body>
    </html>
  );
}

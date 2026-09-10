import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: '#05070c',
        bgAlt: '#0b0f18',
        surface: '#11161f',
        surfaceHi: '#171d29',
        stroke: '#232b3a',
        gold: '#f5c343',
        goldDeep: '#c9902a',
        teal: '#2fe0c8',
        bull: '#28e07f',
        bear: '#ff4d5e',
        text: '#f4f6fa',
        textDim: '#9aa5b8',
        textFaint: '#5d6b82',
      },
      fontFamily: {
        display: ['var(--font-display)', 'sans-serif'],
        body: ['var(--font-body)', 'sans-serif'],
      },
      keyframes: {
        rise: { '0%': { transform: 'translateY(0)', opacity: '1' }, '100%': { transform: 'translateY(-140px)', opacity: '0' } },
        pulseGlow: { '0%,100%': { boxShadow: '0 0 0 0 rgba(245,195,67,.45)' }, '50%': { boxShadow: '0 0 32px 6px rgba(245,195,67,.35)' } },
      },
      animation: {
        rise: 'rise 1.1s ease-out forwards',
        pulseGlow: 'pulseGlow 2.4s ease-in-out infinite',
      },
    },
  },
  plugins: [],
};

export default config;

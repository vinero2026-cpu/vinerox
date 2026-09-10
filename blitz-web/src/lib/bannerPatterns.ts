import type { BannerPattern } from './types';

/** CSS `background-image` per frame pattern — layered on top of the banner's
 * gradient so frames read as genuinely different designs, not just recolors. */
export function bannerPatternCss(pattern: BannerPattern, accent: string): string | undefined {
  switch (pattern) {
    case 'diagonal':
      return `repeating-linear-gradient(45deg, ${accent}33 0px, ${accent}33 6px, transparent 6px, transparent 16px)`;
    case 'lattice':
      return `linear-gradient(45deg, ${accent}2e 25%, transparent 25%, transparent 75%, ${accent}2e 75%), linear-gradient(-45deg, ${accent}2e 25%, transparent 25%, transparent 75%, ${accent}2e 75%)`;
    case 'sunburst':
      return `repeating-conic-gradient(from 0deg, ${accent}3d 0deg 8deg, transparent 8deg 20deg)`;
    case 'facet':
      return `repeating-linear-gradient(60deg, ${accent}33 0px, ${accent}33 3px, transparent 3px, transparent 22px), repeating-linear-gradient(-60deg, ${accent}26 0px, ${accent}26 3px, transparent 3px, transparent 22px)`;
    case 'arcs':
      return `radial-gradient(circle at 50% 130%, transparent 0, transparent 40%, ${accent}33 41%, ${accent}33 44%, transparent 45%), radial-gradient(circle at 50% 130%, transparent 0, transparent 56%, ${accent}26 57%, ${accent}26 60%, transparent 61%)`;
    case 'plain':
    default:
      return undefined;
  }
}

export function bannerPatternSize(pattern: BannerPattern): string | undefined {
  switch (pattern) {
    case 'diagonal':
      return '22px 22px';
    case 'lattice':
      return '18px 18px';
    case 'facet':
      return '30px 30px';
    default:
      return undefined;
  }
}

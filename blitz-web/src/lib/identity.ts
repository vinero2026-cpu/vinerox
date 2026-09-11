import { CARICATURES, caricatureById, isCaricatureId } from './caricatures';

export { CARICATURES, isCaricatureId };

/** A richer, more varied avatar set for players who skip the photo option —
 * broad mix of creatures so no two managers look alike at a glance. */
export const AVATARS = [
  '🦁', '🐺', '🦊', '🐯', '🦅', '🐉', '🦈', '🐻',
  '🐼', '🦉', '🦂', '🐊', '🦓', '🐗', '🦍', '🦚',
  '🐆', '🦌', '🦖', '🦢', '🦩', '🐙', '🦄', '🐬',
];

/** A themed two-tone gradient per avatar so the picker reads as designed
 * character badges rather than plain emoji on a flat tile. */
const AVATAR_ACCENTS: Record<string, [string, string]> = {
  '🦁': ['#f5c343', '#8a5a12'],
  '🐺': ['#8fa0b8', '#2a3140'],
  '🦊': ['#ff8a4c', '#7a2e0e'],
  '🐯': ['#ffb020', '#3a1a05'],
  '🦅': ['#7fb8ff', '#153a5c'],
  '🐉': ['#4ade80', '#0f3d24'],
  '🦈': ['#5eb4ff', '#0c2a45'],
  '🐻': ['#b5793a', '#3a2410'],
  '🐼': ['#2fe0c8', '#0c2622'],
  '🦉': ['#a78bfa', '#241a3d'],
  '🦂': ['#ff5d6c', '#3d0d12'],
  '🐊': ['#5fd47a', '#0e3320'],
  '🦓': ['#c7d0dd', '#1c232f'],
  '🐗': ['#c9902a', '#2e1c05'],
  '🦍': ['#6b7280', '#1a1e26'],
  '🦚': ['#22d3ee', '#0c2f36'],
  '🐆': ['#facc15', '#3a2a05'],
  '🦌': ['#c98a4c', '#2e1c0c'],
  '🦖': ['#84cc16', '#1f2e05'],
  '🦢': ['#f4f6fa', '#2a3140'],
  '🦩': ['#f472b6', '#3d0f26'],
  '🐙': ['#c084fc', '#2b0d3d'],
  '🦄': ['#e879f9', '#33103d'],
  '🐬': ['#38bdf8', '#0c2a45'],
};

export function avatarAccent(avatar: string): [string, string] {
  if (isCaricatureId(avatar)) return caricatureById(avatar)?.accent ?? ['#3a4558', '#11161f'];
  return AVATAR_ACCENTS[avatar] ?? ['#3a4558', '#11161f'];
}

/** ISO 3166-1 alpha-2 codes — real flag emoji generated from the code itself
 * so every country is covered without hand-typing 190+ flag glyphs. */
function flagEmoji(code: string): string {
  return code
    .toUpperCase()
    .split('')
    .map((c) => String.fromCodePoint(127397 + c.charCodeAt(0)))
    .join('');
}

const COUNTRY_CODES: [string, string][] = [
  ['US', 'United States'], ['GB', 'United Kingdom'], ['IL', 'Israel'], ['DE', 'Germany'], ['FR', 'France'],
  ['BR', 'Brazil'], ['IN', 'India'], ['JP', 'Japan'], ['CA', 'Canada'], ['AU', 'Australia'],
  ['ES', 'Spain'], ['IT', 'Italy'], ['NL', 'Netherlands'], ['PT', 'Portugal'], ['BE', 'Belgium'],
  ['CH', 'Switzerland'], ['AT', 'Austria'], ['SE', 'Sweden'], ['NO', 'Norway'], ['DK', 'Denmark'],
  ['FI', 'Finland'], ['IE', 'Ireland'], ['PL', 'Poland'], ['CZ', 'Czechia'], ['SK', 'Slovakia'],
  ['HU', 'Hungary'], ['RO', 'Romania'], ['BG', 'Bulgaria'], ['GR', 'Greece'], ['TR', 'Turkey'],
  ['UA', 'Ukraine'], ['RU', 'Russia'], ['CN', 'China'], ['KR', 'South Korea'], ['KP', 'North Korea'],
  ['TW', 'Taiwan'], ['HK', 'Hong Kong'], ['SG', 'Singapore'], ['MY', 'Malaysia'], ['ID', 'Indonesia'],
  ['TH', 'Thailand'], ['VN', 'Vietnam'], ['PH', 'Philippines'], ['PK', 'Pakistan'], ['BD', 'Bangladesh'],
  ['LK', 'Sri Lanka'], ['NP', 'Nepal'], ['MM', 'Myanmar'], ['KH', 'Cambodia'], ['LA', 'Laos'],
  ['MX', 'Mexico'], ['AR', 'Argentina'], ['CL', 'Chile'], ['CO', 'Colombia'], ['PE', 'Peru'],
  ['VE', 'Venezuela'], ['EC', 'Ecuador'], ['BO', 'Bolivia'], ['PY', 'Paraguay'], ['UY', 'Uruguay'],
  ['CR', 'Costa Rica'], ['PA', 'Panama'], ['GT', 'Guatemala'], ['HN', 'Honduras'], ['SV', 'El Salvador'],
  ['NI', 'Nicaragua'], ['CU', 'Cuba'], ['DO', 'Dominican Republic'], ['JM', 'Jamaica'], ['TT', 'Trinidad and Tobago'],
  ['ZA', 'South Africa'], ['EG', 'Egypt'], ['NG', 'Nigeria'], ['KE', 'Kenya'], ['GH', 'Ghana'],
  ['ET', 'Ethiopia'], ['TZ', 'Tanzania'], ['UG', 'Uganda'], ['DZ', 'Algeria'], ['MA', 'Morocco'],
  ['TN', 'Tunisia'], ['LY', 'Libya'], ['SN', 'Senegal'], ['CI', "Côte d'Ivoire"], ['CM', 'Cameroon'],
  ['ZW', 'Zimbabwe'], ['ZM', 'Zambia'], ['MZ', 'Mozambique'], ['AO', 'Angola'], ['NA', 'Namibia'],
  ['BW', 'Botswana'], ['RW', 'Rwanda'], ['SD', 'Sudan'],
  ['SA', 'Saudi Arabia'], ['AE', 'United Arab Emirates'], ['QA', 'Qatar'], ['KW', 'Kuwait'], ['BH', 'Bahrain'],
  ['OM', 'Oman'], ['JO', 'Jordan'], ['LB', 'Lebanon'], ['IQ', 'Iraq'], ['IR', 'Iran'],
  ['SY', 'Syria'], ['YE', 'Yemen'], ['AF', 'Afghanistan'],
  ['NZ', 'New Zealand'], ['FJ', 'Fiji'], ['PG', 'Papua New Guinea'],
  ['IS', 'Iceland'], ['LU', 'Luxembourg'], ['MT', 'Malta'], ['CY', 'Cyprus'], ['EE', 'Estonia'],
  ['LV', 'Latvia'], ['LT', 'Lithuania'], ['HR', 'Croatia'], ['SI', 'Slovenia'], ['RS', 'Serbia'],
  ['BA', 'Bosnia and Herzegovina'], ['MK', 'North Macedonia'], ['AL', 'Albania'], ['ME', 'Montenegro'], ['MD', 'Moldova'],
  ['BY', 'Belarus'], ['GE', 'Georgia'], ['AM', 'Armenia'], ['AZ', 'Azerbaijan'], ['KZ', 'Kazakhstan'],
  ['UZ', 'Uzbekistan'], ['TM', 'Turkmenistan'], ['KG', 'Kyrgyzstan'], ['TJ', 'Tajikistan'], ['MN', 'Mongolia'],
];

export const FLAGS: [string, string][] = COUNTRY_CODES.map(([code]) => [flagEmoji(code), code]);

export function countryName(code: string): string {
  return COUNTRY_CODES.find(([c]) => c === code)?.[1] ?? code;
}

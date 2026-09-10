import fs from 'node:fs';
import path from 'node:path';

/**
 * Dependency-free JSON-file persistence so the app never needs a native
 * compiled module (avoids node-gyp / build-tools issues across platforms).
 * Adequate for a demo/staging economy; swap for a real database before
 * real-money stakes go live — see README "Known limitations".
 */

export interface ProfileRow {
  id: string;
  name: string;
  avatar: string;
  flag: string;
  countryCode: string;
  coins: number;
  trophies: number;
  wins: number;
  losses: number;
  draws: number;
  createdAt: number;
}

export interface MatchRow {
  id: string;
  profileId: string;
  stake: number;
  seed: number;
  asset: string;
  opponentIsBot: boolean;
  settled: boolean;
  createdAt: number;
}

export interface ChestRow {
  id: string;
  profileId: string;
  kind: 'free' | 'win' | 'milestone';
  readyAt: number;
  opened: boolean;
  createdAt: number;
}

interface DbShape {
  profiles: Record<string, ProfileRow>;
  matches: Record<string, MatchRow>;
  chests: Record<string, ChestRow>;
}

const dataDir = path.join(process.cwd(), '.data');
const dataFile = path.join(dataDir, 'blitz.json');

function load(): DbShape {
  if (!fs.existsSync(dataFile)) return { profiles: {}, matches: {}, chests: {} };
  try {
    return JSON.parse(fs.readFileSync(dataFile, 'utf-8')) as DbShape;
  } catch {
    return { profiles: {}, matches: {}, chests: {} };
  }
}

function save(data: DbShape) {
  if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(dataFile, JSON.stringify(data, null, 2));
}

export function getProfile(id: string): ProfileRow | undefined {
  return load().profiles[id];
}

export function upsertProfile(id: string, name: string, avatar: string, flag: string, countryCode: string): ProfileRow {
  const data = load();
  const existing = data.profiles[id];
  const row: ProfileRow = existing
    ? { ...existing, name, avatar, flag, countryCode }
    : { id, name, avatar, flag, countryCode, coins: 500, trophies: 0, wins: 0, losses: 0, draws: 0, createdAt: Date.now() };
  data.profiles[id] = row;
  save(data);
  return row;
}

export function updateWallet(id: string, wallet: Pick<ProfileRow, 'coins' | 'trophies' | 'wins' | 'losses' | 'draws'>) {
  const data = load();
  const row = data.profiles[id];
  if (!row) return;
  Object.assign(row, wallet);
  save(data);
}

export function adjustCoins(id: string, delta: number) {
  const data = load();
  const row = data.profiles[id];
  if (!row) return;
  row.coins = Math.max(0, row.coins + delta);
  save(data);
}

export function createMatch(row: MatchRow) {
  const data = load();
  data.matches[row.id] = row;
  save(data);
}

export function getMatch(id: string, profileId: string): MatchRow | undefined {
  const row = load().matches[id];
  return row && row.profileId === profileId ? row : undefined;
}

export function settleMatchRow(id: string) {
  const data = load();
  const row = data.matches[id];
  if (row) {
    row.settled = true;
    save(data);
  }
}

export function createChest(row: ChestRow) {
  const data = load();
  data.chests[row.id] = row;
  save(data);
}

export function getChest(id: string, profileId: string): ChestRow | undefined {
  const row = load().chests[id];
  return row && row.profileId === profileId ? row : undefined;
}

export function openChestRow(id: string) {
  const data = load();
  const row = data.chests[id];
  if (row) {
    row.opened = true;
    save(data);
  }
}

import { NextRequest, NextResponse } from 'next/server';
import { createMatch, getProfile } from '@/lib/db';
import { ASSETS, MATCH_DURATION_SECONDS, type MatchStartRequest, type MatchStartResponse } from '@/lib/types';
import { botDifficultyForTrophies, botTierForTrophies } from '@/lib/botAi';

export async function POST(req: NextRequest) {
  const body = (await req.json()) as MatchStartRequest;
  const { profileId, stake, loadout } = body;
  if (!profileId || !stake) return NextResponse.json({ error: 'missing fields' }, { status: 400 });

  const profileRow = getProfile(profileId);
  if (!profileRow) return NextResponse.json({ error: 'unknown profile' }, { status: 404 });
  if (profileRow.coins < stake) return NextResponse.json({ error: 'insufficient balance' }, { status: 400 });

  const matchId = `m_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
  const seed = Math.floor(Math.random() * 2 ** 31);
  const asset = ASSETS[Math.floor(Math.random() * ASSETS.length)] ?? ASSETS[0];
  const difficulty = botDifficultyForTrophies(profileRow.trophies);
  const tier = botTierForTrophies(profileRow.trophies);

  createMatch({ id: matchId, profileId, stake, seed, asset, opponentIsBot: true, settled: false, createdAt: Date.now() });

  const response: MatchStartResponse = {
    matchId,
    seed,
    asset,
    opponent: { id: 'bot', name: tier.name, flag: tier.avatar, isBot: true, botDifficulty: difficulty, tierColor: tier.color, banner: tier.banner },
    durationSeconds: MATCH_DURATION_SECONDS,
  };
  void loadout;
  return NextResponse.json(response);
}


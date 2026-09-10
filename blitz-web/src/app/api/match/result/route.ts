import { NextRequest, NextResponse } from 'next/server';
import { createChest, getMatch, getProfile, settleMatchRow, updateWallet } from '@/lib/db';
import { settleMatch } from '@/lib/economy';
import type { MatchResultRequest, MatchResultResponse, Wallet } from '@/lib/types';

export async function POST(req: NextRequest) {
  const body = (await req.json()) as MatchResultRequest;
  const { matchId, profileId, outcome, stake } = body;
  if (!matchId || !profileId || !outcome) return NextResponse.json({ error: 'missing fields' }, { status: 400 });

  const match = getMatch(matchId, profileId);
  if (!match) return NextResponse.json({ error: 'unknown match' }, { status: 404 });
  if (match.settled) return NextResponse.json({ error: 'already settled' }, { status: 409 });

  const row = getProfile(profileId);
  if (!row) return NextResponse.json({ error: 'unknown profile' }, { status: 404 });

  const currentWallet: Wallet = { coins: row.coins, trophies: row.trophies, wins: row.wins, losses: row.losses, draws: row.draws };
  const { wallet, trophyDelta, coinDelta } = settleMatch(currentWallet, outcome, stake);

  updateWallet(profileId, wallet);
  settleMatchRow(matchId);

  let chest;
  if (outcome === 'win') {
    chest = { id: `chest_${Date.now()}`, kind: 'win' as const, readyAt: Date.now(), opened: false };
    createChest({ id: chest.id, profileId, kind: chest.kind, readyAt: chest.readyAt, opened: false, createdAt: Date.now() });
  }

  const response: MatchResultResponse = { wallet, trophyDelta, coinDelta, chest };
  return NextResponse.json(response);
}


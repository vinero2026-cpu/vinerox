import { NextRequest, NextResponse } from 'next/server';
import { getProfile, upsertProfile, type ProfileRow } from '@/lib/db';
import type { Wallet } from '@/lib/types';

function toWallet(row: ProfileRow): Wallet {
  return { coins: row.coins, trophies: row.trophies, wins: row.wins, losses: row.losses, draws: row.draws };
}

export async function GET(req: NextRequest) {
  const id = req.nextUrl.searchParams.get('id');
  if (!id) return NextResponse.json({ error: 'missing id' }, { status: 400 });
  const row = getProfile(id);
  if (!row) return NextResponse.json({ profile: null });
  return NextResponse.json({
    profile: { id: row.id, name: row.name, avatar: row.avatar, flag: row.flag, countryCode: row.countryCode, createdAt: row.createdAt },
    wallet: toWallet(row),
  });
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { id, name, avatar, flag, countryCode } = body as { id: string; name: string; avatar: string; flag: string; countryCode: string };
  if (!id || !name || !avatar || !flag) return NextResponse.json({ error: 'missing fields' }, { status: 400 });

  const row = upsertProfile(id, name, avatar, flag, countryCode ?? '');
  return NextResponse.json({
    profile: { id: row.id, name: row.name, avatar: row.avatar, flag: row.flag, countryCode: row.countryCode, createdAt: row.createdAt },
    wallet: toWallet(row),
  });
}


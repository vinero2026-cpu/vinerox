import { NextRequest, NextResponse } from 'next/server';
import { adjustCoins, getChest, openChestRow } from '@/lib/db';
import { rollChestReward } from '@/lib/economy';
import { LAYER_CATALOG } from '@/lib/types';

export async function POST(req: NextRequest) {
  const { chestId, profileId } = (await req.json()) as { chestId: string; profileId: string };
  if (!chestId || !profileId) return NextResponse.json({ error: 'missing fields' }, { status: 400 });

  const chest = getChest(chestId, profileId);
  if (!chest) return NextResponse.json({ error: 'unknown chest' }, { status: 404 });
  if (chest.opened) return NextResponse.json({ error: 'already opened' }, { status: 409 });

  // Server route doesn't track per-player unlocks yet, so shards roll across the full catalog.
  const reward = rollChestReward(chest.kind, LAYER_CATALOG.map((l) => l.id));
  openChestRow(chestId);
  adjustCoins(profileId, reward.coins);

  return NextResponse.json({ reward });
}


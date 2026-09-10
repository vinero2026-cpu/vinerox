'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import type { ChestDef, Profile, Wallet } from '@/lib/types';
import { tierProgress } from '@/lib/economy';
import { MILESTONE_TRACK, PREMIUM_TRACK, type MilestoneReward } from '@/lib/milestones';
import { AnimatedNumber } from './AnimatedNumber';
import { CoinIcon } from './CoinIcon';
import { PlayerBanner } from './PlayerBanner';
import { ProfileModal } from './ProfileModal';
import { RewardTrack } from './RewardTrack';
import { TrophyIcon } from './TrophyIcon';

interface Props {
  profile: Profile;
  wallet: Wallet;
  chests: ChestDef[];
  claimedMilestones: number[];
  claimedPremiumMilestones: number[];
  onClaimMilestone: (reward: MilestoneReward, track?: 'free' | 'premium') => void;
  onOpenChest: (chest: ChestDef) => void;
  onSaveProfile: (patch: { name: string; avatar: string; avatarImage?: string; flag: string; countryCode: string }) => void;
  muted: boolean;
  onToggleMute: () => void;
}

/** Home hub — a dashboard of the manager's own stats. Character upgrades now
 * live solely in Loadout, and frames/rank moved to Shop/Rank so nothing here
 * is duplicated across screens. */
export function LobbyView({
  profile,
  wallet,
  chests,
  claimedMilestones,
  claimedPremiumMilestones,
  onClaimMilestone,
  onOpenChest,
  onSaveProfile,
  muted,
  onToggleMute,
}: Props) {
  const { tier, next, pct } = tierProgress(wallet.trophies);
  const openChests = chests.filter((c) => !c.opened);
  const matchesPlayed = wallet.wins + wallet.losses + wallet.draws;
  const [editingProfile, setEditingProfile] = useState(false);

  return (
    <div className="mx-auto min-h-dvh max-w-2xl px-5 py-8 pb-32">
      <header className="flex items-center justify-between gap-3">
        <button onClick={() => setEditingProfile(true)} className="text-left transition hover:opacity-90">
          <PlayerBanner
            name={profile.name}
            avatar={profile.avatar}
            avatarImage={profile.avatarImage}
            countryCode={profile.countryCode}
            trophies={wallet.trophies}
            tag={{ label: tier, color: '#f5c343' }}
            size="sm"
          />
        </button>
        <button
          onClick={onToggleMute}
          className="grid h-10 w-10 shrink-0 place-items-center rounded-full border border-stroke bg-surface/50 text-lg backdrop-blur-md transition hover:border-gold/60"
          aria-label="Toggle sound"
        >
          {muted ? '🔇' : '🔊'}
        </button>
      </header>

      <div className="mt-3 h-2 w-full overflow-hidden rounded-full bg-surface shadow-inner">
        <motion.div
          className="h-full rounded-full bg-gradient-to-r from-teal to-gold"
          initial={{ width: 0 }}
          animate={{ width: `${pct * 100}%` }}
          transition={{ duration: 0.8, ease: 'easeOut' }}
        />
      </div>
      {next && <div className="mt-1 text-right text-xs text-textFaint">Next: {next}</div>}

      <div className="mt-6 grid grid-cols-2 gap-4">
        <div className="flex items-center gap-3 rounded-2xl border border-gold/50 bg-gradient-to-br from-gold/20 via-surface/50 to-bgAlt/50 p-4 shadow-[0_18px_40px_-24px_rgba(245,195,67,.5)] backdrop-blur-md">
          <CoinIcon size={32} />
          <div>
            <div className="text-xs font-bold uppercase tracking-wider text-textDim">Vinerox balance</div>
            <div className="font-display mt-1 text-3xl font-black text-gold">
              <AnimatedNumber value={wallet.coins} />
            </div>
          </div>
        </div>
        <div className="flex items-center gap-3 rounded-2xl border border-teal/50 bg-gradient-to-br from-teal/20 via-surface/50 to-bgAlt/50 p-4 shadow-[0_18px_40px_-24px_rgba(47,224,200,.5)] backdrop-blur-md">
          <TrophyIcon size={32} />
          <div>
            <div className="text-xs font-bold uppercase tracking-wider text-textDim">Trophies</div>
            <div className="font-display mt-1 text-3xl font-black text-teal">
              <AnimatedNumber value={wallet.trophies} />
            </div>
          </div>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-3 gap-3 text-center text-sm">
        <div className="rounded-xl border border-stroke bg-surface/45 py-2 backdrop-blur-md">
          <div className="font-bold text-bull">{wallet.wins}</div>
          <div className="text-xs text-textFaint">Wins</div>
        </div>
        <div className="rounded-xl border border-stroke bg-surface/45 py-2 backdrop-blur-md">
          <div className="font-bold text-bear">{wallet.losses}</div>
          <div className="text-xs text-textFaint">Losses</div>
        </div>
        <div className="rounded-xl border border-stroke bg-surface/45 py-2 backdrop-blur-md">
          <div className="font-bold text-textDim">{wallet.draws}</div>
          <div className="text-xs text-textFaint">Draws</div>
        </div>
      </div>

      <RewardTrack title="Play track" track={MILESTONE_TRACK} matchesPlayed={matchesPlayed} claimedMilestones={claimedMilestones} onClaim={(r) => onClaimMilestone(r, 'free')} accent="#f5c343" />
      <RewardTrack
        title="Premium track"
        track={PREMIUM_TRACK}
        matchesPlayed={matchesPlayed}
        claimedMilestones={claimedPremiumMilestones}
        onClaim={(r) => onClaimMilestone(r, 'premium')}
        locked
        accent="#c084fc"
      />

      <div className="mt-8">
        <div className="mb-2 text-xs font-bold uppercase tracking-wider text-textDim [text-shadow:0_1px_3px_rgba(0,0,0,.8)]">Reward chests</div>
        {openChests.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-stroke p-6 text-center text-sm text-textFaint">
            Win a match to earn a chest.
          </div>
        ) : (
          <div className="flex gap-3 overflow-x-auto pb-2" style={{ perspective: 600 }}>
            {openChests.map((chest) => (
              <motion.button
                whileTap={{ scale: 0.94 }}
                whileHover={{ rotateX: -8, rotateY: 8, scale: 1.04 }}
                key={chest.id}
                onClick={() => onOpenChest(chest)}
                className="grid min-w-[104px] place-items-center gap-2 rounded-2xl border border-gold/50 bg-gradient-to-b from-gold/25 to-bgAlt px-4 py-5 shadow-[0_12px_28px_-14px_rgba(245,195,67,.6)] animate-pulseGlow"
              >
                <span className="text-3xl">📦</span>
                <span className="text-xs font-bold uppercase text-gold">{chest.kind}</span>
              </motion.button>
            ))}
          </div>
        )}
      </div>

      <p className="mt-10 text-center text-xs text-textFaint">Tap the gold COMPETE button below to pick your squad and find a rival.</p>

      {editingProfile && (
        <ProfileModal
          name={profile.name}
          avatar={profile.avatar}
          avatarImage={profile.avatarImage}
          flag={profile.flag}
          onClose={() => setEditingProfile(false)}
          onSave={(patch) => {
            onSaveProfile(patch);
            setEditingProfile(false);
          }}
        />
      )}
    </div>
  );
}


'use client';

import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { BannerId, ChestDef, LayerId, Profile, Wallet } from './types';
import { MAX_CHARACTER_LEVEL, shardsRequired, upgradeCost } from './characters';
import type { MilestoneReward } from './milestones';

interface BlitzState {
  profile: Profile | null;
  wallet: Wallet;
  loadout: LayerId[];
  unlockedLayers: LayerId[];
  characterLevels: Partial<Record<LayerId, number>>;
  characterShards: Partial<Record<LayerId, number>>;
  unlockedBanners: BannerId[];
  equippedBanner: BannerId;
  chests: ChestDef[];
  claimedMilestones: number[];
  claimedPremiumMilestones: number[];
  bonusBoosts: { overdrive: number; shield: number };
  hydrated: boolean;
  setProfile: (p: Profile) => void;
  updateProfile: (patch: Partial<Pick<Profile, 'name' | 'avatar' | 'avatarImage' | 'flag' | 'countryCode'>>) => void;
  setLoadout: (layers: LayerId[]) => void;
  unlockLayer: (layer: LayerId) => void;
  upgradeCharacter: (layer: LayerId) => void;
  equipBanner: (banner: BannerId) => void;
  applyMatchResult: (walletDelta: { coins: number; trophies: number }, outcome: 'win' | 'loss' | 'draw') => void;
  addChest: (chest: ChestDef) => void;
  openChest: (id: string, coins: number, layer?: LayerId, banner?: BannerId, shardCharacter?: LayerId, shardAmount?: number) => void;
  claimMilestone: (reward: MilestoneReward, track?: 'free' | 'premium') => void;
  consumeBonusBoosts: () => { overdrive: number; shield: number };
  setHydrated: () => void;
}

const defaultWallet: Wallet = { coins: 500, trophies: 0, wins: 0, losses: 0, draws: 0 };

export const useBlitzStore = create<BlitzState>()(
  persist(
    (set, get) => ({
      profile: null,
      wallet: defaultWallet,
      loadout: ['bollinger', 'volume'],
      unlockedLayers: ['bollinger', 'volume'],
      characterLevels: { bollinger: 1, volume: 1 },
      characterShards: {},
      unlockedBanners: ['default'],
      equippedBanner: 'default',
      chests: [],
      claimedMilestones: [],
      claimedPremiumMilestones: [],
      bonusBoosts: { overdrive: 0, shield: 0 },
      hydrated: false,
      setProfile: (profile) => set({ profile }),
      updateProfile: (patch) => set((s) => (s.profile ? { profile: { ...s.profile, ...patch } } : s)),
      setLoadout: (loadout) => set({ loadout: loadout.slice(0, 3) }),
      unlockLayer: (layer) =>
        set((s) => ({
          unlockedLayers: s.unlockedLayers.includes(layer) ? s.unlockedLayers : [...s.unlockedLayers, layer],
          characterLevels: s.characterLevels[layer] ? s.characterLevels : { ...s.characterLevels, [layer]: 1 },
        })),
      upgradeCharacter: (layer) => {
        const s = get();
        const level = s.characterLevels[layer] ?? 1;
        if (level >= MAX_CHARACTER_LEVEL) return;
        const cost = upgradeCost(level);
        const needed = shardsRequired(level);
        const shards = s.characterShards[layer] ?? 0;
        if (s.wallet.coins < cost || shards < needed) return;
        set({
          wallet: { ...s.wallet, coins: s.wallet.coins - cost },
          characterLevels: { ...s.characterLevels, [layer]: level + 1 },
          characterShards: { ...s.characterShards, [layer]: shards - needed },
        });
      },
      equipBanner: (banner) => set({ equippedBanner: banner }),
      applyMatchResult: (delta, outcome) =>
        set((s) => ({
          wallet: {
            coins: Math.max(0, s.wallet.coins + delta.coins),
            trophies: Math.max(0, s.wallet.trophies + delta.trophies),
            wins: s.wallet.wins + (outcome === 'win' ? 1 : 0),
            losses: s.wallet.losses + (outcome === 'loss' ? 1 : 0),
            draws: s.wallet.draws + (outcome === 'draw' ? 1 : 0),
          },
        })),
      addChest: (chest) => set((s) => ({ chests: [...s.chests, chest] })),
      openChest: (id, coins, layer, banner, shardCharacter, shardAmount) =>
        set((s) => ({
          chests: s.chests.map((c) => (c.id === id ? { ...c, opened: true } : c)),
          wallet: { ...s.wallet, coins: s.wallet.coins + coins },
          unlockedLayers: layer && !s.unlockedLayers.includes(layer) ? [...s.unlockedLayers, layer] : s.unlockedLayers,
          characterLevels: layer && !s.characterLevels[layer] ? { ...s.characterLevels, [layer]: 1 } : s.characterLevels,
          unlockedBanners: banner && !s.unlockedBanners.includes(banner) ? [...s.unlockedBanners, banner] : s.unlockedBanners,
          characterShards:
            shardCharacter && shardAmount
              ? { ...s.characterShards, [shardCharacter]: (s.characterShards[shardCharacter] ?? 0) + shardAmount }
              : s.characterShards,
        })),
      claimMilestone: (reward, track = 'free') =>
        set((s) => ({
          claimedMilestones: track === 'free' && !s.claimedMilestones.includes(reward.at) ? [...s.claimedMilestones, reward.at] : s.claimedMilestones,
          claimedPremiumMilestones:
            track === 'premium' && !s.claimedPremiumMilestones.includes(reward.at) ? [...s.claimedPremiumMilestones, reward.at] : s.claimedPremiumMilestones,
          wallet: { ...s.wallet, coins: s.wallet.coins + (reward.coins ?? 0) },
          unlockedBanners:
            reward.banner && !s.unlockedBanners.includes(reward.banner) ? [...s.unlockedBanners, reward.banner] : s.unlockedBanners,
          characterShards:
            reward.shardCharacter && reward.shardAmount
              ? { ...s.characterShards, [reward.shardCharacter]: (s.characterShards[reward.shardCharacter] ?? 0) + reward.shardAmount }
              : s.characterShards,
          bonusBoosts: reward.boost
            ? { ...s.bonusBoosts, [reward.boost.kind]: s.bonusBoosts[reward.boost.kind] + reward.boost.amount }
            : s.bonusBoosts,
        })),
      consumeBonusBoosts: () => {
        const current = get().bonusBoosts;
        set({ bonusBoosts: { overdrive: 0, shield: 0 } });
        return current;
      },
      setHydrated: () => set({ hydrated: true }),
    }),
    {
      name: 'vinerox-blitz-store',
      onRehydrateStorage: () => (state) => state?.setHydrated(),
    },
  ),
);




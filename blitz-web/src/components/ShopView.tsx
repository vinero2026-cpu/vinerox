'use client';

import { motion } from 'framer-motion';
import { BANNER_CATALOG, type BannerId, type LayerId, type Wallet } from '@/lib/types';
import { CHARACTER_CATALOG, MAX_CHARACTER_LEVEL, RARITY_COLOR, shardsRequired, statsForLevel, upgradeCost } from '@/lib/characters';
import { bannerPatternCss, bannerPatternSize } from '@/lib/bannerPatterns';
import { CoinIcon } from './CoinIcon';

interface Props {
  wallet: Wallet;
  unlockedLayers: LayerId[];
  characterLevels: Partial<Record<LayerId, number>>;
  characterShards: Partial<Record<LayerId, number>>;
  onUpgradeCharacter: (layer: LayerId) => void;
  unlockedBanners: BannerId[];
  equippedBanner: BannerId;
  onEquipBanner: (banner: BannerId) => void;
}

const COIN_PACKS = [
  { coins: 500, label: '500 V' },
  { coins: 1200, label: '1,200 V' },
  { coins: 3000, label: '3,000 V' },
  { coins: 8000, label: '8,000 V' },
];

/** Central store for coins, character upgrades, and profile frames — the
 * hub the bottom nav's Shop tab opens into. Coin packs are shown as an
 * honest "Coming soon" catalog since no real payment processor is wired up
 * yet; we don't fake a purchase flow that implies real money changes hands. */
export function ShopView({
  wallet,
  unlockedLayers,
  characterLevels,
  characterShards,
  onUpgradeCharacter,
  unlockedBanners,
  equippedBanner,
  onEquipBanner,
}: Props) {
  return (
    <div className="mx-auto min-h-dvh max-w-2xl px-5 py-8 pb-32">
      <h1 className="font-display text-2xl font-black">Shop</h1>
      <p className="mt-1 text-sm text-textDim">Coins, character upgrades, and profile frames.</p>

      <div className="mt-6 flex items-center gap-3 rounded-2xl border border-gold/50 bg-gradient-to-br from-gold/20 via-surface/50 to-bgAlt/50 p-4 backdrop-blur-md">
        <CoinIcon size={30} />
        <div>
          <div className="text-xs font-bold uppercase tracking-wider text-textDim">Your balance</div>
          <div className="font-display text-2xl font-black text-gold">{wallet.coins}</div>
        </div>
      </div>

      <div className="mt-8">
        <div className="mb-2 text-xs font-bold uppercase tracking-wider text-textDim">Vinerox coin packs</div>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {COIN_PACKS.map((pack) => (
            <div
              key={pack.label}
              className="relative flex flex-col items-center gap-2 rounded-2xl border border-stroke bg-surface/45 p-4 text-center opacity-60 backdrop-blur-md"
            >
              <span className="absolute right-2 top-2 rounded-full border border-stroke px-1.5 py-0.5 text-[9px] font-black uppercase text-textFaint">
                🔒 Soon
              </span>
              <CoinIcon size={26} />
              <span className="text-sm font-black text-gold">{pack.label}</span>
              <button disabled className="w-full cursor-not-allowed rounded-lg border border-stroke py-1.5 text-xs font-bold text-textFaint">
                Buy
              </button>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-8">
        <div className="mb-2 text-xs font-bold uppercase tracking-wider text-textDim">Upgrade characters</div>
        <div className="flex flex-col gap-2">
          {CHARACTER_CATALOG.filter((c) => unlockedLayers.includes(c.id)).map((c) => {
            const level = characterLevels[c.id] ?? 1;
            const maxed = level >= MAX_CHARACTER_LEVEL;
            const cost = upgradeCost(level);
            const needed = shardsRequired(level);
            const shards = characterShards[c.id] ?? 0;
            const canUpgrade = !maxed && wallet.coins >= cost && shards >= needed;
            const rarityColor = RARITY_COLOR[c.rarity];
            const stats = statsForLevel(c.id, level);
            return (
              <div
                key={c.id}
                className="flex items-center gap-3 rounded-xl border p-3"
                style={{ borderColor: `${rarityColor}60`, background: `linear-gradient(90deg, ${rarityColor}14, transparent)` }}
              >
                <span className="text-2xl">{c.avatar}</span>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 text-sm font-bold">
                    <span style={{ color: rarityColor }}>{c.shortName}</span>
                    <span className="text-xs text-textFaint">Lv.{level}</span>
                    <span className="text-xs text-textFaint">· {stats.durationSec.toFixed(0)}s active</span>
                  </div>
                  {!maxed && (
                    <div className="mt-1">
                      <div className="h-1.5 w-full overflow-hidden rounded-full border border-stroke/60 bg-bgAlt">
                        <div
                          className="h-full rounded-full"
                          style={{ width: `${Math.max(4, Math.min(100, (shards / needed) * 100))}%`, background: rarityColor }}
                        />
                      </div>
                      <div className="mt-0.5 text-[10px] text-textFaint">
                        {shards}/{needed} shards
                      </div>
                    </div>
                  )}
                </div>
                <button
                  onClick={() => onUpgradeCharacter(c.id)}
                  disabled={maxed || !canUpgrade}
                  className="shrink-0 rounded-lg border px-3 py-1.5 text-xs font-black uppercase transition disabled:opacity-30"
                  style={{ borderColor: maxed ? '#2fe0c8' : `${rarityColor}90`, color: maxed ? '#2fe0c8' : rarityColor }}
                >
                  {maxed ? 'Max' : `${cost} V`}
                </button>
              </div>
            );
          })}
        </div>
      </div>

      <div className="mt-8">
        <div className="mb-2 text-xs font-bold uppercase tracking-wider text-textDim">Card frames</div>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          {BANNER_CATALOG.map((b) => {
            const owned = unlockedBanners.includes(b.id);
            const equipped = equippedBanner === b.id;
            return (
              <motion.div
                key={b.id}
                whileHover={owned ? { y: -2 } : undefined}
                className="relative flex flex-col items-center gap-2 overflow-hidden rounded-2xl border p-4 text-center backdrop-blur-md"
                style={{
                  borderColor: equipped ? '#f5c343' : b.border + '80',
                  background: `linear-gradient(160deg, ${b.colors[0]}40, ${b.colors[1]}66)`,
                }}
              >
                <div
                  className="pointer-events-none absolute inset-0"
                  style={{ backgroundImage: bannerPatternCss(b.pattern, b.border), backgroundSize: bannerPatternSize(b.pattern) }}
                />
                {!owned && (
                  <span className="absolute right-2 top-2 rounded-full border border-stroke bg-black/40 px-1.5 py-0.5 text-[9px] font-black uppercase text-textFaint">
                    🔒
                  </span>
                )}
                <span className="text-sm font-black uppercase">{b.name}</span>
                {owned ? (
                  <button
                    onClick={() => onEquipBanner(b.id)}
                    className={`relative w-full rounded-lg border px-2 py-1.5 text-xs font-black uppercase transition ${
                      equipped ? 'border-gold text-gold' : 'border-stroke text-textFaint'
                    }`}
                  >
                    {equipped ? 'Equipped' : 'Equip'}
                  </button>
                ) : (
                  <button disabled className="relative w-full cursor-not-allowed rounded-lg border border-stroke py-1.5 text-xs font-bold text-textFaint">
                    Coming soon
                  </button>
                )}
              </motion.div>
            );
          })}
        </div>
        <p className="mt-3 text-center text-xs text-textFaint">Locked frames also drop from reward chests.</p>
      </div>
    </div>
  );
}

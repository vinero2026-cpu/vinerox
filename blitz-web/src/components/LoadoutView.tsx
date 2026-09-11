'use client';

import { useState } from 'react';
import { motion, Reorder } from 'framer-motion';
import { LAYER_CATALOG, type LayerId } from '@/lib/types';
import { CHARACTER_CATALOG, MAX_CHARACTER_LEVEL, RARITY_COLOR, characterFor, shardsRequired, statsForLevel, upgradeCost } from '@/lib/characters';
import { FlipCard } from './FlipCard';

interface Props {
  coins: number;
  unlockedLayers: LayerId[];
  characterLevels: Partial<Record<LayerId, number>>;
  characterShards: Partial<Record<LayerId, number>>;
  onUpgradeCharacter: (layer: LayerId) => void;
  initialLoadout: LayerId[];
  onUnlock: (layer: LayerId, cost: number) => void;
  onConfirm: (loadout: LayerId[], stake: number) => void;
  onBack: () => void;
}

const STAKES = [10, 25, 50, 100];

export function LoadoutView({
  coins,
  unlockedLayers,
  characterLevels,
  characterShards,
  onUpgradeCharacter,
  initialLoadout,
  onUnlock,
  onConfirm,
  onBack,
}: Props) {
  const [loadout, setLoadout] = useState<LayerId[]>(initialLoadout);
  const [stake, setStake] = useState(STAKES[0]!);
  const [explainingId, setExplainingId] = useState<LayerId | null>(null);

  const toggle = (id: LayerId) => {
    setLoadout((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : prev.length < 3 ? [...prev, id] : prev));
  };

  return (
    <div className="mx-auto min-h-dvh max-w-3xl px-5 py-8">
      <button onClick={onBack} className="text-sm text-textDim transition hover:text-text">
        ← Back to lobby
      </button>
      <h1 className="font-display mt-3 text-2xl font-black">Cockpit Loadout</h1>
      <p className="mt-1 text-sm text-textDim">
        Pick up to 3 instruments to bring into battle — {loadout.length}/3 selected.
      </p>

      <div className="mt-4">
        <div className="mb-2 text-xs font-bold uppercase tracking-wider text-textDim">Your squad · drag to reorder</div>
        <Reorder.Group
          as="div"
          axis="x"
          values={loadout}
          onReorder={setLoadout}
          className="flex gap-2.5 overflow-x-auto rounded-2xl border border-dashed border-stroke bg-surface/60 p-3"
        >
          {loadout.map((id) => {
            const char = characterFor(id);
            const rarityColor = RARITY_COLOR[char.rarity];
            return (
              <Reorder.Item
                key={id}
                value={id}
                whileDrag={{ scale: 1.08, zIndex: 10, boxShadow: '0 12px 24px rgba(0,0,0,.5)' }}
                className="flex min-w-[92px] shrink-0 cursor-grab flex-col items-center gap-1 rounded-xl border p-2 text-center active:cursor-grabbing"
                style={{ borderColor: `${rarityColor}90`, background: `linear-gradient(160deg, ${rarityColor}22, #11161f)` }}
              >
                <span className="text-2xl">{char.avatar}</span>
                <span className="text-xs font-black uppercase leading-tight">{char.shortName}</span>
                <button
                  onClick={() => toggle(id)}
                  className="mt-0.5 rounded-full border border-stroke px-2 py-0.5 text-[11px] font-bold text-textFaint transition hover:border-bear hover:text-bear"
                >
                  Remove
                </button>
              </Reorder.Item>
            );
          })}
          {Array.from({ length: 3 - loadout.length }).map((_, i) => (
            <div
              key={`empty-${i}`}
              className="grid min-w-[92px] shrink-0 place-items-center rounded-xl border border-dashed border-stroke text-center text-xs text-textFaint"
              style={{ minHeight: 92 }}
            >
              Empty slot
            </div>
          ))}
        </Reorder.Group>
      </div>

      <div className="mt-6 grid grid-cols-4 gap-2">
        {LAYER_CATALOG.map((layer) => {
          const unlocked = unlockedLayers.includes(layer.id);
          const active = loadout.includes(layer.id);
          const affordable = coins >= layer.cost;
          const char = CHARACTER_CATALOG.find((c) => c.id === layer.id)!;
          const rarityColor = RARITY_COLOR[char.rarity];
          const level = characterLevels[layer.id] ?? 1;
          const maxed = level >= MAX_CHARACTER_LEVEL;
          const cost = upgradeCost(level);
          const needed = shardsRequired(level);
          const shards = characterShards[layer.id] ?? 0;
          const canUpgrade = unlocked && !maxed && coins >= cost && shards >= needed;
          const current = statsForLevel(layer.id, level);
          const nextLevel = statsForLevel(layer.id, level + 1);
          const flipped = explainingId === layer.id;

          return (
            <FlipCard
              key={layer.id}
              flipped={flipped}
              className="h-[168px] w-full"
              front={
                <motion.div
                  whileHover={{ y: -2 }}
                  className={`relative flex h-full flex-col items-center overflow-hidden rounded-xl border p-2 text-center transition ${
                    active ? 'shadow-[0_12px_24px_-14px_rgba(47,224,200,.6)]' : ''
                  } ${!unlocked && !affordable ? 'opacity-50' : ''}`}
                  style={{
                    borderColor: unlocked ? (active ? '#2fe0c8' : `${rarityColor}80`) : '#232b3a',
                    background: unlocked
                      ? `linear-gradient(160deg, ${rarityColor}1f, #11161f 65%, #05070c)`
                      : 'rgba(17,22,31,.7)',
                  }}
                >
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      setExplainingId(layer.id);
                    }}
                    className="absolute right-1.5 top-1.5 z-10 grid h-5 w-5 place-items-center rounded-full text-[10px] font-black text-black transition hover:scale-110"
                    style={{ background: rarityColor }}
                    aria-label="What does this indicator do?"
                  >
                    {unlocked ? level : 'ⓘ'}
                  </button>
                  <button
                    onClick={() => (unlocked ? toggle(layer.id) : affordable && onUnlock(layer.id, layer.cost))}
                    disabled={!unlocked && !affordable}
                    className="flex w-full flex-1 flex-col items-center disabled:cursor-not-allowed"
                  >
                    <span className="mt-2 text-2xl">{char.avatar}</span>
                    <span className="mt-1 text-[11px] font-black uppercase leading-tight" style={{ color: rarityColor }}>
                      {char.shortName}
                    </span>
                    {!unlocked ? (
                      <span className="mt-1 text-[10px] font-bold text-gold">{layer.cost} V</span>
                    ) : (
                      active && <span className="mt-1 text-[10px] font-bold uppercase text-teal">In squad</span>
                    )}
                  </button>

                  {unlocked && (
                    <div className="mt-auto w-full pt-1.5">
                      {!maxed && (
                        <div className="h-1 w-full overflow-hidden rounded-full border border-stroke/60 bg-bgAlt">
                          <div
                            className="h-full rounded-full"
                            style={{ width: `${Math.max(4, Math.min(100, (shards / needed) * 100))}%`, background: rarityColor }}
                          />
                        </div>
                      )}
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          onUpgradeCharacter(layer.id);
                        }}
                        disabled={maxed || !canUpgrade}
                        className="mt-1.5 w-full rounded-md border px-1 py-1 text-[10px] font-black uppercase transition disabled:opacity-30"
                        style={{ borderColor: maxed ? '#2fe0c8' : `${rarityColor}90`, color: maxed ? '#2fe0c8' : rarityColor }}
                      >
                        {maxed ? 'Max' : `${cost} V`}
                      </button>
                    </div>
                  )}
                </motion.div>
              }
              back={
                <button
                  onClick={() => setExplainingId(null)}
                  className="flex h-full w-full flex-col items-center gap-1 overflow-y-auto rounded-xl border p-2 text-center"
                  style={{ borderColor: `${rarityColor}90`, background: '#05070cf2' }}
                >
                  <span className="text-lg">{char.avatar}</span>
                  <span className="text-[10px] font-black uppercase tracking-wide" style={{ color: rarityColor }}>
                    {char.shortName}
                  </span>
                  <p className="text-left text-[10px] leading-snug text-textDim">{char.explain}</p>
                  {unlocked && !maxed && (
                    <p className="text-left text-[9px] leading-snug text-textFaint">
                      Lv.{level + 1}: {nextLevel.durationSec.toFixed(1)}s ({current.durationSec.toFixed(1)}s now), {nextLevel.cooldownSec.toFixed(1)}s cd, +
                      {(nextLevel.bonus * 100).toFixed(1)}%.
                    </p>
                  )}
                  <span className="mt-auto text-[8px] font-bold uppercase text-textFaint">Tap to flip back</span>
                </button>
              }
            />
          );
        })}
      </div>

      <div className="mt-8">
        <div className="mb-2 text-xs font-bold uppercase tracking-wider text-textDim">Ranked stake</div>
        <div className="grid grid-cols-4 gap-2">
          {STAKES.map((s) => (
            <button
              key={s}
              onClick={() => setStake(s)}
              disabled={coins < s}
              className={`rounded-xl border py-2 text-sm font-bold backdrop-blur-md transition disabled:opacity-30 ${
                stake === s ? 'border-gold bg-gold/15 text-gold' : 'border-stroke bg-surface/45'
              }`}
            >
              {s} V
            </button>
          ))}
        </div>
        <div className="mt-2 text-center text-xs text-textFaint">Pot: {stake * 2} Vinerox</div>
      </div>

      <motion.button
        whileHover={{ scale: 1.015 }}
        whileTap={{ scale: 0.98 }}
        disabled={coins < stake}
        onClick={() => onConfirm(loadout, stake)}
        className="mt-8 w-full rounded-2xl bg-gradient-to-r from-teal to-emerald-400 py-4 text-lg font-black uppercase tracking-wide text-black shadow-[0_0_28px_rgba(47,224,200,.4)] disabled:opacity-30"
      >
        Find rival · {stake} Vinerox
      </motion.button>
    </div>
  );
}


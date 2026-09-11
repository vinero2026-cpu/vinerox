'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { MatchSimulator, type PriceTick } from '@/lib/match-sim';
import { botTick, type BotState } from '@/lib/botAi';
import { characterFor, RARITY_COLOR, statsForLevel } from '@/lib/characters';
import type { LayerId, MatchOutcome, MatchStartResponse } from '@/lib/types';
import { colorForTicker } from '@/lib/tickerColors';
import { TradingChart } from './TradingChart';
import { PlayerHud } from './PlayerHud';
import { CoinFountain, type CoinBurst } from './CoinFountain';
import { AnimatedNumber } from './AnimatedNumber';
import { AbilityCastOverlay } from './AbilityCastOverlay';
import { ActiveAbilityAura } from './ActiveAbilityAura';
import { TrophyIcon } from './TrophyIcon';
import { sound } from '@/lib/sound';

interface Props {
  match: MatchStartResponse;
  stake: number;
  loadout: LayerId[];
  characterLevels: Partial<Record<LayerId, number>>;
  playerName: string;
  playerFlag: string;
  playerCountryCode?: string;
  playerAvatar: string;
  bonusBoosts?: { overdrive: number; shield: number };
  socket: WebSocket | null;
  onSentiment?: (sentiment: number) => void;
  onFinish: (outcome: MatchOutcome, myPnl: number, opponentPnl: number) => void;
}

/** Minimum gap between calls — the previous version let rapid clicking stack
 * uncapped gains within a second; this throttles input to one graded call
 * per cooldown window regardless of click speed. */
const CALL_COOLDOWN_MS = 650;
/** Three wrong-direction calls in a row locks the buttons out for a long
 * "reloading" cooldown instead of the normal short one. */
const MISS_STREAK_LIMIT = 3;
const RELOAD_PENALTY_MS = 10000;
type BoostKind = 'overdrive' | 'shield';

export function MatchView({ match, stake, loadout, characterLevels, playerName, playerFlag, playerCountryCode, playerAvatar, bonusBoosts, socket, onSentiment, onFinish }: Props) {
  const sim = useMemo(() => new MatchSimulator(match.seed), [match.seed]);
  const [history, setHistory] = useState<PriceTick[]>(sim.history);
  const [secondsLeft, setSecondsLeft] = useState(match.durationSeconds);
  const [myPnl, setMyPnl] = useState(0);
  const [oppPnl, setOppPnl] = useState(0);
  const [flash, setFlash] = useState('');
  const [bursts, setBursts] = useState<CoinBurst[]>([]);
  const [activeLayers, setActiveLayers] = useState<LayerId[]>([]);
  const [finished, setFinished] = useState(false);
  const [cooling, setCooling] = useState(false);
  const [cooldownMs, setCooldownMs] = useState(CALL_COOLDOWN_MS);
  const [isPenalty, setIsPenalty] = useState(false);
  const [cooldownKey, setCooldownKey] = useState(0);
  const [impact, setImpact] = useState<{ id: number; correct: boolean } | null>(null);
  const [shakeKey, setShakeKey] = useState(0);
  const [streak, setStreak] = useState(0);
  const [castOverlay, setCastOverlay] = useState<{ id: LayerId; key: number } | null>(null);
  const [boostCharges, setBoostCharges] = useState<Record<BoostKind, number>>({
    overdrive: 1 + (bonusBoosts?.overdrive ?? 0),
    shield: 1 + (bonusBoosts?.shield ?? 0),
  });
  const [pendingBoost, setPendingBoost] = useState<BoostKind | null>(null);
  const [boostFlash, setBoostFlash] = useState<BoostKind | null>(null);

  const botStateRef = useRef<BotState>({ pnl: 0 });
  const tickIndexRef = useRef(0);
  const finishedRef = useRef(false);
  const myPnlRef = useRef(0);
  const oppPnlRef = useRef(0);
  const coolingRef = useRef(false);
  const streakRef = useRef(0);
  const missStreakRef = useRef(0);
  const cooldownTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pendingBoostRef = useRef<BoostKind | null>(null);
  const abilityTimersRef = useRef<Record<string, { activeUntil: number; cooldownUntil: number }>>({});
  const chartRef = useRef<HTMLDivElement>(null);
  const topHudRef = useRef<HTMLDivElement>(null);
  const bottomDockRef = useRef<HTMLDivElement>(null);
  const [chartInsets, setChartInsets] = useState({ top: 170, bottom: 220 });

  const streakBonus = Math.min(0.06, streak * 0.01);
  const layerBonus = activeLayers.reduce((sum, id) => sum + statsForLevel(id, characterLevels[id] ?? 1).bonus, 0);
  const chance = Math.min(0.88, 0.5 + layerBonus + streakBonus);

  // Keep the chart's plotted safe-zone in sync with the ACTUAL rendered
  // height of the floating HUD bars (they resize as the streak badge, active
  // ability chips, etc. appear/disappear) so the line and its indicator
  // overlays never end up hidden underneath them.
  useEffect(() => {
    const topEl = topHudRef.current;
    const bottomEl = bottomDockRef.current;
    if (!topEl || !bottomEl) return;
    const update = () => setChartInsets({ top: topEl.offsetHeight + 12, bottom: bottomEl.offsetHeight + 12 });
    update();
    const ro = new ResizeObserver(update);
    ro.observe(topEl);
    ro.observe(bottomEl);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    sound.startCrowd();
    return () => {
      sound.stopCrowd();
      if (cooldownTimeoutRef.current) clearTimeout(cooldownTimeoutRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!socket) return;
    const handler = (event: MessageEvent) => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === 'opponent_tick') {
          oppPnlRef.current = msg.pnl;
          setOppPnl(msg.pnl);
        }
        if (msg.type === 'opponent_left') setFlash('OPPONENT DISCONNECTED');
      } catch {
        /* ignore malformed frame */
      }
    };
    socket.addEventListener('message', handler);
    return () => socket.removeEventListener('message', handler);
  }, [socket]);

  const finish = (finalMine: number, finalOpp: number) => {
    if (finishedRef.current) return;
    finishedRef.current = true;
    setFinished(true);
    const outcome: MatchOutcome = finalMine > finalOpp ? 'win' : finalMine < finalOpp ? 'loss' : 'draw';
    if (outcome === 'win') sound.victory();
    else if (outcome === 'loss') sound.defeat();
    if (socket) socket.send(JSON.stringify({ type: 'finish', matchId: match.matchId }));
    setTimeout(() => onFinish(outcome, finalMine, finalOpp), 1400);
  };

  useEffect(() => {
    const interval = setInterval(() => {
      tickIndexRef.current += 1;
      const t = tickIndexRef.current;
      const { up } = sim.tick(t);
      setHistory([...sim.history]);
      onSentiment?.(sim.sentiment);

      if (match.opponent.isBot) {
        botStateRef.current = botTick(botStateRef.current, match.opponent.botDifficulty ?? 0.5, match.seed, t, up);
        oppPnlRef.current = botStateRef.current.pnl;
        setOppPnl(botStateRef.current.pnl);
      }

      // Expire any cast ability whose active duration has elapsed.
      const now = Date.now();
      setActiveLayers((prev) => prev.filter((id) => {
        const timer = abilityTimersRef.current[id];
        return !timer || now < timer.activeUntil;
      }));

      setSecondsLeft((s) => {
        const next = s - 1;
        if (next <= 0) {
          clearInterval(interval);
          finish(myPnlRef.current, oppPnlRef.current);
          return 0;
        }
        return next;
      });
    }, 1000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const call = (up: boolean) => {
    if (finished || coolingRef.current) return;
    void up;

    const startCooldown = (ms: number, penalty: boolean) => {
      if (cooldownTimeoutRef.current) clearTimeout(cooldownTimeoutRef.current);
      coolingRef.current = true;
      setCooling(true);
      setCooldownMs(ms);
      setIsPenalty(penalty);
      setCooldownKey((k) => k + 1);
      cooldownTimeoutRef.current = setTimeout(() => {
        coolingRef.current = false;
        setCooling(false);
        setIsPenalty(false);
      }, ms);
    };
    startCooldown(CALL_COOLDOWN_MS, false);

    const boost = pendingBoostRef.current;
    pendingBoostRef.current = null;
    setPendingBoost(null);

    let correct = Math.random() < chance;
    if (boost === 'shield' && !correct) {
      // Shield absorbs the next miss entirely — no gain, no loss, no streak hit.
      setFlash('SHIELD ABSORBED');
      setStreak(0);
      streakRef.current = 0;
      sound.layerToggle(false);
      setTimeout(() => setFlash(''), 900);
      return;
    }
    let magnitude = correct ? 0.4 + Math.random() * 0.4 : -(0.16 + Math.random() * 0.1);
    if (boost === 'overdrive' && correct) magnitude *= 2;

    const nextStreak = correct ? streakRef.current + 1 : 0;
    streakRef.current = nextStreak;
    setStreak(nextStreak);

    let penaltyTriggered = false;
    if (correct) {
      missStreakRef.current = 0;
    } else {
      missStreakRef.current += 1;
      if (missStreakRef.current >= MISS_STREAK_LIMIT) {
        missStreakRef.current = 0;
        penaltyTriggered = true;
        startCooldown(RELOAD_PENALTY_MS, true);
      }
    }

    const nextMine = myPnlRef.current + magnitude;
    myPnlRef.current = nextMine;
    setMyPnl(nextMine);
    setFlash(
      correct
        ? `${boost === 'overdrive' ? '⚡ ' : ''}+${(magnitude * 100).toFixed(0)}% CALL`
        : penaltyTriggered
          ? `${MISS_STREAK_LIMIT} MISCALLS · RELOADING ${RELOAD_PENALTY_MS / 1000}s`
          : 'MISREAD · PRESSURE',
    );
    setImpact({ id: Date.now(), correct });
    sound.click();
    if (correct) {
      sound.coin();
      sound.roar(1.1);
      const rect = chartRef.current?.getBoundingClientRect();
      const x = rect ? rect.left + rect.width / 2 : window.innerWidth / 2;
      const y = rect ? rect.top + rect.height / 2 : window.innerHeight * 0.5;
      const burstId = Date.now();
      setBursts((b) => [...b, { id: burstId, x, y }]);
      setTimeout(() => setBursts((b) => b.filter((burst) => burst.id !== burstId)), 1200);
      if (magnitude > 0.65) setShakeKey((k) => k + 1);
    } else {
      sound.roar(0.6);
    }
    setTimeout(() => setFlash(''), penaltyTriggered ? 2200 : 900);
    setTimeout(() => setImpact(null), 700);
    if (socket && !match.opponent.isBot) socket.send(JSON.stringify({ type: 'tick', matchId: match.matchId, pnl: nextMine }));
  };

  const useBoost = (kind: BoostKind) => {
    if (finished || pendingBoostRef.current || boostCharges[kind] <= 0) return;
    pendingBoostRef.current = kind;
    setPendingBoost(kind);
    setBoostCharges((b) => ({ ...b, [kind]: b[kind] - 1 }));
    setBoostFlash(kind);
    sound.powerUp();
    const rect = chartRef.current?.getBoundingClientRect();
    const x = rect ? rect.left + rect.width / 2 : window.innerWidth / 2;
    const y = rect ? rect.top + rect.height / 2 : window.innerHeight * 0.5;
    const burstId = Date.now();
    setBursts((b) => [...b, { id: burstId, x, y, icon: kind === 'overdrive' ? '⚡' : '🛡', count: 12 }]);
    setTimeout(() => setBursts((b) => b.filter((burst) => burst.id !== burstId)), 1200);
    setShakeKey((k) => k + 1);
    setTimeout(() => setBoostFlash(null), 1100);
  };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowUp') call(true);
      if (e.key === 'ArrowDown') call(false);
      if (e.key === '1') useBoost('overdrive');
      if (e.key === '2') useBoost('shield');
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chance, finished, boostCharges, pendingBoost]);

  /** Casts a character's ability: goes active for its level-scaled duration,
   * then locks out on a level-scaled cooldown — never a permanent toggle. */
  const castAbility = (id: LayerId) => {
    if (finished) return;
    const now = Date.now();
    const timer = abilityTimersRef.current[id];
    if (timer && now < timer.cooldownUntil) return;

    const level = characterLevels[id] ?? 1;
    const stats = statsForLevel(id, level);
    const activeUntil = now + stats.durationSec * 1000;
    const cooldownUntil = activeUntil + stats.cooldownSec * 1000;
    abilityTimersRef.current[id] = { activeUntil, cooldownUntil };
    setActiveLayers((prev) => (prev.includes(id) ? prev : [...prev, id]));

    const char = characterFor(id);
    const rarityIntensity: Record<string, number> = { common: 0.35, rare: 0.55, epic: 0.75, legendary: 1 };
    sound.powerUp(rarityIntensity[char.rarity] ?? 0.5);
    setCastOverlay({ id, key: Date.now() });
    setTimeout(() => setCastOverlay(null), 950);
    const rect = chartRef.current?.getBoundingClientRect();
    const x = rect ? rect.left + rect.width / 2 : window.innerWidth / 2;
    const y = rect ? rect.top + rect.height / 2 : window.innerHeight * 0.5;
    const burstId = Date.now();
    setBursts((b) => [...b, { id: burstId, x, y, icon: char.avatar, count: 10 }]);
    setTimeout(() => setBursts((b) => b.filter((burst) => burst.id !== burstId)), 1200);
  };

  const leading = myPnl >= oppPnl;
  const time = `${Math.floor(secondsLeft / 60).toString().padStart(2, '0')}:${(secondsLeft % 60).toString().padStart(2, '0')}`;
  const accent = leading ? '#28e07f' : '#ff4d5e';
  const tickerColor = colorForTicker(match.asset);
  const lastPrice = history[history.length - 1]?.price ?? 0;

  return (
    <div
      className="relative h-dvh w-full overflow-hidden"
      style={{ background: `radial-gradient(circle at 50% 0%, ${accent}14, transparent 60%)` }}
    >
      {/* FULL-SCREEN CHART — the graph is the entire backdrop, everything else floats over it */}
      <motion.div
        ref={chartRef}
        key={shakeKey}
        animate={shakeKey ? { x: [0, -6, 6, -4, 4, 0] } : {}}
        transition={{ duration: 0.4 }}
        className="absolute inset-0 bg-gradient-to-b from-surface/80 to-bgAlt/90"
      >
        <TradingChart history={history} layers={activeLayers} leading={leading} topInset={chartInsets.top} bottomInset={chartInsets.bottom} />
        <ActiveAbilityAura activeLayers={activeLayers} characterLevels={characterLevels} />
        <AnimatePresence>
          {impact && (
            <motion.div
              key={impact.id}
              initial={{ opacity: 0.55, scale: 0.2 }}
              animate={{ opacity: 0, scale: 2.6 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.7, ease: 'easeOut' }}
              className="pointer-events-none absolute inset-0"
              style={{
                background: `radial-gradient(circle at 50% 55%, ${impact.correct ? '#28e07f55' : '#ff4d5e55'}, transparent 60%)`,
              }}
            />
          )}
        </AnimatePresence>
        <AnimatePresence>
          {flash && (
            <motion.div
              initial={{ opacity: 0, scale: 0.8, y: 6 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.8 }}
              className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 rounded-xl border px-4 py-2 font-bold backdrop-blur-sm"
              style={{ borderColor: accent, color: accent, backgroundColor: '#0b0f18cc' }}
            >
              {flash}
            </motion.div>
          )}
        </AnimatePresence>
        <AnimatePresence>
          {boostFlash && (
            <motion.div
              initial={{ opacity: 0, scale: 0.5, y: -10 }}
              animate={{ opacity: 1, scale: [1.15, 1], y: 0 }}
              exit={{ opacity: 0, scale: 0.6 }}
              transition={{ duration: 0.4 }}
              className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 rounded-full border px-4 py-1.5 text-xs font-black uppercase shadow-[0_0_24px_rgba(245,195,67,.5)]"
              style={{
                borderColor: boostFlash === 'overdrive' ? '#f5c343' : '#2fe0c8',
                color: boostFlash === 'overdrive' ? '#f5c343' : '#2fe0c8',
                backgroundColor: '#0b0f18e6',
              }}
            >
              {boostFlash === 'overdrive' ? '⚡ OVERDRIVE ARMED · NEXT CALL ×2' : '🛡 SHIELD ARMED · NEXT MISS SAFE'}
            </motion.div>
          )}
        </AnimatePresence>
        <AbilityCastOverlay cast={castOverlay} />
        <CoinFountain bursts={bursts} />
      </motion.div>

      {/* TOP HUD — floats over the chart, gradient scrim keeps text readable */}
      <div ref={topHudRef} className="absolute inset-x-0 top-0 z-20 bg-gradient-to-b from-bg/95 via-bg/55 to-transparent px-4 pb-10 pt-4">
        <header className="flex items-center justify-between gap-3">
          <div className="relative" style={{ perspective: 500 }}>
            <motion.div
              initial={{ rotateY: -18 }}
              animate={{ rotateY: [-18, 18, -18] }}
              transition={{ duration: 7, repeat: Infinity, ease: 'easeInOut' }}
              className="relative rounded-xl border px-3 py-1.5 text-center"
              style={{
                borderColor: `${tickerColor}80`,
                background: `linear-gradient(160deg, ${tickerColor}35, #11161f 60%, #05070c)`,
                boxShadow: `0 10px 30px -8px ${tickerColor}66, inset 0 1px 0 rgba(255,255,255,.08)`,
                transformStyle: 'preserve-3d',
              }}
            >
              <div
                className="font-display text-lg font-black tracking-wider"
                style={{
                  color: '#f4f6fa',
                  textShadow: `0 1px 0 ${tickerColor}, 0 2px 0 ${tickerColor}aa, 0 3px 6px rgba(0,0,0,.6)`,
                }}
              >
                {match.asset}
              </div>
              <div className="font-display text-sm font-bold text-textDim">
                $<AnimatedNumber value={lastPrice} format={(v) => v.toFixed(2)} duration={0.35} />
              </div>
            </motion.div>
          </div>

          <div className="text-right">
            <div className="font-display text-xl font-black" style={{ color: secondsLeft < 15 ? '#ff4d5e' : '#f5c343' }}>
              {time}
            </div>
          </div>
        </header>

        <div className="relative mt-3 flex items-center justify-between gap-2">
          <PlayerHud name={playerName} flag={playerFlag} countryCode={playerCountryCode} avatar={playerAvatar} pnl={myPnl} leading={leading} />
          <motion.div
            animate={{ scale: [1, 1.06, 1] }}
            transition={{ duration: 1.6, repeat: Infinity }}
            className="z-10 flex shrink-0 flex-col items-center gap-0.5 select-none"
          >
            <span className="font-display text-[9px] font-black italic" style={{ color: accent }}>
              VS
            </span>
            <div
              className="flex items-center gap-1 whitespace-nowrap rounded-full border border-gold/60 bg-gold/10 px-2 py-0.5 font-display text-[11px] font-black text-gold"
              style={{ boxShadow: `0 0 12px ${accent}55` }}
            >
              <TrophyIcon size={12} /> {stake * 2} V
            </div>
          </motion.div>
          <PlayerHud
            name={match.opponent.name}
            flag={match.opponent.isBot ? '' : match.opponent.flag}
            avatar={match.opponent.isBot ? match.opponent.flag : '🎮'}
            pnl={oppPnl}
            leading={!leading}
            align="right"
          />
        </div>

        <div className="mt-3 flex items-center gap-3">
          <div className="flex-1">
            <div className="mb-1 flex items-center justify-between text-[10px] font-display font-bold uppercase tracking-wider text-textDim">
              <span>Call confidence</span>
              <span className="text-teal">{Math.round(chance * 100)}%</span>
            </div>
            <div className="h-1.5 w-full overflow-hidden rounded-full bg-surface">
              <motion.div
                className="h-full rounded-full bg-gradient-to-r from-teal to-gold"
                animate={{ width: `${chance * 100}%` }}
                transition={{ duration: 0.3 }}
              />
            </div>
          </div>
          {streak > 0 && (
            <motion.div
              key={streak}
              initial={{ scale: 0.6, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              className="flex items-center gap-1 rounded-full border border-gold/50 bg-gold/10 px-2.5 py-1 font-display text-xs font-black text-gold"
            >
              🔥 {streak}
            </motion.div>
          )}
        </div>
      </div>

      {/* BOTTOM CONTROL DOCK — floats over the chart at the very bottom of the screen */}
      <div ref={bottomDockRef} className="absolute inset-x-0 bottom-0 z-20 bg-gradient-to-t from-bg/95 via-bg/70 to-transparent px-4 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-10">
        <div className="grid grid-cols-3 gap-1.5">
          {loadout.map((id) => {
            const char = characterFor(id);
            const rarityColor = RARITY_COLOR[char.rarity];
            const level = characterLevels[id] ?? 1;
            const stats = statsForLevel(id, level);
            const now = Date.now();
            const timer = abilityTimersRef.current[id];
            const isActive = !!timer && now < timer.activeUntil;
            const isCooling = !!timer && !isActive && now < timer.cooldownUntil;
            const pct = isActive
              ? (timer!.activeUntil - now) / (stats.durationSec * 1000)
              : isCooling
                ? (timer!.cooldownUntil - now) / (stats.cooldownSec * 1000)
                : 0;
            const secsLeft = isActive ? Math.ceil((timer!.activeUntil - now) / 1000) : isCooling ? Math.ceil((timer!.cooldownUntil - now) / 1000) : 0;
            return (
              <motion.button
                key={id}
                onClick={() => castAbility(id)}
                disabled={finished || isActive || isCooling}
                whileTap={{ scale: 0.95 }}
                animate={isActive ? { boxShadow: [`0 0 6px ${rarityColor}55`, `0 0 18px ${rarityColor}aa`, `0 0 6px ${rarityColor}55`] } : {}}
                transition={isActive ? { duration: 1.1, repeat: Infinity } : {}}
                className="relative flex flex-col items-center gap-0.5 overflow-hidden rounded-lg border px-1.5 py-1.5 text-center transition disabled:cursor-not-allowed"
                style={{
                  borderColor: isActive || !isCooling ? rarityColor : '#232b3a',
                  background: isActive ? `${rarityColor}22` : isCooling ? 'rgba(17,22,31,.6)' : `linear-gradient(160deg, ${rarityColor}18, #11161f)`,
                  opacity: isCooling ? 0.6 : 1,
                }}
              >
                <span className="text-sm">{char.avatar}</span>
                <span className="truncate font-display text-[11px] font-black uppercase leading-tight" style={{ color: rarityColor }}>
                  {char.shortName}
                </span>
                <span className="font-display text-[9px] font-bold" style={{ color: isActive ? rarityColor : '#8892a4' }}>
                  +{Math.round(stats.bonus * 100)}% {isActive ? `· ${secsLeft}s` : isCooling ? `· ${secsLeft}s` : `· Lv.${level}`}
                </span>
                {(isActive || isCooling) && (
                  <div className="absolute bottom-0 left-0 h-1 w-full bg-bgAlt">
                    <div className="h-full" style={{ width: `${pct * 100}%`, background: rarityColor }} />
                  </div>
                )}
              </motion.button>
            );
          })}
        </div>

        <div className="mt-2 grid grid-cols-2 gap-1.5">
          <button
            onClick={() => useBoost('overdrive')}
            disabled={finished || boostCharges.overdrive <= 0 || pendingBoost !== null}
            className={`flex items-center justify-center gap-1.5 rounded-lg border px-2.5 py-1.5 font-display text-[11px] font-black uppercase transition disabled:opacity-30 ${
              pendingBoost === 'overdrive' ? 'border-gold bg-gold/20 text-gold' : 'border-gold/50 text-gold hover:bg-gold/10'
            }`}
          >
            ⚡ Overdrive ×{boostCharges.overdrive}
          </button>
          <button
            onClick={() => useBoost('shield')}
            disabled={finished || boostCharges.shield <= 0 || pendingBoost !== null}
            className={`flex items-center justify-center gap-1.5 rounded-lg border px-2.5 py-1.5 font-display text-[11px] font-black uppercase transition disabled:opacity-30 ${
              pendingBoost === 'shield' ? 'border-teal bg-teal/20 text-teal' : 'border-teal/50 text-teal hover:bg-teal/10'
            }`}
          >
            🛡 Shield ×{boostCharges.shield}
          </button>
        </div>

        <div className="mt-2.5 grid grid-cols-2 gap-3">
          <div className="relative overflow-hidden rounded-2xl">
            <button
              onClick={() => call(false)}
              disabled={cooling || finished}
              className="flex w-full items-center justify-center gap-2 rounded-2xl bg-bear py-4 font-display text-lg font-black uppercase text-white shadow-[0_0_20px_rgba(255,77,94,.4)] transition disabled:opacity-40"
            >
              {isPenalty && cooling ? (
                <>
                  <motion.span animate={{ rotate: 360 }} transition={{ duration: 0.9, repeat: Infinity, ease: 'linear' }}>
                    ⟳
                  </motion.span>
                  Reloading
                </>
              ) : (
                '↓ Down'
              )}
            </button>
            {cooling && (
              <motion.div
                key={`down-${cooldownKey}`}
                initial={{ width: '100%' }}
                animate={{ width: '0%' }}
                transition={{ duration: cooldownMs / 1000, ease: 'linear' }}
                className={`absolute bottom-0 left-0 h-1 ${isPenalty ? 'bg-gold' : 'bg-white/70'}`}
              />
            )}
          </div>
          <div className="relative overflow-hidden rounded-2xl">
            <button
              onClick={() => call(true)}
              disabled={cooling || finished}
              className="flex w-full items-center justify-center gap-2 rounded-2xl bg-bull py-4 font-display text-lg font-black uppercase text-white shadow-[0_0_20px_rgba(40,224,127,.4)] transition disabled:opacity-40"
            >
              {isPenalty && cooling ? (
                <>
                  <motion.span animate={{ rotate: 360 }} transition={{ duration: 0.9, repeat: Infinity, ease: 'linear' }}>
                    ⟳
                  </motion.span>
                  Reloading
                </>
              ) : (
                '↑ Up'
              )}
            </button>
            {cooling && (
              <motion.div
                key={`up-${cooldownKey}`}
                initial={{ width: '100%' }}
                animate={{ width: '0%' }}
                transition={{ duration: cooldownMs / 1000, ease: 'linear' }}
                className={`absolute bottom-0 left-0 h-1 ${isPenalty ? 'bg-gold' : 'bg-white/70'}`}
              />
            )}
          </div>
        </div>
        <div className="pt-1.5 text-center text-[11px] text-textFaint">↑ / ↓ arrow keys · 1 = Overdrive · 2 = Shield</div>
      </div>
    </div>
  );
}



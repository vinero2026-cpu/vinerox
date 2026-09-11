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
import { BearFaceIcon, BullFaceIcon } from './BullBearIcons';
import { ActiveAbilityAura } from './ActiveAbilityAura';
import { SiegeTower } from './SiegeTower';
import { BattleTutorial } from './BattleTutorial';
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
  showTutorial?: boolean;
  onTutorialDone?: () => void;
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

export function MatchView({ match, stake, loadout, characterLevels, playerName, playerFlag, playerCountryCode, playerAvatar, bonusBoosts, socket, showTutorial, onTutorialDone, onSentiment, onFinish }: Props) {
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
  /** "Visual assistance layer" toggle — the eye icon on the price badge.
   * Purely additive: overlays plain-language Hebrew captions next to the
   * chart elements they describe, never changes any game math. */
  const [assistOn, setAssistOn] = useState(false);
  const [newsEvent, setNewsEvent] = useState(false);
  /** "Tower Siege" battle visualization: each side's tower shrinks/cracks as
   * its HP drops. Correct calls fire a projectile at the rival's tower;
   * misses fire one back at yours. Either tower hitting 0 ends the match
   * immediately (a KO), independent of the pnl-based time-out outcome. */
  const [myTowerHp, setMyTowerHp] = useState(100);
  const [oppTowerHp, setOppTowerHp] = useState(100);
  const [myHitKey, setMyHitKey] = useState<number | null>(null);
  const [oppHitKey, setOppHitKey] = useState<number | null>(null);
  const [projectiles, setProjectiles] = useState<{ id: number; from: 'me' | 'opp' }[]>([]);

  const botStateRef = useRef<BotState>({ pnl: 0 });
  const tickIndexRef = useRef(0);
  const finishedRef = useRef(false);
  const myPnlRef = useRef(0);
  const oppPnlRef = useRef(0);
  const myTowerHpRef = useRef(100);
  const oppTowerHpRef = useRef(100);
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

  // "Breaking news" gamification event — a periodic cosmetic banner only,
  // never touches chance/pnl math (an honest visual flavor beat, not a
  // hidden difficulty spike).
  useEffect(() => {
    let showTimer: ReturnType<typeof setTimeout>;
    const schedule = () => {
      const delay = 14000 + Math.random() * 16000;
      return setTimeout(() => {
        if (finishedRef.current) return;
        setNewsEvent(true);
        sound.layerToggle(false);
        showTimer = setTimeout(() => setNewsEvent(false), 4200);
        loop = schedule();
      }, delay);
    };
    let loop = schedule();
    return () => {
      clearTimeout(loop);
      clearTimeout(showTimer);
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

  const finish = (finalMine: number, finalOpp: number, forcedOutcome?: MatchOutcome) => {
    if (finishedRef.current) return;
    finishedRef.current = true;
    setFinished(true);
    const outcome: MatchOutcome = forcedOutcome ?? (finalMine > finalOpp ? 'win' : finalMine < finalOpp ? 'loss' : 'draw');
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
      sound.successBoom();
      sound.coin();
      sound.roar(1.1);
      if (nextStreak > 0 && nextStreak % 3 === 0) sound.comboHype(nextStreak);
      const rect = chartRef.current?.getBoundingClientRect();
      const x = rect ? rect.left + rect.width / 2 : window.innerWidth / 2;
      const y = rect ? rect.top + rect.height / 2 : window.innerHeight * 0.5;
      const burstId = Date.now();
      setBursts((b) => [...b, { id: burstId, x, y }]);
      setTimeout(() => setBursts((b) => b.filter((burst) => burst.id !== burstId)), 1200);
      if (magnitude > 0.65) setShakeKey((k) => k + 1);

      // Tower Siege: a correct call fires a projectile at the rival's tower.
      const dmg = Math.min(22, Math.abs(magnitude) * 22);
      const nextOppHp = Math.max(0, oppTowerHpRef.current - dmg);
      oppTowerHpRef.current = nextOppHp;
      setOppTowerHp(nextOppHp);
      const projId = Date.now();
      setProjectiles((p) => [...p, { id: projId, from: 'me' }]);
      setTimeout(() => {
        setProjectiles((p) => p.filter((pr) => pr.id !== projId));
        setOppHitKey(projId);
        if (nextOppHp <= 0) finish(myPnlRef.current, oppPnlRef.current, 'win');
      }, 420);
    } else {
      sound.failBuzzer();
      sound.roar(0.6);

      // Tower Siege: an ordinary miss (not the big reload penalty, which
      // already carries its own heavy consequence) takes a bite out of yours.
      if (!penaltyTriggered) {
        const dmg = 6;
        const nextMyHp = Math.max(0, myTowerHpRef.current - dmg);
        myTowerHpRef.current = nextMyHp;
        setMyTowerHp(nextMyHp);
        const projId = Date.now() + 1;
        setProjectiles((p) => [...p, { id: projId, from: 'opp' }]);
        setTimeout(() => {
          setProjectiles((p) => p.filter((pr) => pr.id !== projId));
          setMyHitKey(projId);
          if (nextMyHp <= 0) finish(myPnlRef.current, oppPnlRef.current, 'loss');
        }, 420);
      }
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
  // Overall asset price trend (not the player's pnl) — drives the ambient
  // trend arrow and the "מגמת עלייה/ירידה" assist-layer caption.
  const trendWindow = history.slice(-8);
  const trendUp = trendWindow.length < 2 || (trendWindow[trendWindow.length - 1]!.price >= trendWindow[0]!.price);
  const trendColor = trendUp ? '#28e07f' : '#ff4d5e';

  return (
    <div
      className="relative h-dvh w-full overflow-hidden"
      style={{ background: `radial-gradient(circle at 50% 0%, ${accent}14, transparent 60%)` }}
    >
      {/* FULL-SCREEN CHART — the graph is the entire backdrop, everything else floats over it.
          Kept translucent (not a flat opaque panel) so the app-wide AmbientBackground's
          particles/orbs read through here too, plus a layered vignette + soft "arena pit"
          glow of its own for extra depth on this screen specifically. */}
      <motion.div
        ref={chartRef}
        key={shakeKey}
        animate={shakeKey ? { x: [0, -6, 6, -4, 4, 0] } : {}}
        transition={{ duration: 0.4 }}
        className="absolute inset-0 bg-gradient-to-b from-surface/45 via-bgAlt/30 to-bgAlt/55"
      >
        <div
          className="pointer-events-none absolute inset-0"
          style={{
            background: `radial-gradient(circle at 50% 46%, ${accent}1a, transparent 55%), radial-gradient(ellipse at 50% 100%, #05070cd9 5%, transparent 55%), radial-gradient(ellipse at 50% 50%, transparent 40%, #05070ca8 100%)`,
          }}
        />
        <TradingChart history={history} layers={activeLayers} leading={leading} topInset={chartInsets.top} bottomInset={chartInsets.bottom} />
        <ActiveAbilityAura activeLayers={activeLayers} characterLevels={characterLevels} />

        {/* Ambient trend arrow — small and low-opacity so it reads as a subtle
            cue in the open chart space, not a shape competing with the price line. */}
        <motion.div
          key={trendUp ? 'up' : 'down'}
          initial={{ opacity: 0 }}
          animate={{ opacity: [0.08, 0.16, 0.08], y: trendUp ? [0, -6, 0] : [0, 6, 0] }}
          transition={{ duration: 2.6, repeat: Infinity, ease: 'easeInOut' }}
          className="pointer-events-none absolute inset-x-0 z-10 flex justify-center"
          style={{ top: '30%' }}
        >
          <span
            className="text-[4.5rem] leading-none"
            style={{ color: trendColor, filter: `drop-shadow(0 0 24px ${trendColor})`, transform: trendUp ? 'none' : 'rotate(180deg)' }}
          >
            ▲
          </span>
        </motion.div>

        {/* Assist layer — toggled by the eye icon on the price badge; adds
            Hebrew captions next to the elements they explain. Hidden by default. */}
        <AnimatePresence>
          {assistOn && (
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="pointer-events-none absolute inset-0 z-10">
              <div
                className="absolute left-1/2 top-[38%] -translate-x-1/2 rounded-full border px-3 py-1 font-display text-xs font-black backdrop-blur-sm"
                style={{ borderColor: `${trendColor}aa`, color: trendColor, backgroundColor: '#05070ce6' }}
                dir="rtl"
              >
                {trendUp ? 'מגמת עלייה ⬆' : 'מגמת ירידה ⬇'}
              </div>
              {activeLayers.includes('bollinger') && (
                <div
                  className="absolute right-3 rounded-full border border-teal/70 bg-[#05070ce6] px-2.5 py-1 font-display text-[11px] font-black text-teal backdrop-blur-sm"
                  style={{ top: chartInsets.top + 10 }}
                  dir="rtl"
                >
                  שוק תנודתי
                </div>
              )}
              {activeLayers.includes('volume') && (
                <div
                  className="absolute bottom-[26%] left-3 rounded-full border border-gold/70 bg-[#05070ce6] px-2.5 py-1 font-display text-[11px] font-black text-gold backdrop-blur-sm"
                  dir="rtl"
                >
                  לחץ קונים
                </div>
              )}
            </motion.div>
          )}
        </AnimatePresence>

        {/* "Breaking news" gamification banner — cosmetic only. Anchored to the
            measured HUD height so it can never overlap the confidence bar. */}
        <AnimatePresence>
          {newsEvent && (
            <motion.div
              initial={{ opacity: 0, y: -20, scale: 0.9 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -20, scale: 0.9 }}
              className="pointer-events-none absolute left-1/2 z-30 -translate-x-1/2 rounded-2xl border border-bear/70 px-4 py-2 text-center font-display text-sm font-black text-bear shadow-[0_0_28px_rgba(255,77,94,.55)] backdrop-blur-sm"
              style={{ backgroundColor: '#1a0a0ce6', top: chartInsets.top + 10 }}
              dir="rtl"
            >
              <motion.span
                animate={{ scale: [1, 1.15, 1] }}
                transition={{ duration: 0.6, repeat: Infinity }}
                className="mr-1 inline-block"
              >
                📢
              </motion.span>
              🚨 ידיעות כזכור! - לחץ מכירה
            </motion.div>
          )}
        </AnimatePresence>

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

        {/* Indicators panel — vertical stack of circular icon buttons with a
            progress ring, replacing the old bottom row of ability buttons. */}
        <div className="absolute right-2 top-1/2 z-20 flex -translate-y-1/2 flex-col gap-3">
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
              ? 1 - (timer!.activeUntil - now) / (stats.durationSec * 1000)
              : isCooling
                ? 1 - (timer!.cooldownUntil - now) / (stats.cooldownSec * 1000)
                : 1;
            const secsLeft = isActive ? Math.ceil((timer!.activeUntil - now) / 1000) : isCooling ? Math.ceil((timer!.cooldownUntil - now) / 1000) : 0;
            const ringDeg = Math.max(0, Math.min(360, pct * 360));
            return (
              <motion.button
                key={id}
                onClick={() => castAbility(id)}
                disabled={finished || isActive || isCooling}
                whileTap={{ scale: 0.92 }}
                className="flex flex-col items-center gap-1 disabled:cursor-not-allowed"
              >
                <div
                  className="relative grid h-12 w-12 place-items-center rounded-full p-[2.5px] transition"
                  style={{
                    background: isCooling
                      ? `conic-gradient(${rarityColor} ${ringDeg}deg, rgba(255,255,255,.1) 0deg)`
                      : `conic-gradient(${rarityColor} 360deg, rgba(255,255,255,.1) 0deg)`,
                    opacity: isCooling ? 0.7 : 1,
                  }}
                >
                  <motion.div
                    animate={isActive ? { boxShadow: [`0 0 6px ${rarityColor}55`, `0 0 16px ${rarityColor}cc`, `0 0 6px ${rarityColor}55`] } : {}}
                    transition={isActive ? { duration: 1.1, repeat: Infinity } : {}}
                    className="grid h-full w-full place-items-center rounded-full text-lg"
                    style={{ background: isActive ? `${rarityColor}33` : '#11161fdd' }}
                  >
                    {char.avatar}
                  </motion.div>
                  {(isActive || isCooling) && (
                    <span
                      className="absolute -bottom-1 rounded-full bg-bg/90 px-1 font-display text-[8px] font-black"
                      style={{ color: rarityColor }}
                    >
                      {secsLeft}s
                    </span>
                  )}
                </div>
                <span className="rounded-full bg-bg/70 px-1.5 py-0.5 font-display text-[8px] font-black leading-none backdrop-blur-sm" style={{ color: rarityColor }} dir="rtl">
                  {char.heLabel}
                </span>
              </motion.button>
            );
          })}
        </div>

        {/* Tower Siege — each side's HQ tower, shrinking/cracking as it takes hits. */}
        <SiegeTower align="left" hpFraction={myTowerHp / 100} accent="#2fe0c8" hitKey={myHitKey} label="You" />
        <SiegeTower align="right" hpFraction={oppTowerHp / 100} accent={match.opponent.tierColor ?? '#ff4d5e'} hitKey={oppHitKey} label="Rival" />
        {projectiles.map((p) => {
          const color = p.from === 'me' ? '#2fe0c8' : (match.opponent.tierColor ?? '#ff4d5e');
          return (
            <motion.div
              key={p.id}
              initial={{ left: p.from === 'me' ? '6%' : '92%', bottom: '22%', opacity: 1 }}
              animate={{ left: p.from === 'me' ? '92%' : '6%', bottom: ['22%', '34%', '20%'] }}
              transition={{ duration: 0.42, ease: 'easeInOut' }}
              className="pointer-events-none absolute z-10 h-1.5 w-7 -translate-x-1/2 rounded-full"
              style={{ background: color, boxShadow: `0 0 10px ${color}` }}
            />
          );
        })}

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
              <div className="flex items-center justify-center gap-1.5">
                <div className="font-display text-sm font-bold text-textDim">
                  $<AnimatedNumber value={lastPrice} format={(v) => v.toFixed(2)} duration={0.35} />
                </div>
                <button
                  type="button"
                  onClick={() => setAssistOn((v) => !v)}
                  aria-pressed={assistOn}
                  aria-label="Toggle visual assistance layer"
                  className="grid h-5 w-5 shrink-0 place-items-center rounded-full border text-[10px] transition"
                  style={{
                    borderColor: assistOn ? '#2fe0c8' : 'rgba(47,224,200,.4)',
                    background: assistOn ? '#2fe0c833' : '#0b0f18cc',
                    boxShadow: assistOn ? '0 0 10px #2fe0c8aa' : 'none',
                  }}
                >
                  👁
                </button>
              </div>
            </motion.div>
          </div>

          <div className="text-right">
            <div
              className="font-display text-2xl font-black tabular-nums tracking-widest"
              style={{
                color: secondsLeft < 15 ? '#ff4d5e' : '#f5a623',
                textShadow: `0 0 14px ${secondsLeft < 15 ? '#ff4d5eaa' : '#f5a623aa'}`,
              }}
            >
              {time}
            </div>
          </div>
        </header>

        <div className="relative mt-3 flex items-center justify-between gap-2">
          <PlayerHud
            name={playerName}
            flag={playerFlag}
            countryCode={playerCountryCode}
            avatar={playerAvatar}
            pnl={myPnl}
            leading={leading}
            mood={myTowerHp <= 30 ? 'panic' : streak >= 3 ? 'cheer' : 'neutral'}
          />
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
            mood={oppTowerHp <= 30 ? 'panic' : !leading && oppPnl - myPnl > 1.2 ? 'cheer' : 'neutral'}
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
        <div className="grid grid-cols-2 gap-1.5">
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
          <div
            className="relative overflow-hidden rounded-2xl border-2 p-[3px]"
            style={{ borderColor: '#3a4356', background: 'linear-gradient(160deg,#4a5468,#11161f 55%,#05070c)' }}
          >
            <button
              onClick={() => call(false)}
              disabled={cooling || finished}
              className="flex w-full items-center justify-center gap-2 rounded-xl bg-bear py-5 font-display text-xl font-black uppercase text-white shadow-[0_0_28px_rgba(255,77,94,.6)] transition disabled:opacity-40"
            >
              {isPenalty && cooling ? (
                <>
                  <motion.span animate={{ rotate: 360 }} transition={{ duration: 0.9, repeat: Infinity, ease: 'linear' }}>
                    ⟳
                  </motion.span>
                  Reloading
                </>
              ) : (
                <>
                  <BearFaceIcon size={26} />
                  DOWN
                </>
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
          <div
            className="relative overflow-hidden rounded-2xl border-2 p-[3px]"
            style={{ borderColor: '#3a4356', background: 'linear-gradient(160deg,#4a5468,#11161f 55%,#05070c)' }}
          >
            <button
              onClick={() => call(true)}
              disabled={cooling || finished}
              className="flex w-full items-center justify-center gap-2 rounded-xl bg-bull py-5 font-display text-xl font-black uppercase text-white shadow-[0_0_28px_rgba(40,224,127,.6)] transition disabled:opacity-40"
            >
              {isPenalty && cooling ? (
                <>
                  <motion.span animate={{ rotate: 360 }} transition={{ duration: 0.9, repeat: Infinity, ease: 'linear' }}>
                    ⟳
                  </motion.span>
                  Reloading
                </>
              ) : (
                <>
                  <BullFaceIcon size={26} />
                  UP
                </>
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

      {showTutorial && <BattleTutorial onDone={() => onTutorialDone?.()} />}
    </div>
  );
}



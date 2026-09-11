'use client';

import { useEffect, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { useBlitzStore } from '@/lib/store';
import { sound } from '@/lib/sound';
import { newChest, rollChestReward, settleMatch } from '@/lib/economy';
import { BOT_FALLBACK_SECONDS, type ChestDef, type LayerId, type MatchOutcome, type MatchStartResponse } from '@/lib/types';
import { botDifficultyForTrophies, botTierForTrophies } from '@/lib/botAi';
import { AmbientBackground } from '@/components/AmbientBackground';
import { OnboardingView } from '@/components/OnboardingView';
import { LobbyView } from '@/components/LobbyView';
import { LoadoutView } from '@/components/LoadoutView';
import { PrizePotView } from '@/components/PrizePotView';
import { QueueView } from '@/components/QueueView';
import { MatchIntroView } from '@/components/MatchIntroView';
import { MatchView } from '@/components/MatchView';
import { ResultOverlay } from '@/components/ResultOverlay';
import { BottomNav, type NavStage } from '@/components/BottomNav';
import { ShopView } from '@/components/ShopView';
import { RankView } from '@/components/RankView';
import { LeagueView } from '@/components/LeagueView';
import { MasterView } from '@/components/MasterView';

type Stage = 'onboarding' | 'lobby' | 'loadout' | 'pot' | 'queue' | 'intro' | 'match' | 'result' | 'shop' | 'rank' | 'league' | 'master';

const HUB_STAGES: Stage[] = ['lobby', 'shop', 'rank', 'league', 'master'];

const WS_URL = process.env.NEXT_PUBLIC_BLITZ_WS_URL ?? 'ws://localhost:4001';
const ASSETS = ['NVDA', 'TSLA', 'AAPL', 'AMD', 'META', 'MSFT', 'AMZN'];

function localBotMatch(trophies: number): MatchStartResponse {
  const tier = botTierForTrophies(trophies);
  return {
    matchId: `local_${Date.now()}`,
    seed: Math.floor(Math.random() * 2 ** 31),
    asset: ASSETS[Math.floor(Math.random() * ASSETS.length)]!,
    opponent: { id: 'bot', name: tier.name, flag: tier.avatar, isBot: true, botDifficulty: botDifficultyForTrophies(trophies), tierColor: tier.color, banner: tier.banner },
    durationSeconds: 120,
  };
}

export default function Page() {
  const {
    profile,
    wallet,
    loadout,
    unlockedLayers,
    characterLevels,
    characterShards,
    unlockedBanners,
    equippedBanner,
    chests,
    claimedMilestones,
    claimedPremiumMilestones,
    lastDailyClaim,
    dailyStreak,
    hydrated,
    setProfile,
    updateProfile,
    setLoadout,
    unlockLayer,
    upgradeCharacter,
    equipBanner,
    applyMatchResult,
    addChest,
    openChest,
    claimMilestone,
    claimDaily,
    consumeBonusBoosts,
    seenBlitzTutorial,
    markTutorialSeen,
    setHydrated,
  } =
    useBlitzStore();

  const [stage, setStage] = useState<Stage>('onboarding');
  const [muted, setMuted] = useState(false);
  const [pendingStake, setPendingStake] = useState(10);
  const [pendingLoadout, setPendingLoadout] = useState<LayerId[]>([]);
  const [queueSeconds, setQueueSeconds] = useState(BOT_FALLBACK_SECONDS);
  const [activeMatch, setActiveMatch] = useState<MatchStartResponse | null>(null);
  const [result, setResult] = useState<{ outcome: MatchOutcome; coinDelta: number; trophyDelta: number; gotChest: boolean } | null>(null);
  const [sentiment, setSentiment] = useState(0);
  const [matchBonusBoosts, setMatchBonusBoosts] = useState({ overdrive: 0, shield: 0 });

  const socketRef = useRef<WebSocket | null>(null);
  const queueTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Not persisted by zustand's storage race — wait for rehydration before routing.
  useEffect(() => {
    if (!hydrated) return;
    setStage(profile ? 'lobby' : 'onboarding');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hydrated]);

  useEffect(() => {
    if (!hydrated) setHydrated();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleOnboardingComplete = async (data: { name: string; avatar: string; avatarImage?: string; flag: string; countryCode: string }) => {
    const id = crypto.randomUUID();
    setProfile({ id, name: data.name, avatar: data.avatar, avatarImage: data.avatarImage, flag: data.flag, countryCode: data.countryCode, createdAt: Date.now() });
    setStage('lobby');
    try {
      await fetch('/blitz/api/profile', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id, ...data }) });
    } catch {
      /* offline is fine — wallet state lives client-side too */
    }
  };

  const handleSaveProfile = async (patch: { name: string; avatar: string; avatarImage?: string; flag: string; countryCode: string }) => {
    updateProfile(patch);
    if (!profile) return;
    try {
      await fetch('/blitz/api/profile', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: profile.id, ...patch }) });
    } catch {
      /* offline is fine — profile lives client-side too */
    }
  };

  const toggleMute = () => {
    setMuted((m) => {
      sound.setMuted(!m);
      return !m;
    });
  };

  const handleOpenChest = (chest: ChestDef) => {
    const reward = rollChestReward(chest.kind, unlockedLayers);
    sound.coin();
    openChest(chest.id, reward.coins, reward.layer, reward.banner, reward.shardCharacter, reward.shardAmount);
  };

  const handleClaimDaily = () => {
    const reward = claimDaily();
    if (reward) sound.coin();
    return reward;
  };

  const confirmLoadout = (nextLoadout: LayerId[], stake: number) => {
    setLoadout(nextLoadout);
    setPendingLoadout(nextLoadout);
    setPendingStake(stake);
    setStage('pot');
  };

  const beginQueue = () => {
    const stake = pendingStake;
    setStage('queue');
    setQueueSeconds(BOT_FALLBACK_SECONDS);

    let settled = false;
    const toBot = () => {
      if (settled) return;
      settled = true;
      socketRef.current?.close();
      setActiveMatch(localBotMatch(wallet.trophies));
      setStage('intro');
    };

    try {
      const ws = new WebSocket(WS_URL);
      socketRef.current = ws;
      ws.onopen = () => ws.send(JSON.stringify({ type: 'queue', profileId: profile?.id, name: profile?.name, flag: profile?.flag, stake }));
      ws.onmessage = (event) => {
        const msg = JSON.parse(event.data);
        if (msg.type === 'matched' && !settled) {
          settled = true;
          setActiveMatch({
            matchId: msg.matchId,
            seed: msg.seed,
            asset: msg.asset,
            opponent: msg.opponent,
            durationSeconds: 120,
          });
          setStage('intro');
        }
        if (msg.type === 'timeout') toBot();
      };
      ws.onerror = () => toBot();
      ws.onclose = () => {
        if (!settled) toBot();
      };
    } catch {
      toBot();
    }

    queueTimerRef.current = setInterval(() => {
      setQueueSeconds((s) => {
        if (s <= 1) {
          clearInterval(queueTimerRef.current!);
          toBot();
          return 0;
        }
        return s - 1;
      });
    }, 1000);
  };

  const cancelQueue = () => {
    socketRef.current?.close();
    if (queueTimerRef.current) clearInterval(queueTimerRef.current);
    setStage('loadout');
  };

  const handleFinish = async (outcome: MatchOutcome, myPnl: number, opponentPnl: number) => {
    const { trophyDelta, coinDelta } = settleMatch(wallet, outcome, pendingStake);
    applyMatchResult({ coins: coinDelta, trophies: trophyDelta }, outcome);
    let gotChest = false;
    if (outcome === 'win') {
      addChest(newChest('win'));
      gotChest = true;
    }
    setResult({ outcome, coinDelta, trophyDelta, gotChest });
    setStage('result');

    if (profile) {
      try {
        await fetch('/blitz/api/match/result', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ matchId: activeMatch?.matchId, profileId: profile.id, outcome, myPnl, opponentPnl, stake: pendingStake }),
        });
      } catch {
        /* server bookkeeping is best-effort; the client wallet already settled */
      }
    }
  };

  if (!hydrated)
    return (
      <div className="grid min-h-dvh place-items-center bg-bg">
        <div className="flex flex-col items-center gap-3">
          <motion.div
            animate={{ rotate: 360 }}
            transition={{ duration: 1.1, repeat: Infinity, ease: 'linear' }}
            className="grid h-12 w-12 place-items-center rounded-full border-2 border-gold/25 border-t-gold"
          />
          <span className="font-display text-sm font-bold uppercase tracking-widest text-textFaint">Loading Blitz Arena…</span>
        </div>
      </div>
    );

  return (
    <div className="relative min-h-dvh">
      <AmbientBackground sentiment={sentiment} />
      <div className="relative z-10">
        <AnimatePresence mode="wait">
          <motion.div
            key={stage}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.22, ease: 'easeOut' }}
          >
        {stage === 'onboarding' && <OnboardingView onComplete={handleOnboardingComplete} />}

        {stage === 'lobby' && profile && (
          <LobbyView
            profile={profile}
            wallet={wallet}
            chests={chests}
            claimedMilestones={claimedMilestones}
            claimedPremiumMilestones={claimedPremiumMilestones}
            onClaimMilestone={claimMilestone}
            lastDailyClaim={lastDailyClaim}
            dailyStreak={dailyStreak}
            onClaimDaily={handleClaimDaily}
            onOpenChest={handleOpenChest}
            onSaveProfile={handleSaveProfile}
            muted={muted}
            onToggleMute={toggleMute}
          />
        )}

        {stage === 'shop' && (
          <ShopView
            wallet={wallet}
            unlockedLayers={unlockedLayers}
            characterLevels={characterLevels}
            characterShards={characterShards}
            onUpgradeCharacter={upgradeCharacter}
            unlockedBanners={unlockedBanners}
            equippedBanner={equippedBanner}
            onEquipBanner={equipBanner}
          />
        )}

        {stage === 'rank' && profile && <RankView profile={profile} wallet={wallet} />}

        {stage === 'league' && <LeagueView />}

        {stage === 'master' && <MasterView />}

        {stage === 'loadout' && (
          <LoadoutView
            coins={wallet.coins}
            unlockedLayers={unlockedLayers}
            characterLevels={characterLevels}
            characterShards={characterShards}
            onUpgradeCharacter={upgradeCharacter}
            initialLoadout={loadout}
            onUnlock={(layer, cost) => {
              if (wallet.coins < cost) return;
              applyMatchResult({ coins: -cost, trophies: 0 }, 'draw');
              unlockLayer(layer);
            }}
            onConfirm={confirmLoadout}
            onBack={() => setStage('lobby')}
          />
        )}

        {stage === 'pot' && (
          <PrizePotView stake={pendingStake} onConfirm={beginQueue} onBack={() => setStage('loadout')} />
        )}

        {stage === 'queue' && <QueueView secondsLeft={queueSeconds} onCancel={cancelQueue} />}

        {stage === 'intro' && activeMatch && profile && (
          <MatchIntroView
            asset={activeMatch.asset}
            stake={pendingStake}
            me={{ name: profile.name, avatar: profile.avatar, avatarImage: profile.avatarImage, countryCode: profile.countryCode, trophies: wallet.trophies, banner: equippedBanner }}
            opponent={{
              name: activeMatch.opponent.name,
              avatar: activeMatch.opponent.isBot ? activeMatch.opponent.flag : '🎮',
              trophies: wallet.trophies,
              banner: activeMatch.opponent.banner,
              tag: activeMatch.opponent.isBot ? { label: activeMatch.opponent.name, color: activeMatch.opponent.tierColor ?? '#9aa5b8' } : undefined,
            }}
            onDone={() => {
              setMatchBonusBoosts(consumeBonusBoosts());
              setStage('match');
            }}
          />
        )}

        {stage === 'match' && activeMatch && profile && (
          <MatchView
            match={activeMatch}
            stake={pendingStake}
            loadout={pendingLoadout}
            characterLevels={characterLevels}
            playerName={profile.name}
            playerFlag={profile.flag}
            playerCountryCode={profile.countryCode}
            playerAvatar={profile.avatar}
            bonusBoosts={matchBonusBoosts}
            socket={socketRef.current}
            showTutorial={!seenBlitzTutorial}
            onTutorialDone={markTutorialSeen}
            onSentiment={setSentiment}
            onFinish={handleFinish}
          />
        )}

        {stage === 'result' && result && (
          <ResultOverlay
            outcome={result.outcome}
            coinDelta={result.coinDelta}
            trophyDelta={result.trophyDelta}
            gotChest={result.gotChest}
            onContinue={() => {
              setActiveMatch(null);
              setResult(null);
              setSentiment(0);
              setStage('lobby');
            }}
          />
        )}
          </motion.div>
        </AnimatePresence>
      </div>

      <AnimatePresence>
        {HUB_STAGES.includes(stage) && (
          <motion.div
            key="bottom-nav"
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 24 }}
            transition={{ duration: 0.2, ease: 'easeOut' }}
          >
            <BottomNav
              active={stage as NavStage}
              onNavigate={(next) => setStage(next)}
              onCompete={() => {
                setSentiment(0);
                setStage('loadout');
              }}
            />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

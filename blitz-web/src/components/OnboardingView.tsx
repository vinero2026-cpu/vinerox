'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { AVATARS, FLAGS, avatarAccent } from '@/lib/identity';
import { FlagIcon } from './FlagIcon';

export function OnboardingView({ onComplete }: { onComplete: (data: { name: string; avatar: string; flag: string; countryCode: string }) => void }) {
  const [name, setName] = useState('');
  const [avatar, setAvatar] = useState(AVATARS[0]!);
  const [flagIdx, setFlagIdx] = useState(0);

  const canContinue = name.trim().length >= 2;

  return (
    <div className="mx-auto flex min-h-dvh max-w-lg flex-col justify-center px-6 py-10">
      <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="text-center">
        <div className="font-display text-4xl font-black tracking-wide text-gold">VINEROX</div>
        <div className="mt-1 text-sm font-bold uppercase tracking-[0.3em] text-teal">Blitz Arena</div>
      </motion.div>

      <div className="mt-10 rounded-3xl border border-stroke bg-surface/60 p-6 backdrop-blur-md">
        <label className="mb-2 block text-xs font-bold uppercase tracking-wider text-textDim">Manager name</label>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          maxLength={18}
          placeholder="Enter your call sign"
          className="w-full rounded-xl border border-stroke bg-bgAlt px-4 py-3 text-lg font-bold outline-none focus:border-gold"
        />

        <div className="mt-6">
          <div className="mb-2 text-xs font-bold uppercase tracking-wider text-textDim">Choose your avatar</div>
          <div className="grid grid-cols-4 gap-3">
            {AVATARS.map((a) => {
              const [c1, c2] = avatarAccent(a);
              const selected = avatar === a;
              return (
                <motion.button
                  key={a}
                  whileHover={{ scale: 1.06, y: -2 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => setAvatar(a)}
                  className="grid aspect-square place-items-center rounded-2xl border text-3xl transition"
                  style={{
                    borderColor: selected ? c1 : '#232b3a',
                    background: `radial-gradient(circle at 35% 30%, ${c1}${selected ? '55' : '2e'}, ${c2}${selected ? 'e0' : '80'})`,
                    boxShadow: selected ? `0 0 20px ${c1}66` : 'none',
                  }}
                >
                  {a}
                </motion.button>
              );
            })}
          </div>
        </div>

        <div className="mt-6">
          <div className="mb-2 text-xs font-bold uppercase tracking-wider text-textDim">Country flag</div>
          <div className="grid max-h-48 grid-cols-6 gap-2 overflow-y-auto pr-1">
            {FLAGS.map(([, code], i) => (
              <button
                key={code}
                onClick={() => setFlagIdx(i)}
                title={code}
                className={`grid aspect-square place-items-center rounded-xl border p-1.5 transition ${
                  flagIdx === i ? 'border-teal bg-teal/15' : 'border-stroke bg-bgAlt'
                }`}
              >
                <FlagIcon code={code} className="h-full w-full" />
              </button>
            ))}
          </div>
        </div>

        <button
          disabled={!canContinue}
          onClick={() => onComplete({ name: name.trim(), avatar, flag: FLAGS[flagIdx]![0], countryCode: FLAGS[flagIdx]![1] })}
          className="mt-8 w-full rounded-xl bg-gold py-3 text-base font-black uppercase tracking-wide text-black transition disabled:opacity-40"
        >
          Enter the arena
        </button>
      </div>
    </div>
  );
}

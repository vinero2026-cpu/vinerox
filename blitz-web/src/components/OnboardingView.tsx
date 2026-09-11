'use client';

import { useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { CARICATURES, FLAGS, avatarAccent } from '@/lib/identity';
import { AvatarGlyph } from './AvatarGlyph';
import { CaricatureAvatar } from './CaricatureAvatar';
import { FlagIcon } from './FlagIcon';

export function OnboardingView({
  onComplete,
}: {
  onComplete: (data: { name: string; avatar: string; avatarImage?: string; flag: string; countryCode: string }) => void;
}) {
  const [name, setName] = useState('');
  const [avatar, setAvatar] = useState(CARICATURES[0]!.id);
  const [avatarImage, setAvatarImage] = useState<string | undefined>(undefined);
  const [flagIdx, setFlagIdx] = useState(0);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const canContinue = name.trim().length >= 2;

  const handlePhoto = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => setAvatarImage(typeof reader.result === 'string' ? reader.result : undefined);
    reader.readAsDataURL(file);
  };

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
          <div className="mb-2 text-xs font-bold uppercase tracking-wider text-textDim">Profile photo</div>
          <div className="flex items-center gap-3">
            <div className="grid h-16 w-16 shrink-0 place-items-center overflow-hidden rounded-full border border-stroke bg-bgAlt text-3xl">
              {avatarImage ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={avatarImage} alt="Profile" className="h-full w-full object-cover" />
              ) : (
                <AvatarGlyph avatar={avatar} className="h-full w-full" />
              )}
            </div>
            <div className="flex flex-1 flex-col gap-1.5">
              <input ref={fileInputRef} type="file" accept="image/*" capture="user" onChange={handlePhoto} className="hidden" />
              <button
                onClick={() => fileInputRef.current?.click()}
                className="rounded-lg border border-gold/60 py-1.5 text-xs font-black uppercase text-gold transition hover:bg-gold/10"
              >
                📷 Take / upload photo
              </button>
              {avatarImage && (
                <button onClick={() => setAvatarImage(undefined)} className="rounded-lg border border-stroke py-1.5 text-xs font-bold text-textFaint">
                  Remove photo
                </button>
              )}
            </div>
          </div>
        </div>

        <div className="mt-6">
          <div className="mb-2 text-xs font-bold uppercase tracking-wider text-textDim">
            {avatarImage ? 'Or pick an avatar instead' : 'No photo? Choose your avatar'}
          </div>
          <div className="grid grid-cols-4 gap-3">
            {CARICATURES.map((c) => {
              const [c1, c2] = avatarAccent(c.id);
              const selected = !avatarImage && avatar === c.id;
              return (
                <motion.button
                  key={c.id}
                  whileHover={{ scale: 1.06, y: -2 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => {
                    setAvatar(c.id);
                    setAvatarImage(undefined);
                  }}
                  title={c.name}
                  className="grid aspect-square place-items-center rounded-2xl border p-1.5 transition"
                  style={{
                    borderColor: selected ? c1 : '#232b3a',
                    background: `radial-gradient(circle at 35% 30%, ${c1}${selected ? '55' : '2e'}, ${c2}${selected ? 'e0' : '80'})`,
                    boxShadow: selected ? `0 0 20px ${c1}66` : 'none',
                  }}
                >
                  <CaricatureAvatar id={c.id} className="h-full w-full" />
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
          onClick={() => onComplete({ name: name.trim(), avatar, avatarImage, flag: FLAGS[flagIdx]![0], countryCode: FLAGS[flagIdx]![1] })}
          className="mt-8 w-full rounded-xl bg-gold py-3 text-base font-black uppercase tracking-wide text-black transition disabled:opacity-40"
        >
          Enter the arena
        </button>
      </div>
    </div>
  );
}

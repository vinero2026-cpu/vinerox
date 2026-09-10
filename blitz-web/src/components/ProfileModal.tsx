'use client';

import { useRef, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { AVATARS, FLAGS, avatarAccent } from '@/lib/identity';
import { FlagIcon } from './FlagIcon';

interface Props {
  name: string;
  avatar: string;
  avatarImage?: string;
  flag: string;
  onSave: (patch: { name: string; avatar: string; avatarImage?: string; flag: string; countryCode: string }) => void;
  onClose: () => void;
}

/** Opens from tapping the player's banner card in the lobby — lets them
 * rename, upload/capture a photo (or pick an emoji avatar), and change
 * their country flag from the full country list. */
export function ProfileModal({ name, avatar, avatarImage, flag, onSave, onClose }: Props) {
  const [draftName, setDraftName] = useState(name);
  const [draftAvatar, setDraftAvatar] = useState(avatar);
  const [draftImage, setDraftImage] = useState<string | undefined>(avatarImage);
  const [flagIdx, setFlagIdx] = useState(() => Math.max(0, FLAGS.findIndex(([f]) => f === flag)));
  const [flagQuery, setFlagQuery] = useState('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const filteredFlags = FLAGS.filter(([, code]) => code.toLowerCase().includes(flagQuery.toLowerCase()));

  const handlePhoto = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => setDraftImage(typeof reader.result === 'string' ? reader.result : undefined);
    reader.readAsDataURL(file);
  };

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-50 grid place-items-center bg-black/70 px-6"
        onClick={onClose}
      >
        <motion.div
          initial={{ scale: 0.92, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.92, opacity: 0 }}
          onClick={(e) => e.stopPropagation()}
          className="max-h-[85vh] w-full max-w-sm overflow-y-auto rounded-3xl border border-stroke bg-surface/85 p-6 backdrop-blur-xl"
        >
          <h2 className="font-display text-xl font-black">Edit profile</h2>

          <label className="mt-4 block text-xs font-bold uppercase tracking-wider text-textDim">Manager name</label>
          <input
            value={draftName}
            onChange={(e) => setDraftName(e.target.value)}
            maxLength={18}
            className="mt-1 w-full rounded-xl border border-stroke bg-bgAlt px-4 py-2.5 text-base font-bold outline-none focus:border-gold"
          />

          <div className="mt-4 text-xs font-bold uppercase tracking-wider text-textDim">Profile photo</div>
          <div className="mt-2 flex items-center gap-3">
            <div className="grid h-16 w-16 shrink-0 place-items-center overflow-hidden rounded-full border border-stroke bg-bgAlt text-3xl">
              {draftImage ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={draftImage} alt="Profile" className="h-full w-full object-cover" />
              ) : (
                draftAvatar
              )}
            </div>
            <div className="flex flex-1 flex-col gap-1.5">
              <input ref={fileInputRef} type="file" accept="image/*" onChange={handlePhoto} className="hidden" />
              <button
                onClick={() => fileInputRef.current?.click()}
                className="rounded-lg border border-gold/60 py-1.5 text-xs font-black uppercase text-gold transition hover:bg-gold/10"
              >
                📷 Take / upload photo
              </button>
              {draftImage && (
                <button onClick={() => setDraftImage(undefined)} className="rounded-lg border border-stroke py-1.5 text-xs font-bold text-textFaint">
                  Remove photo
                </button>
              )}
            </div>
          </div>

          <div className="mt-4 text-xs font-bold uppercase tracking-wider text-textDim">Or pick an avatar</div>
          <div className="mt-2 grid grid-cols-6 gap-2">
            {AVATARS.map((av) => {
              const [c1, c2] = avatarAccent(av);
              const selected = !draftImage && draftAvatar === av;
              return (
                <motion.button
                  key={av}
                  whileHover={{ scale: 1.08, y: -2 }}
                  whileTap={{ scale: 0.94 }}
                  onClick={() => {
                    setDraftAvatar(av);
                    setDraftImage(undefined);
                  }}
                  className="grid aspect-square place-items-center rounded-xl border text-xl transition"
                  style={{
                    borderColor: selected ? c1 : '#232b3a',
                    background: `radial-gradient(circle at 35% 30%, ${c1}${selected ? '55' : '2e'}, ${c2}${selected ? 'e0' : '80'})`,
                    boxShadow: selected ? `0 0 16px ${c1}66` : 'none',
                  }}
                >
                  {av}
                </motion.button>
              );
            })}
          </div>

          <div className="mt-4 text-xs font-bold uppercase tracking-wider text-textDim">Country flag</div>
          <input
            value={flagQuery}
            onChange={(e) => setFlagQuery(e.target.value)}
            placeholder="Search country code…"
            className="mt-1 w-full rounded-lg border border-stroke bg-bgAlt px-3 py-1.5 text-xs outline-none focus:border-teal"
          />
          <div className="mt-2 grid max-h-40 grid-cols-6 gap-2 overflow-y-auto pr-1">
            {filteredFlags.map(([, code]) => {
              const i = FLAGS.findIndex(([, c]) => c === code);
              return (
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
              );
            })}
          </div>

          <div className="mt-6 flex gap-3">
            <button onClick={onClose} className="flex-1 rounded-xl border border-stroke py-2.5 text-sm font-bold text-textDim">
              Cancel
            </button>
            <button
              onClick={() =>
                onSave({
                  name: draftName.trim() || name,
                  avatar: draftAvatar,
                  avatarImage: draftImage,
                  flag: FLAGS[flagIdx]![0],
                  countryCode: FLAGS[flagIdx]![1],
                })
              }
              className="flex-1 rounded-xl bg-gradient-to-r from-gold to-goldDeep py-2.5 text-sm font-black uppercase text-black"
            >
              Save
            </button>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}


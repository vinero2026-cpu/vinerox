import { isCaricatureId } from '@/lib/caricatures';
import { CaricatureAvatar } from './CaricatureAvatar';

/** Drop-in replacement for rendering `avatar` anywhere in the app: renders the
 * SVG caricature for 'car_*' ids, falls back to plain emoji text for legacy
 * saved profiles that still hold one of the old AVATARS emoji strings. */
export function AvatarGlyph({ avatar, className }: { avatar: string; className?: string }) {
  if (isCaricatureId(avatar)) return <CaricatureAvatar id={avatar} className={className} />;
  return <span className={className}>{avatar}</span>;
}

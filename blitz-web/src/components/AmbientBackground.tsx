'use client';

import { useEffect, useRef } from 'react';

/**
 * Canvas backdrop evoking a modern US trading floor: a spaced-out dot-grid
 * perspective floor with atmospheric depth (the grid hazes into fog near the
 * horizon so it reads as far away), glow orbs, and a particle field — all
 * kept at low alpha so it reads as depth behind the UI, never competes with
 * it. (Company badges were removed — they read as visual clutter; see
 * companyBadges.ts for why we don't draw real logos instead.)
 */
export function AmbientBackground({ sentiment }: { sentiment: number }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const sentimentRef = useRef(sentiment);
  sentimentRef.current = sentiment;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let raf = 0;
    let width = (canvas.width = canvas.clientWidth);
    let height = (canvas.height = canvas.clientHeight);
    const onResize = () => {
      width = canvas.width = canvas.clientWidth;
      height = canvas.height = canvas.clientHeight;
    };
    window.addEventListener('resize', onResize);

    const particles = Array.from({ length: 70 }, () => ({
      x: Math.random() * width,
      y: Math.random() * height,
      r: Math.random() * 2 + 0.4,
      speed: Math.random() * 0.25 + 0.05,
      drift: (Math.random() - 0.5) * 0.15,
    }));

    const orbs = Array.from({ length: 4 }, (_, i) => ({
      x: (0.2 + i * 0.22) * width,
      y: height * (0.2 + (i % 2) * 0.4),
      r: 140 + i * 30,
      phase: i * 1.3,
    }));

    // Floating dollar glyphs among the particle field for Wall Street flavor.
    const dollars = Array.from({ length: 10 }, () => ({
      x: Math.random() * width,
      y: Math.random() * height,
      z: 0.3 + Math.random() * 0.7,
      speed: 0.05 + Math.random() * 0.1,
    }));

    const ROWS = 11;
    const HALF_COLS = 5;
    let scrollPhase = 0;

    const paint = (now: number) => {
      const s = sentimentRef.current;
      const bull = Math.max(0, s);
      const bear = Math.max(0, -s);
      ctx.clearRect(0, 0, width, height);

      const grad = ctx.createRadialGradient(width / 2, height * 0.15, 20, width / 2, height * 0.5, height);
      grad.addColorStop(0, `rgba(${40 + bear * 120}, ${40 + bull * 140}, 60, ${0.25 + Math.max(bull, bear) * 0.25})`);
      grad.addColorStop(1, 'rgba(5,7,12,1)');
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, width, height);

      // --- spaced-out dot-grid perspective floor (dots, not thin lines —
      // avoids moiré against the UI's own straight borders) ---
      const horizonY = height * 0.62;
      const vpX = width / 2;
      const colSpan = width / (HALF_COLS * 2);
      const tint = s >= 0 ? '47,224,136' : '255,77,94';

      scrollPhase = (scrollPhase + 0.0026) % 1;

      const yAt = (t: number) => horizonY + t * t * (height - horizonY);
      const xAt = (t: number, col: number) => vpX + t * col * colSpan;

      ctx.save();
      for (let row = -1; row < ROWS; row++) {
        const t = (row + scrollPhase) / ROWS;
        if (t < 0 || t > 1) continue;
        const y = yAt(t);
        // cubic falloff (t*t*t) hazes the grid out near the horizon much more
        // aggressively than a linear/quadratic fade — reads as fog/distance.
        const depthFade = t * t * t;
        const dotAlpha = Math.min(0.55, depthFade * 1.8) * (0.35 + Math.max(bull, bear) * 0.15);
        const dotSize = 0.5 + depthFade * 2.6;
        for (let col = -HALF_COLS; col <= HALF_COLS; col++) {
          ctx.beginPath();
          ctx.arc(xAt(t, col), y, dotSize, 0, Math.PI * 2);
          ctx.fillStyle = `rgba(${tint},${dotAlpha})`;
          ctx.fill();
        }
      }
      ctx.restore();

      // atmospheric haze band just above the horizon — the classic "fog in
      // the distance" depth cue, blending the vanishing point into the scene
      // instead of letting the grid cut off sharply.
      const fog = ctx.createLinearGradient(0, horizonY - height * 0.16, 0, horizonY + height * 0.1);
      fog.addColorStop(0, 'rgba(5,7,12,0)');
      fog.addColorStop(0.7, 'rgba(5,7,12,.35)');
      fog.addColorStop(1, 'rgba(5,7,12,0)');
      ctx.fillStyle = fog;
      ctx.fillRect(0, horizonY - height * 0.16, width, height * 0.26);

      // soft glow right at the horizon line reinforces "far away"
      const horizonGlow = ctx.createRadialGradient(vpX, horizonY, 4, vpX, horizonY, width * 0.42);
      horizonGlow.addColorStop(0, `rgba(${tint},${0.14 + Math.max(bull, bear) * 0.08})`);
      horizonGlow.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = horizonGlow;
      ctx.fillRect(0, 0, width, height);

      // slow-drifting glow orbs add parallax depth behind the particle field
      for (const orb of orbs) {
        const wobble = Math.sin(now / 4000 + orb.phase) * 24;
        const orbGrad = ctx.createRadialGradient(orb.x + wobble, orb.y, 0, orb.x + wobble, orb.y, orb.r);
        orbGrad.addColorStop(0, `rgba(${tint},${0.05 + Math.max(bull, bear) * 0.06})`);
        orbGrad.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = orbGrad;
        ctx.fillRect(0, 0, width, height);
      }

      // floating dollar glyphs
      ctx.save();
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.font = '700 16px var(--font-display, sans-serif)';
      for (const d of dollars) {
        d.y -= d.speed * d.z;
        if (d.y < -20) d.y = height + 20;
        ctx.fillStyle = `rgba(245,195,67,${0.04 + d.z * 0.08})`;
        ctx.fillText('$', d.x, d.y);
      }
      ctx.restore();

      for (const p of particles) {
        p.y -= p.speed + bull * 0.4;
        p.y += bear * 0.25;
        p.x += p.drift;
        if (p.y < -5) p.y = height + 5;
        if (p.y > height + 5) p.y = -5;
        if (p.x < -5) p.x = width + 5;
        if (p.x > width + 5) p.x = -5;
        const color = s >= 0 ? `rgba(47,224,136,${0.35 + bull * 0.5})` : `rgba(255,77,94,${0.35 + bear * 0.5})`;
        ctx.beginPath();
        ctx.fillStyle = color;
        ctx.arc(p.x, p.y, p.r + bull * 1.2, 0, Math.PI * 2);
        ctx.fill();
      }
      raf = requestAnimationFrame(paint);
    };
    raf = requestAnimationFrame(paint);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', onResize);
    };
  }, []);

  return <canvas ref={canvasRef} className="pointer-events-none absolute inset-0 h-full w-full opacity-80" />;
}

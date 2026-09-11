'use client';

import { useEffect, useRef } from 'react';
import type { LayerId } from '@/lib/types';
import type { PriceTick } from '@/lib/match-sim';

interface Props {
  history: PriceTick[];
  layers: LayerId[];
  leading: boolean;
  /** Pixel-space top/bottom safe-zone insets (e.g. the height of HUD bars
   * floating over a full-screen chart) so the plotted line and indicator
   * overlays never render underneath those bars. */
  topInset?: number;
  bottomInset?: number;
}

type Pt = [number, number];

/** Draws a smooth curve through every point using a Catmull-Rom → Bézier
 * conversion so the price path reads as a living line, not a jagged EKG. */
function smoothPath(ctx: CanvasRenderingContext2D, pts: Pt[]) {
  if (pts.length < 2) return;
  ctx.moveTo(pts[0]![0], pts[0]![1]);
  if (pts.length === 2) {
    ctx.lineTo(pts[1]![0], pts[1]![1]);
    return;
  }
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] ?? pts[i]!;
    const p1 = pts[i]!;
    const p2 = pts[i + 1]!;
    const p3 = pts[i + 2] ?? p2;
    const cp1x = p1[0] + (p2[0] - p0[0]) / 6;
    const cp1y = p1[1] + (p2[1] - p0[1]) / 6;
    const cp2x = p2[0] - (p3[0] - p1[0]) / 6;
    const cp2y = p2[1] - (p3[1] - p1[1]) / 6;
    ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2[0], p2[1]);
  }
}

function ema(values: number[], period: number): number[] {
  const k = 2 / (period + 1);
  const out: number[] = [];
  let prev = values[0] ?? 0;
  for (const v of values) {
    prev = v * k + prev * (1 - k);
    out.push(prev);
  }
  return out;
}

/** Canvas chart rendering the live price path plus any active cockpit layers. */
export function TradingChart({ history, layers, leading, topInset, bottomInset }: Props) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const cssW = canvas.clientWidth || 320;
    const cssH = canvas.clientHeight || 240;
    canvas.width = cssW * dpr;
    canvas.height = cssH * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    const width = cssW;
    const height = cssH;
    const padTop = topInset ?? 26;
    const padBottom = bottomInset ?? 46;

    let raf = 0;
    // Redraws every frame (not just on tick) so time-based glows/pulses
    // (volume bars, sentiment sweep) actually animate instead of stepping
    // once per second alongside the underlying price ticks.
    const draw = () => {
      ctx.clearRect(0, 0, width, height);
      if (history.length < 2) {
        raf = requestAnimationFrame(draw);
        return;
      }
    const prices = history.map((h) => h.price);
    const min = Math.min(...prices);
    const max = Math.max(...prices);
    const span = Math.max(0.5, max - min);
    const stepX = width / Math.max(1, history.length - 1);
    const toY = (p: number) => height - padBottom - ((p - min) / span) * (height - padTop - padBottom);
    const accent = leading ? '#28e07f' : '#ff4d5e';

    // background grid + price axis labels
    ctx.strokeStyle = 'rgba(35,43,58,0.55)';
    ctx.lineWidth = 1;
    ctx.font = '10px system-ui';
    ctx.fillStyle = 'rgba(154,165,184,0.55)';
    for (let i = 0; i <= 4; i++) {
      const y = padTop + ((height - padTop - padBottom) / 4) * i;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
      const priceAt = max - (span / 4) * i;
      ctx.fillText(priceAt.toFixed(2), 6, y - 4);
    }

    // heatmap — sentiment-weighted background clouds
    if (layers.includes('heatmap')) {
      history.forEach((h, i) => {
        const x = i * stepX;
        const bull = Math.max(0, h.sentiment);
        const bear = Math.max(0, -h.sentiment);
        ctx.fillStyle = h.sentiment >= 0 ? `rgba(47,224,136,${bull * 0.14})` : `rgba(255,77,94,${bear * 0.14})`;
        ctx.fillRect(x, padTop, stepX + 1, height - padTop - padBottom);
      });
    }

    // fibonacci retracement — dashed levels across the visible swing
    if (layers.includes('fibonacci')) {
      const levels = [0.236, 0.382, 0.5, 0.618, 0.786];
      ctx.save();
      ctx.setLineDash([5, 5]);
      ctx.strokeStyle = 'rgba(245,195,67,0.45)';
      ctx.font = '9px system-ui';
      levels.forEach((lvl) => {
        const y = toY(min + span * lvl);
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();
        ctx.fillStyle = 'rgba(245,195,67,0.75)';
        ctx.fillText(`${(lvl * 100).toFixed(1)}%`, width - 34, y - 3);
      });
      ctx.restore();
    }

    // volume profile — synthetic bars from price delta magnitude, breathing
    // in and out on a slow sine pulse so it reads as "alive", not static
    if (layers.includes('volume')) {
      const pulse = 0.78 + 0.22 * Math.sin(Date.now() / 260);
      history.forEach((h, i) => {
        if (i === 0) return;
        const prev = history[i - 1]!;
        const delta = Math.abs(h.price - prev.price);
        const barH = Math.min((height - padTop - padBottom) * 0.3, delta * 14 + 3) * pulse;
        const grad = ctx.createLinearGradient(0, height - padBottom, 0, height - padBottom - barH);
        grad.addColorStop(0, 'rgba(58,140,255,0.15)');
        grad.addColorStop(1, 'rgba(58,140,255,0.6)');
        ctx.fillStyle = grad;
        ctx.fillRect(i * stepX - 2, height - padBottom - barH, 4, barH);
      });
    }

    // VWAP — running volume-weighted average acting as a fair-value anchor
    if (layers.includes('vwap')) {
      let cumPV = 0;
      let cumV = 0;
      const vwapPts: Pt[] = history.map((h, i) => {
        const vol = i === 0 ? 1 : Math.abs(h.price - history[i - 1]!.price) * 4 + 1;
        cumPV += h.price * vol;
        cumV += vol;
        return [i * stepX, toY(cumPV / cumV)];
      });
      ctx.save();
      ctx.setLineDash([2, 6]);
      ctx.strokeStyle = 'rgba(245,195,67,0.85)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      smoothPath(ctx, vwapPts);
      ctx.stroke();
      ctx.restore();
    }

    // Bollinger bands — rolling volatility channel, neon glow so it reads as
    // an energy tunnel rather than a plain line overlay.
    if (layers.includes('bollinger')) {
      const window = 10;
      const upper: Pt[] = [];
      const lower: Pt[] = [];
      history.forEach((_, i) => {
        const slice = history.slice(Math.max(0, i - window), i + 1).map((h) => h.price);
        const mean = slice.reduce((a, b) => a + b, 0) / slice.length;
        const variance = slice.reduce((a, b) => a + (b - mean) ** 2, 0) / slice.length;
        const sd = Math.sqrt(variance) || 0.4;
        upper.push([i * stepX, toY(mean + sd * 1.6)]);
        lower.push([i * stepX, toY(mean - sd * 1.6)]);
      });
      ctx.save();
      ctx.beginPath();
      smoothPath(ctx, upper);
      for (let i = lower.length - 1; i >= 0; i--) ctx.lineTo(lower[i]![0], lower[i]![1]);
      ctx.closePath();
      ctx.fillStyle = 'rgba(47,224,200,0.08)';
      ctx.fill();
      ctx.shadowColor = '#2fe0c8';
      ctx.shadowBlur = 10;
      ctx.strokeStyle = 'rgba(47,224,200,0.9)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      smoothPath(ctx, upper);
      ctx.stroke();
      ctx.beginPath();
      smoothPath(ctx, lower);
      ctx.stroke();
      ctx.restore();
    }

    // live price line — smooth glowing curve with a soft gradient area fill
    // beneath it (the requested reversion away from a candlestick chart).
    const points: Pt[] = history.map((h, i) => [i * stepX, toY(h.price)]);
    ctx.save();
    const areaGrad = ctx.createLinearGradient(0, padTop, 0, height - padBottom);
    areaGrad.addColorStop(0, `${accent}33`);
    areaGrad.addColorStop(1, `${accent}00`);
    ctx.beginPath();
    smoothPath(ctx, points);
    ctx.lineTo(points[points.length - 1]![0], height - padBottom);
    ctx.lineTo(points[0]![0], height - padBottom);
    ctx.closePath();
    ctx.fillStyle = areaGrad;
    ctx.fill();
    ctx.restore();

    ctx.save();
    ctx.shadowColor = accent;
    ctx.shadowBlur = 14;
    ctx.strokeStyle = accent;
    ctx.lineWidth = 3.5;
    ctx.beginPath();
    smoothPath(ctx, points);
    ctx.stroke();
    ctx.restore();

    const last = history[history.length - 1]!;
    const lastPt = points[points.length - 1]!;

    // sentiment radar — rotating sweep + pulse ring at the last point
    if (layers.includes('sentiment')) {
      const pulse = 12 + Math.abs(last.sentiment) * 30;
      const sweep = (Date.now() / 500) % (Math.PI * 2);
      ctx.save();
      ctx.strokeStyle = last.sentiment >= 0 ? 'rgba(47,224,136,0.55)' : 'rgba(255,77,94,0.55)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(lastPt[0], lastPt[1], pulse, 0, Math.PI * 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(lastPt[0], lastPt[1], pulse * 0.6, sweep, sweep + Math.PI * 0.6);
      ctx.strokeStyle = 'rgba(245,195,67,0.85)';
      ctx.stroke();
      ctx.restore();
    }

    // order flow pressure — pulsing buy/sell bars at the chart edges
    if (layers.includes('orderflow')) {
      const recent = history.slice(-10);
      const bull = recent.filter((h) => h.sentiment >= 0).length / recent.length;
      const bear = 1 - bull;
      const barMax = height - padTop - padBottom;
      ctx.save();
      const leftGrad = ctx.createLinearGradient(0, height - padBottom, 0, height - padBottom - barMax * bull);
      leftGrad.addColorStop(0, 'rgba(40,224,127,0.05)');
      leftGrad.addColorStop(1, 'rgba(40,224,127,0.55)');
      ctx.fillStyle = leftGrad;
      ctx.fillRect(2, height - padBottom - barMax * bull, 6, barMax * bull);
      const rightGrad = ctx.createLinearGradient(0, height - padBottom, 0, height - padBottom - barMax * bear);
      rightGrad.addColorStop(0, 'rgba(255,77,94,0.05)');
      rightGrad.addColorStop(1, 'rgba(255,77,94,0.55)');
      ctx.fillStyle = rightGrad;
      ctx.fillRect(width - 8, height - padBottom - barMax * bear, 6, barMax * bear);
      ctx.restore();
    }

    // MACD — momentum histogram + signal line along the base strip
    if (layers.includes('macd')) {
      const fast = ema(prices, 8);
      const slow = ema(prices, 17);
      const macdLine = fast.map((v, i) => v - slow[i]!);
      const signal = ema(macdLine, 9);
      const hist = macdLine.map((v, i) => v - signal[i]!);
      const maxAbs = Math.max(0.2, ...hist.map((v) => Math.abs(v)));
      const baseY = height - padBottom - 8;
      const bandH = 30;
      ctx.save();
      hist.forEach((v, i) => {
        const h = (v / maxAbs) * bandH;
        ctx.fillStyle = v >= 0 ? 'rgba(40,224,127,0.6)' : 'rgba(255,77,94,0.6)';
        ctx.fillRect(i * stepX - 1.5, baseY - Math.max(0, h), 3, Math.abs(h));
      });
      ctx.restore();
    }

    // RSI — compact radial gauge, top-right corner
    if (layers.includes('rsi')) {
      const period = 14;
      const slice = history.slice(-period - 1);
      let gains = 0;
      let losses = 0;
      for (let i = 1; i < slice.length; i++) {
        const d = slice[i]!.price - slice[i - 1]!.price;
        if (d >= 0) gains += d;
        else losses -= d;
      }
      const rs = losses === 0 ? gains : gains / Math.max(0.0001, losses);
      const rsi = 100 - 100 / (1 + rs);
      const cx = width - 34;
      const cy = padTop + 34;
      const r = 20;
      ctx.save();
      ctx.strokeStyle = 'rgba(154,165,184,0.35)';
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI * 1.5);
      ctx.stroke();
      const pct = rsi / 100;
      const color = rsi > 70 ? '#ff4d5e' : rsi < 30 ? '#28e07f' : '#f5c343';
      ctx.strokeStyle = color;
      ctx.beginPath();
      ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * pct);
      ctx.stroke();
      ctx.fillStyle = color;
      ctx.font = 'bold 11px system-ui';
      ctx.textAlign = 'center';
      ctx.fillText(rsi.toFixed(0), cx, cy + 4);
      ctx.textAlign = 'left';
      ctx.restore();
    }

    // head marker — glowing dot at the current price
    ctx.save();
    ctx.shadowColor = accent;
    ctx.shadowBlur = 10;
    ctx.fillStyle = accent;
    ctx.beginPath();
    ctx.arc(lastPt[0], lastPt[1], 5.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [history, layers, leading, topInset, bottomInset]);

  return <canvas ref={ref} className="h-full w-full rounded-2xl" />;
}


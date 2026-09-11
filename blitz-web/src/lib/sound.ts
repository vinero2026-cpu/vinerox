'use client';

/**
 * Adaptive sound engine built on the Web Audio API: a filtered-noise "crowd"
 * bed that swells on big moves, plus short synthesized SFX for clicks, layer
 * toggles and coin payouts. No external SFX library needed.
 */
class SoundEngine {
  private ctx: AudioContext | null = null;
  private crowdGain: GainNode | null = null;
  private crowdSource: AudioBufferSourceNode | null = null;
  private master: GainNode | null = null;
  private muted = false;

  private ensure() {
    if (this.ctx) return this.ctx;
    const Ctor = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    this.ctx = new Ctor();
    this.master = this.ctx.createGain();
    this.master.gain.value = this.muted ? 0 : 0.8;
    this.master.connect(this.ctx.destination);
    return this.ctx;
  }

  private noiseBuffer(ctx: AudioContext, seconds: number) {
    const buffer = ctx.createBuffer(1, ctx.sampleRate * seconds, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    return buffer;
  }

  startCrowd() {
    const ctx = this.ensure();
    if (this.crowdSource) return;
    const buffer = this.noiseBuffer(ctx, 4);
    const source = ctx.createBufferSource();
    source.buffer = buffer;
    source.loop = true;
    const filter = ctx.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.value = 420;
    filter.Q.value = 0.6;
    const gain = ctx.createGain();
    gain.gain.value = 0.05;
    source.connect(filter).connect(gain).connect(this.master!);
    source.start();
    this.crowdSource = source;
    this.crowdGain = gain;
  }

  stopCrowd() {
    this.crowdSource?.stop();
    this.crowdSource = null;
  }

  /** Momentary crowd swell — sharp market move or a scored call. */
  roar(intensity = 1) {
    if (!this.ctx || !this.crowdGain) return;
    const now = this.ctx.currentTime;
    const peak = Math.min(0.35, 0.12 * intensity);
    this.crowdGain.gain.cancelScheduledValues(now);
    this.crowdGain.gain.setValueAtTime(this.crowdGain.gain.value, now);
    this.crowdGain.gain.linearRampToValueAtTime(peak, now + 0.08);
    this.crowdGain.gain.linearRampToValueAtTime(0.05, now + 0.9);
  }

  private blip(freq: number, duration: number, type: OscillatorType = 'sine', gainPeak = 0.25) {
    const ctx = this.ensure();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(0, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(gainPeak, ctx.currentTime + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + duration);
    osc.connect(gain).connect(this.master!);
    osc.start();
    osc.stop(ctx.currentTime + duration + 0.05);
  }

  click() {
    this.blip(760, 0.06, 'square', 0.12);
  }

  layerToggle(on: boolean) {
    this.blip(on ? 520 : 340, 0.12, 'triangle', 0.16);
  }

  /** Ascending arpeggio — the "coin fountain" ding. */
  coin() {
    const notes = [660, 880, 1046, 1318];
    notes.forEach((freq, i) => setTimeout(() => this.blip(freq, 0.18, 'sine', 0.2), i * 55));
  }

  /** Rising pitch sweep with a shimmer tail — the ability/boost-activation
   * "thrill". `intensity` (0..1) scales pitch reach and shimmer count so
   * rarer characters land a noticeably bigger sound. */
  powerUp(intensity = 0.5) {
    const ctx = this.ensure();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    const peak = 700 + intensity * 900;
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(160, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(peak, ctx.currentTime + 0.35);
    gain.gain.setValueAtTime(0.0001, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.18 + intensity * 0.1, ctx.currentTime + 0.08);
    gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 0.4);
    osc.connect(gain).connect(this.master!);
    osc.start();
    osc.stop(ctx.currentTime + 0.45);
    const shimmerCount = 3 + Math.round(intensity * 2);
    const shimmer = [880, 1046, 1318, 1568, 1760];
    for (let i = 0; i < shimmerCount; i++) {
      const freq = shimmer[i % shimmer.length]!;
      setTimeout(() => this.blip(freq, 0.2, 'sine', 0.14 + intensity * 0.08), 90 + i * 60);
    }
  }

  victory() {
    this.roar(1.6);
    [523, 659, 784, 1046].forEach((freq, i) => setTimeout(() => this.blip(freq, 0.3, 'sine', 0.22), i * 90));
  }

  defeat() {
    [400, 320, 260].forEach((freq, i) => setTimeout(() => this.blip(freq, 0.35, 'sawtooth', 0.14), i * 120));
  }

  /** "Boom-tzzka!" — a punchy sub-bass thump followed by a bright noise
   * crackle and a sparkle tail. The big correct-call hit. */
  successBoom() {
    const ctx = this.ensure();
    const now = ctx.currentTime;

    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(170, now);
    osc.frequency.exponentialRampToValueAtTime(45, now + 0.18);
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.5, now + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.28);
    osc.connect(gain).connect(this.master!);
    osc.start(now);
    osc.stop(now + 0.3);

    const noise = this.noiseBuffer(ctx, 0.12);
    [0, 0.05, 0.1].forEach((delay, i) => {
      const src = ctx.createBufferSource();
      src.buffer = noise;
      const filter = ctx.createBiquadFilter();
      filter.type = 'highpass';
      filter.frequency.value = 3200 + i * 600;
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, now + delay);
      g.gain.exponentialRampToValueAtTime(0.22 - i * 0.05, now + delay + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, now + delay + 0.08);
      src.connect(filter).connect(g).connect(this.master!);
      src.start(now + delay);
      src.stop(now + delay + 0.1);
    });

    [1318, 1568, 1976].forEach((freq, i) => setTimeout(() => this.blip(freq, 0.16, 'sine', 0.16), 120 + i * 45));
  }

  /** Comedic descending 4x "no-no-no-no" buzz — the missed-call sting. */
  failBuzzer() {
    const ctx = this.ensure();
    [280, 250, 220, 190].forEach((freq, i) => {
      setTimeout(() => {
        const now = ctx.currentTime;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(freq, now);
        osc.frequency.exponentialRampToValueAtTime(freq * 0.72, now + 0.14);
        gain.gain.setValueAtTime(0.0001, now);
        gain.gain.exponentialRampToValueAtTime(0.22, now + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.16);
        osc.connect(gain).connect(this.master!);
        osc.start(now);
        osc.stop(now + 0.18);
      }, i * 150);
    });
  }

  /** Stacked ascending chord blip — fired on streak milestones (3/5/7/...). */
  comboHype(streak: number) {
    const base = 660 + Math.min(6, streak) * 40;
    [base, base * 1.26, base * 1.5].forEach((freq, i) => setTimeout(() => this.blip(freq, 0.22, 'triangle', 0.18), i * 40));
  }


  setMuted(muted: boolean) {
    this.muted = muted;
    if (this.master) this.master.gain.value = muted ? 0 : 0.8;
  }
}

export const sound = new SoundEngine();

// Synthesizes an original 120 BPM soundtrack (pad, bass, kick, hats, pluck arp) to public/music.wav. No samples, no dependencies.
import {writeFileSync} from 'node:fs';
const SR = 44100, DUR = 53, N = SR * DUR, L = new Float32Array(N), R = new Float32Array(N);
const hz = (m) => 440 * 2 ** ((m - 69) / 12);
const add = (t, v, pan = 0.5) => { const i = Math.round(t * SR); if (i < 0 || i >= N) return; L[i] += v * (1 - pan); R[i] += v * pan; };
const BEAT = 0.5, BAR = 2;
const chords = [[57, 60, 64, 67], [53, 57, 60, 64], [48, 55, 60, 64], [55, 59, 62, 67]]; // Am7 Fmaj7 C G
const roots = [33, 29, 36, 31];
// pad: starts 0s, fades in; swells at scenes
const padEnv = (t) => Math.min(1, t / 3) * (t > DUR - 3 ? Math.max(0, (DUR - t) / 3) : 1);
for (let n = 0; n < N; n++) {
  const t = n / SR, ci = Math.floor(t / (BAR * 2)) % 4, ch = chords[ci];
  const within = (t % (BAR * 2)) / (BAR * 2), swell = 0.55 + 0.45 * Math.sin(Math.PI * within);
  let v = 0;
  for (const m of ch) for (const d of [-0.12, 0.12]) { const f = hz(m + d / 12 * 12 * 0.01 * 0 + d * 0.1); v += Math.sin(2 * Math.PI * f * t) + 0.35 * Math.sin(4 * Math.PI * f * t + 1); }
  v *= 0.018 * padEnv(t) * swell;
  L[n] += v * 0.9; R[n] += v * 0.9;
}
const kick = (t, amp = 1) => { for (let i = 0; i < SR * 0.45; i++) { const x = i / SR, f = 48 + 110 * Math.exp(-x * 28); const ph = 2 * Math.PI * (48 * x + 110 * (1 - Math.exp(-x * 28)) / 28); add(t + x, amp * 0.8 * Math.sin(ph) * Math.exp(-x * 7), 0.5); } };
const hat = (t, amp = 0.12) => { for (let i = 0; i < SR * 0.05; i++) { const x = i / SR; add(t + x, amp * (Math.random() * 2 - 1) * Math.exp(-x * 90), 0.62); } };
const pluck = (t, m, amp = 0.09, pan = 0.5) => { const f = hz(m); for (let i = 0; i < SR * 0.6; i++) { const x = i / SR, e = Math.exp(-x * 6); add(t + x, amp * e * (Math.sin(2 * Math.PI * f * x) + 0.3 * Math.sin(4 * Math.PI * f * x)), pan); } };
const bass = (t, m, len = 0.45, amp = 0.2) => { const f = hz(m); for (let i = 0; i < SR * len; i++) { const x = i / SR; add(t + x, amp * Math.sin(2 * Math.PI * f * x) * Math.min(1, x * 60) * Math.exp(-x * 3.5)); } };
const whoosh = (t, len = 0.7, amp = 0.16) => { let lp = 0; for (let i = 0; i < SR * len; i++) { const x = i / SR, e = Math.sin(Math.PI * Math.min(1, x / len)) ** 2; lp += (Math.random() * 2 - 1 - lp) * (0.02 + 0.3 * x / len); add(t + x, amp * e * lp, 0.5); } };
for (let b = 0; b * BEAT < DUR; b++) {
  const t = b * BEAT, bar = Math.floor(t / BAR), ci = Math.floor(t / (BAR * 2)) % 4;
  if (t >= 7 && t < 50) { kick(t, t >= 12.5 ? 1 : 0.55); bass(t, roots[ci] + 12 * (b % 2), 0.4, 0.17); }
  if (t >= 12.5 && t < 50) hat(t + BEAT / 2);
  if (t >= 14 && t < 49) { const sc = chords[ci]; pluck(t, sc[b % 4] + 12, 0.07, 0.3 + 0.4 * ((b % 3) / 2)); pluck(t + BEAT / 2, sc[(b + 2) % 4] + 24, 0.05, 0.7); }
}
// accents
kick(12.5, 1.3); whoosh(12.4); kick(46, 1.4); whoosh(45.6, 0.5); whoosh(2.1, 0.5, 0.1);
for (const m of chords[0]) pluck(46, m + 12, 0.1);
// UI ticks at key moments (s): search typing, pin, paste, switches
for (const t of [20.6, 20.7, 20.8, 20.9, 21.0, 21.1, 21.2]) pluck(t, 96, 0.04);
for (const t of [18.7, 21.4, 23.8]) pluck(t, 84, 0.08);
// normalize + soft clip + fade tail
let peak = 0; for (let i = 0; i < N; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
const g = 0.85 / peak, buf = Buffer.alloc(44 + N * 4);
buf.write('RIFF', 0); buf.writeUInt32LE(36 + N * 4, 4); buf.write('WAVEfmt ', 8); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(2, 22);
buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 4, 28); buf.writeUInt16LE(4, 32); buf.writeUInt16LE(16, 34); buf.write('data', 36); buf.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) { const fade = Math.min(1, (N - i) / (SR * 2.5)); buf.writeInt16LE(Math.round(Math.tanh(L[i] * g * 1.2) * 32000 * fade), 44 + i * 4); buf.writeInt16LE(Math.round(Math.tanh(R[i] * g * 1.2) * 32000 * fade), 46 + i * 4); }
writeFileSync(new URL('../public/music.wav', import.meta.url), buf);
console.log('wrote music.wav', (buf.length / 1e6).toFixed(1), 'MB');

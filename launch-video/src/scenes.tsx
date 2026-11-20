import React from 'react';
import {Img, staticFile, useCurrentFrame} from 'remotion';
import {ACCENT, GREY, INK, APPS, Card, FONT, Glass, Ico, Item, Key, Words, ip, sp} from './ui';

const C = ({children, style}: {children: React.ReactNode; style?: React.CSSProperties}) => (
  <div style={{position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', fontFamily: FONT, ...style}}>{children}</div>
);

// 1. cold open
export const Cold: React.FC = () => {
  const f = useCurrentFrame();
  const dot = sp(f, 0, {damping: 12, stiffness: 160, mass: 0.7}), pulse = 1 + 0.12 * Math.sin(f * 0.5);
  const gone = ip(f, [14, 24], [0, 1]);
  return (
    <C>
      <div style={{position: 'absolute', width: 44, height: 44, borderRadius: 22, background: INK, transform: `scale(${dot * pulse * (1 - gone)})`, opacity: 1 - ip(f, [16, 28], [0, 1])}} />
      {f >= 12 && <Words text="Copied." f={f - 12} size={230} weight={800} stagger={0} out={52} />}
    </C>
  );
};

// 2. the problem
const P_ITEMS: Item[] = [
  {id: 'p0', app: 'safari', kind: 'link', text: 'https://linear.app/pastry/PST-214', meta: 'linear.app', ago: '10 min ago'},
  {id: 'p1', app: 'messages', kind: 'text', text: 'Running 10 min late. Start without me!', meta: '38 characters', ago: '4 min ago'},
  {id: 'p2', app: 'photos', kind: 'image', meta: '1280 × 800', ago: '1 min ago'},
];
export const Problem: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <C>
      <div style={{position: 'absolute', top: 190, left: 0, right: 0}}>
        {f < 80 && <div style={{position: 'absolute', left: 0, right: 0, display: 'flex', justifyContent: 'center'}}><Words text="You copied it 10 minutes ago." f={f} size={96} out={66} /></div>}
        {f >= 76 && <div style={{position: 'absolute', left: 0, right: 0, display: 'flex', justifyContent: 'center'}}><Words text="Where did it go?" f={f - 76} size={120} accentFrom={3} weight={800} /></div>}
      </div>
      <div style={{position: 'absolute', left: 844, top: 520}}>
        {P_ITEMS.map((it, i) => {
          const at = 14 + i * 17, e = sp(f, at, {damping: 15, stiffness: 170, mass: 0.8}), x = sp(f, at + 17, {damping: 20, stiffness: 200, mass: 0.7}), last = i === P_ITEMS.length - 1;
          const away = last ? sp(f, 66, {damping: 22, stiffness: 120, mass: 1}) : x;
          if (f < at) return null;
          return <div key={it.id} style={{position: 'absolute', opacity: e * (1 - away), transform: `translate(${-away * 360}px, ${(1 - e) * 80 - away * (last ? 80 : 0)}px) rotate(${-away * 4}deg) scale(${(0.9 + 0.1 * e) * (1 + 0.15 * (last ? 0 : 0))})`, filter: `blur(${away * 10}px)`}}><Card item={it} /></div>;
        })}
      </div>
    </C>
  );
};

// 3. everything you copy
const G_ITEMS: Item[] = [
  {id: 'g0', app: 'notes', kind: 'text', text: 'Invoice #4021\nDue Nov 30 · $1,280.00', meta: '2 lines', ago: '22 min ago'},
  {id: 'g1', app: 'safari', kind: 'link', text: 'https://linear.app/pastry/PST-214', meta: 'linear.app', ago: '2 min ago'},
  {id: 'g2', app: 'photos', kind: 'image', meta: '1280 × 800', ago: '14 min ago'},
  {id: 'g3', app: 'finder', kind: 'file', text: 'Q3-Invoice.pdf', meta: 'PDF · 248 KB', ago: '9 min ago'},
];
export const Gather: React.FC = () => {
  const f = useCurrentFrame();
  const from = [[-1200, -100], [1200, -150], [-1100, 400], [1200, 450]], to = [[-330, 20, -5], [-110, -10, -2], [110, -10, 2], [330, 20, 5]];
  const col = sp(f, 92, {damping: 22, stiffness: 150, mass: 1});
  return (
    <C>
      <div style={{position: 'absolute', top: 150, left: 0, right: 0, display: 'flex', justifyContent: 'center'}}><Words text="Everything you copy." f={f - 2} size={112} accentFrom={2} out={96} weight={800} /></div>
      <div style={{position: 'absolute', left: 844, top: 480}}>
        {G_ITEMS.map((it, i) => {
          const e = sp(f, 12 + i * 2.5, {damping: 24, stiffness: 90, mass: 1.1});
          const x = from[i][0] * (1 - e) + to[i][0] * e, y = from[i][1] * (1 - e) + to[i][1] * e;
          return <div key={it.id} style={{position: 'absolute', transform: `translate(${x * (1 - col)}px, ${y * (1 - col) - 20 * col}px) rotate(${to[i][2] * e + (1 - e) * (i % 2 ? 10 : -10)}deg) scale(${1.08 * (1 - col) + 0.04 * col})`, opacity: 1 - col * col}}><Card item={it} /></div>;
        })}
      </div>
    </C>
  );
};

// 9. private
export const Privacy: React.FC = () => {
  const f = useCurrentFrame();
  const mac = sp(f, 6), draw = ip(f, [8, 50], [1, 0], (t) => 1 - (1 - t) ** 3), lock = sp(f, 48);
  const stroke = {fill: 'none', stroke: INK, strokeWidth: 5, strokeLinecap: 'round', strokeLinejoin: 'round'} as const;
  return (
    <C>
      <div style={{position: 'absolute', top: 190, left: 0, right: 0, display: 'flex', justifyContent: 'center', gap: 30}}>
        <Words text="On your Mac." f={f} size={104} weight={700} />
        {f >= 22 && <Words text="Private." f={f - 22} size={104} weight={700} accentFrom={0} />}
      </div>
      <svg width="360" height="300" viewBox="0 0 360 300" style={{position: 'absolute', top: 410, opacity: ip(f, [4, 16], [0, 1])}}>
        <rect x="40" y="20" width="280" height="190" rx="22" {...stroke} strokeDasharray="1000" strokeDashoffset={1000 * draw} />
        <path d="M20 250h320" {...stroke} strokeDasharray="1000" strokeDashoffset={1000 * draw} />
        <g opacity={lock} transform={`translate(0 ${(1 - lock) * 10})`}>
          <rect x="146" y="98" width="68" height="54" rx="13" fill={INK} />
          <path d="M160 98V84a20 20 0 0 1 40 0v14" {...stroke} strokeWidth={7} />
          <circle cx="180" cy="125" r="6" fill="#F8F5F3" />
        </g>
      </svg>
      <div style={{position: 'absolute', bottom: 130, left: 0, right: 0, display: 'flex', justifyContent: 'center', gap: 22}}>
        {[['chip', 'History stays local'], ['sparkles', 'Suggestions run on-device'], ['hand', 'One permission: Accessibility']].map(([ic, t], i) => {
          const e = sp(f, 26 + i * 7);
          return <div key={t} style={{position: 'relative', width: 420, height: 74, opacity: e, transform: `translateY(${(1 - e) * 16}px)`}}><Glass r={37} style={{inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12, color: INK, fontSize: 22, fontWeight: 600}}><Ico n={ic} s={26} c={INK} fill={ic === 'sparkles'} />{t}</Glass></div>;
        })}
      </div>
    </C>
  );
};

// 10. keyboard
const KEYS: [string[], string][] = [[['⇧', '⌘', 'V'], 'Open the shelf'], [['⌘', '1–9'], 'Paste a card'], [['↩'], 'Paste'], [['⇧', '↩'], 'Paste plain or rich'], [['⌘', 'P'], 'Pin'], [['⇥'], 'Flip to Pinned'], [['⇧', '→'], 'Jump to suggestions'], [['⇧', '←'], 'Back to history'], [['⌘', ','], 'Settings'], [['esc'], 'Close']];
export const Keyboard: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <C>
      <div style={{position: 'absolute', top: 110, left: 0, right: 0, display: 'flex', justifyContent: 'center'}}><Words text="Made for the keyboard." f={f} size={104} weight={800} accentFrom={3} /></div>
      <div style={{position: 'absolute', left: 250, top: 330, width: 1420, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '40px 60px'}}>
        {KEYS.map(([ks, label], i) => {
          const at = 14 + i * 7, e = sp(f, at), press = ip(f, [at + 4, at + 7, at + 14, at + 18], [0, 1, 1, 0]);
          return (
            <div key={label} style={{display: 'flex', alignItems: 'center', gap: 24, opacity: ip(e, [0, 0.4], [0, 1]), transform: `translateY(${(1 - e) * 30}px)`}}>
              <div style={{display: 'flex', gap: 10, width: 330, justifyContent: 'flex-end'}}>{ks.map((k) => <Key key={k} k={k} s={74} press={press} />)}</div>
              <div style={{color: INK, whiteSpace: 'nowrap', fontSize: 38, fontWeight: 600, letterSpacing: '-0.01em'}}>{label}</div>
            </div>
          );
        })}
      </div>
    </C>
  );
};

// 12. end card
export const End: React.FC = () => {
  const f = useCurrentFrame();
  const ic = sp(f, 0, {damping: 14, stiffness: 120, mass: 0.9}), btn = sp(f, 90, {damping: 14, stiffness: 150, mass: 0.8}), pulse = ip(f, [120, 130, 150], [0, 1, 0]);
  return (
    <C style={{paddingBottom: 30}}>
      <div style={{position: 'absolute', top: 100, width: 400, height: 400, opacity: ic, transform: `scale(${0.9 + 0.1 * ic})`, filter: `drop-shadow(0 24px 40px rgba(70,50,30,${0.22 * ic}))`}}>
        <Img src={staticFile('icon.png')} width={400} height={400} style={{display: 'block', transform: `translateY(${Math.sin(f / 22) * 5}px)`}} />
      </div>
      <div style={{position: 'absolute', top: 480, display: 'flex', justifyContent: 'center', left: 0, right: 0}}>{f >= 15 && <Words text="Pastry" f={f - 15} size={150} weight={800} stagger={0} />}</div>
      <div style={{position: 'absolute', top: 650, left: 0, right: 0, display: 'flex', justifyContent: 'center'}}>{f >= 45 && <Words text="Your clipboard, remembered." f={f - 45} size={58} weight={600} accentFrom={2} stagger={5} />}</div>
      <div style={{position: 'absolute', top: 790, width: 520, height: 92, opacity: btn, transform: `scale(${(0.92 + 0.08 * btn) * (1 + 0.025 * pulse)})`}}>
        <div style={{position: 'absolute', inset: 0, borderRadius: 46, background: ACCENT, boxShadow: '0 14px 36px rgba(232,97,143,.28), inset 0 1px 0 rgba(255,255,255,.35)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 14, color: '#fff', fontSize: 34, fontWeight: 600, overflow: 'hidden'}}>
          <Ico n="down" s={34} w={2.6} />Download for macOS
          <div style={{position: 'absolute', top: 0, bottom: 0, width: 120, left: -160 + ip(f, [118, 150], [0, 760]), background: 'linear-gradient(100deg, transparent, rgba(255,255,255,.3), transparent)'}} />
        </div>
      </div>
      <div style={{position: 'absolute', top: 925, color: GREY, fontSize: 24, opacity: ip(f, [110, 130], [0, 1]), display: 'flex', alignItems: 'center', gap: 12}}>Press <Key k="⇧" s={38} /><Key k="⌘" s={38} /><Key k="V" s={38} /> anywhere</div>
    </C>
  );
};
export {APPS};

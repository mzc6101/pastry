import React from 'react';
import {useCurrentFrame} from 'remotion';
import {GREY, INK, Card, CARD_H, CARD_W, FONT, Glass, Ico, Item, Key, Words, ip, sp} from './ui';
import {MailWin, MessagesWin, WIN_H, WIN_W, XcodeWin} from './windows';

export const DEMO_FRAMES = 810;
const SH_L = 85, SH_W = 1750, SH_H = 372, SH_T = 1080 - 40 - SH_H, PITCH = CARD_W + 2, CARD_X0 = 24, CARDS_TOP = 72;
const SIDE_X = 1000, SPARK = {x: 1657, y: 36};

const H: Item[] = [
  {id: 'h0', app: 'messages', kind: 'text', text: 'Running 10 min late. Start without me!', meta: '38 characters', ago: 'Just now'},
  {id: 'h1', app: 'safari', kind: 'link', text: 'https://linear.app/pastry/PST-214', meta: 'linear.app', ago: '2 min ago'},
  {id: 'h2', app: 'mail', kind: 'text', text: 'Thanks for the quick turnaround. Invoice attached — let me know if anything looks off.', meta: '86 characters', ago: '6 min ago'},
  {id: 'h3', app: 'finder', kind: 'file', text: 'Q3-Invoice.pdf', meta: 'PDF · 248 KB', ago: '9 min ago'},
  {id: 'h4', app: 'photos', kind: 'image', meta: '1280 × 800', ago: '14 min ago'},
  {id: 'h5', app: 'notes', kind: 'text', text: 'Invoice #4021\nDue Nov 30 · $1,280.00', meta: '2 lines', ago: '22 min ago'},
  {id: 'h6', app: 'xcode', kind: 'text', text: 'func paste(_ item: ClipItem) throws {\n  try Pasteboard.write(item)\n}', meta: '3 lines', ago: '31 min ago'},
  {id: 'h7', app: 'terminal', kind: 'text', text: 'npm run build && npm test', meta: '25 characters', ago: '40 min ago'},
];
const SETS: {key: string; name: string; at: number; out: number; items: Item[]}[] = [
  {key: 'mail', name: 'Mail', at: 400, out: 500, items: [
    {id: 'sm0', app: 'mail', kind: 'text', text: 'Best,\nAlex', meta: 'Sign-off', ago: '1 hr ago'},
    {id: 'sm1', app: 'notes', kind: 'text', text: 'Invoice #4021\nDue Nov 30 · $1,280.00', meta: '2 lines', ago: '22 min ago'},
    {id: 'sm2', app: 'finder', kind: 'file', text: 'Q3-Invoice.pdf', meta: 'PDF · 248 KB', ago: '9 min ago'}]},
  {key: 'xcode', name: 'Xcode', at: 508, out: 600, items: [
    {id: 'sx0', app: 'xcode', kind: 'text', text: 'func paste(_ item: ClipItem) throws {\n  try Pasteboard.write(item)\n}', meta: '3 lines', ago: '31 min ago'},
    {id: 'sx1', app: 'safari', kind: 'link', text: 'https://developer.apple.com/documentation/appkit', meta: 'developer.apple.com', ago: '1 hr ago'},
    {id: 'sx2', app: 'terminal', kind: 'text', text: 'xcodebuild -scheme Pastry build', meta: '31 characters', ago: '40 min ago'}]},
  {key: 'messages', name: 'Messages', at: 608, out: 99999, items: [
    {id: 'ss0', app: 'safari', kind: 'link', text: 'https://maps.apple.com/?q=Blue+Bottle', meta: 'maps.apple.com', ago: 'Just now'},
    {id: 'ss1', app: 'photos', kind: 'image', meta: '1280 × 800', ago: '14 min ago'},
    {id: 'ss2', app: 'messages', kind: 'text', text: 'Running 10 min late. Start without me!', meta: '38 characters', ago: '2 min ago'}]},
];

const ALL = [0, 1, 2, 3, 4, 5, 6, 7];
const EVENTS = [
  {at: 0, slots: ALL},
  {at: 178, slots: [-1, -1, 0, 1, -1, 2, -1, -1]},
  {at: 258, slots: [-1, 0, -1, 1, -1, -1, -1, -1]},
  {at: 284, slots: ALL},
];
const CAPTIONS = [
  {from: 92, to: 162, text: 'One shelf.', accent: 1},
  {from: 162, to: 292, text: 'Find it. Pin it.', accent: 2},
  {from: 292, to: 382, text: '⌘1–9. Paste now.', accent: 1},
  {from: 382, to: 702, text: 'It knows where you are.', accent: 2},
  {from: 702, to: 810, text: 'Your call.', accent: 1},
];
const FLIES: {at: number; from: number[]; to: number[]; via?: number[][]; text: string}[] = [
  {at: 326, from: [693, 872], to: [760, 392], text: 'Thanks for the quick…'},
  {at: 478, from: [1201, 790], to: [540, 505], via: [[1420, 700], [1420, 600]], text: 'Best, Alex'},
  {at: 556, from: [1201, 790], to: [680, 470], via: [[1420, 700], [1420, 600]], text: 'func paste(_ item…'},
  {at: 656, from: [1201, 790], to: [1180, 450], via: [[1420, 700], [1420, 600]], text: 'maps.apple.com/…'},
];

const KeyToast: React.FC<{keys: string[]; f: number}> = ({keys, f}) => {
  if (f < 0 || f > 40) return null;
  const e = sp(f, 0), press = ip(f, [8, 11, 24, 28], [0, 1, 1, 0]);
  return (
    <div style={{position: 'absolute', left: 0, right: 0, top: 126, display: 'flex', justifyContent: 'center', gap: 12, opacity: ip(f, [0, 6], [0, 1]) * (1 - ip(f, [30, 40], [0, 1])), transform: `translateY(${(1 - e) * 20}px) scale(${0.8 + 0.2 * e})`}}>
      {keys.map((k) => <Key key={k} k={k} s={58} press={press} />)}
    </div>
  );
};

export const Demo: React.FC = () => {
  const d = useCurrentFrame();
  // ---------- state ----------
  const ev = [...EVENTS].reverse().find((e) => e.at <= d)!, k = EVENTS.indexOf(ev);
  const slotOf = (i: number) => {
    const cur = ev.slots[i], prev = k > 0 ? EVENTS[k - 1].slots[i] : cur, s = sp(d, ev.at + i * 1.5, {damping: 17, stiffness: 170, mass: 0.8});
    if (cur >= 0 && prev >= 0) return {slot: prev + (cur - prev) * s, vis: 1};
    if (cur >= 0) return {slot: cur, vis: s};
    if (prev >= 0) return {slot: prev, vis: 1 - s};
    return {slot: 0, vis: 0};
  };
  const sug = Math.max(0, Math.min(1, sp(d, 385) - sp(d, 725) + sp(d, 770)));
  const drain = 1 - sug;
  const rise = sp(d, 47, {damping: 20, stiffness: 120, mass: 1}), fall = sp(d, 790, {damping: 22, stiffness: 120, mass: 1});
  const typed = d < 168 ? 0 : Math.min(7, Math.floor((d - 168) / 3) + 1), query = d >= 252 ? '' : 'invoice'.slice(0, typed);
  const typing = d >= 164 && d < 254;
  const pinnedAmt = sp(d, 258) * (1 - sp(d, 284));
  const selId = d >= 316 && d < 350 ? 2 : (ALL.find((i) => ev.slots[i] === 0) ?? 0);
  const pinOf = (i: number) => i === 1 || (i === 3 && d >= 230);
  const front = d < 500 ? 'Mail' : d < 600 ? 'Xcode' : 'Messages';
  const xin = sp(d, 500, {damping: 22, stiffness: 130, mass: 1}), min = sp(d, 600, {damping: 22, stiffness: 130, mass: 1});
  const winIn = sp(d, 58, {damping: 20, stiffness: 110, mass: 1});
  const keysE = sp(d, 62, {damping: 18, stiffness: 120, mass: 1});
  const pulse = ip(d, [725, 732, 748], [0, 1, 0]) + ip(d, [770, 777, 793], [0, 1, 0]);

  return (
    <div style={{position: 'absolute', inset: 0, overflow: 'hidden', fontFamily: FONT}}>
      {/* menu bar */}
      <div style={{position: 'absolute', left: 0, right: 0, top: 0, height: 36, background: 'rgba(255,255,255,.6)', backdropFilter: 'blur(30px)', boxShadow: '0 1px 0 rgba(0,0,0,.06)', display: 'flex', alignItems: 'center', padding: '0 24px', gap: 26, color: INK, fontSize: 16, opacity: winIn}}>
        <b>{front}</b>{['File', 'Edit', 'View', 'Window', 'Help'].map((m) => <span key={m} style={{opacity: 0.8}}>{m}</span>)}
        <span style={{marginLeft: 'auto', opacity: 0.85}}>Wed 9:41 AM</span>
      </div>
      {/* app windows */}
      <div style={{position: 'absolute', left: (1920 - WIN_W) / 2, top: 192, width: WIN_W, height: WIN_H, opacity: winIn, transform: `translateY(${(1 - winIn) * 50 + fall * -30}px)`}}>
        <div style={{position: 'absolute', transform: `translateX(${-xin * 1300}px) scale(${1 - xin * 0.05})`, opacity: 1 - xin}}><MailWin p={sp(d, 338)} p2={sp(d, 484)} /></div>
        <div style={{position: 'absolute', transform: `translateX(${(1 - xin) * 1300 - min * 1300}px)`, opacity: xin * (1 - min)}}><XcodeWin p={sp(d, 560)} /></div>
        <div style={{position: 'absolute', transform: `translateX(${(1 - min) * 1300}px)`, opacity: min}}><MessagesWin p={sp(d, 660)} /></div>
      </div>
      {/* captions */}
      <div style={{position: 'absolute', left: 0, right: 0, top: 48}}>
        {CAPTIONS.map((c) => d >= c.from && d < c.to + 14 && <div key={c.text} style={{position: 'absolute', left: 0, right: 0, display: 'flex', justifyContent: 'center'}}><Words text={c.text} f={d - c.from} size={60} accentFrom={c.accent} out={c.to - c.from - 6} /></div>)}
      </div>
      {/* large keycaps -> toast */}
      {d < 110 && (
        <div style={{position: 'absolute', left: 0, right: 0, top: 0, bottom: 0, display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 26, transform: `translateY(${-keysE * 320}px) scale(${1 - keysE * 0.62})`, opacity: sp(d, 0) * (1 - ip(d, [96, 108], [0, 1]))}}>
          {['⇧', '⌘', 'V'].map((kk, i) => <div key={kk} style={{transform: `scale(${0.6 + 0.4 * sp(d, i * 5)})`}}><Key k={kk} s={190} press={ip(d, [15 + i * 15, 18 + i * 15, 58, 64], [0, 1, 1, 0])} /></div>)}
        </div>
      )}
      <KeyToast keys={['⌘', 'P']} f={d - 222} />
      <KeyToast keys={['⇥']} f={d - 252} />
      <KeyToast keys={['⌘', '3']} f={d - 314} />
      <KeyToast keys={['⇧', '→']} f={d - 434} />
      <KeyToast keys={['↩']} f={d - 470} />
      {/* shelf */}
      <div style={{position: 'absolute', left: SH_L, top: SH_T, width: SH_W, height: SH_H, transform: `translateY(${(1 - rise) * (SH_H + 120) + fall * 480}px)`}}>
        <Glass r={46} tint={0.55} style={{inset: 0}} />
        {/* search */}
        <div style={{position: 'absolute', left: 24, top: 17, width: 320, height: 38, borderRadius: 19, background: 'rgba(255,255,255,.7)', boxShadow: typing ? 'inset 0 0 0 2px rgba(29,29,31,.7)' : 'inset 0 0 0 1px rgba(0,0,0,.1)', display: 'flex', alignItems: 'center', gap: 9, padding: '0 14px', color: INK, fontSize: 18}}>
          <Ico n="search" s={17} c={GREY} />
          {query ? <span>{query}<span style={{opacity: typing && Math.floor(d / 8) % 2 ? 0 : 1, color: INK}}>|</span></span> : <span style={{opacity: 0.45}}>Search</span>}
        </div>
        {/* segmented pill */}
        <div style={{position: 'absolute', left: (SH_W - 232) / 2, top: 17, width: 232, height: 38, borderRadius: 19, background: 'rgba(0,0,0,.05)', boxShadow: 'inset 0 0 0 1px rgba(0,0,0,.06)'}}>
          <div style={{position: 'absolute', top: 3, left: 3 + pinnedAmt * 112, width: 114, height: 32, borderRadius: 16, background: '#fff', boxShadow: '0 1px 4px rgba(0,0,0,.18)'}} />
          {[['Clipboard', 'clip', 0], ['Pinned', 'pin', 1]].map(([l, ic, i]) => (
            <div key={l as string} style={{position: 'absolute', left: 3 + (i as number) * 112, top: 3, width: 114, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, color: INK, fontSize: 15, fontWeight: 600}}><Ico n={ic as string} s={15} fill={ic === 'pin'} />{l}</div>
          ))}
        </div>
        {/* sparkle + gear */}
        <div style={{position: 'absolute', left: 1638, top: 17, width: 38, height: 38, borderRadius: 19, background: sug > 0.5 ? 'rgba(29,29,31,.82)' : 'rgba(255,255,255,.7)', boxShadow: 'inset 0 0 0 1px rgba(0,0,0,.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: sug > 0.5 ? '#fff' : INK, transform: `scale(${1 + pulse * 0.12})`}}><Ico n="sparkles" s={19} fill={sug > 0.5} /></div>
        <div style={{position: 'absolute', left: 1688, top: 17, width: 38, height: 38, borderRadius: 19, background: 'rgba(255,255,255,.7)', boxShadow: 'inset 0 0 0 1px rgba(0,0,0,.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: INK}}><Ico n="gear" s={19} /></div>
        {/* history */}
        <div style={{position: 'absolute', left: 0, top: 62, height: 300, width: SH_W - (SH_W - 950) * sug, overflow: 'hidden'}}>
          {H.map((it, i) => {
            const {slot, vis} = slotOf(i), ent = sp(d, 56 + i * 5, {damping: 15, stiffness: 160, mass: 0.8});
            const flash = i === 2 ? ip(d, [316, 322, 336], [0, 1, 0]) : 0;
            return (
              <div key={it.id} style={{position: 'absolute', left: CARD_X0 + slot * PITCH, top: 10, opacity: ent * vis, transform: `translateY(${(1 - ent) * 70}px) scale(${(0.94 + 0.06 * vis) * (1 + 0.04 * flash)})`}}>
                <Card item={it} num={i + 1} pinned={pinOf(i)} pinPop={i === 3 ? 1 + 0.6 * ip(d, [230, 236, 248], [0, 1, 0]) : 1} selected={d < 448 && ent > 0.9 && i === selId} badge={ip(d, [296 + i * 3, 300 + i * 3, 308 + i * 3], [0, 1, 0])} />
              </div>
            );
          })}
        </div>
        {d >= 440 && d < 530 && (() => {
          const g = sp(d, 448, {damping: 24, stiffness: 90, mass: 1});
          return <div style={{position: 'absolute', left: CARD_X0 + (SIDE_X - CARD_X0) * g + 1.5, top: CARDS_TOP + 1.5, width: CARD_W - 3, height: CARD_H - 3, borderRadius: 25.5, border: '3px solid rgba(29,29,31,.8)', opacity: ip(d, [440, 448], [0, 1]) * (1 - ip(d, [496, 512], [0, 1]))}} />;
        })()}
        {/* divider + suggestions */}
        <div style={{position: 'absolute', left: 980, top: 88, width: 1.5, height: 244, background: 'rgba(0,0,0,.12)', opacity: sug}} />
        {SETS.map((st) => {
          const lead = sp(d, st.at, {damping: 20, stiffness: 160, mass: 0.8}) * (1 - sp(d, st.out, {damping: 22, stiffness: 260, mass: 0.7}));
          return (
            <React.Fragment key={st.key}>
              {lead > 0.01 && (
                <div style={{position: 'absolute', left: SIDE_X, top: 40, display: 'flex', alignItems: 'center', gap: 7, color: INK, fontSize: 15, fontWeight: 600, opacity: lead * sug}}>
                  <Ico n="sparkles" s={15} c={INK} fill /> Picked for {st.name}<span style={{fontWeight: 400, color: GREY, marginLeft: 8}}>on-device model</span>
                </div>
              )}
              {st.items.map((it, j) => {
                const e = sp(d, st.at + j * 5, {damping: 14, stiffness: 170, mass: 0.8}), x = sp(d, st.out + j * 3, {damping: 22, stiffness: 260, mass: 0.7}), v = e * (1 - x);
                if (v < 0.005) return null;
                const cx = SIDE_X + j * PITCH + CARD_W / 2, cy = CARDS_TOP + CARD_H / 2, dr = drain * drain * (3 - 2 * drain);
                const sel = (st.key === 'xcode' && d >= 548 && d < 584) || (st.key === 'messages' && d >= 648 && d < 684);
                return (
                  <div key={it.id} style={{position: 'absolute', left: SIDE_X + j * PITCH, top: CARDS_TOP, opacity: v * (1 - dr * dr), transform: `translate(${(1 - e) * 140 - x * 40 + dr * (SPARK.x - cx)}px, ${x * 24 + dr * (SPARK.y - cy)}px) scale(${(0.92 + 0.08 * v) * (1 - 0.92 * dr)})`}}>
                    <Card item={it} suggested selected={sel && j === 0} />
                  </div>
                );
              })}
            </React.Fragment>
          );
        })}
      </div>
      {/* paste fly-in chips */}
      {FLIES.map((fl) => {
        const f = d - fl.at;
        if (f < 0 || f > 32) return null;
        const e = Math.min(1, sp(f, 0, {damping: 26, stiffness: 90, mass: 1})), pts = [fl.from, ...(fl.via ?? []), fl.to], seg = pts.length - 1;
        const k = Math.min(seg - 1, Math.floor(e * seg)), u = e * seg - k, x = pts[k][0] + (pts[k + 1][0] - pts[k][0]) * u, y = pts[k][1] + (pts[k + 1][1] - pts[k][1]) * u;
        return <div key={fl.at} style={{position: 'absolute', left: x, top: y, transform: `translate(-50%,-50%) scale(${1 - 0.3 * e})`, opacity: ip(f, [0, 4], [0, 1]) * (1 - ip(f, [24, 32], [0, 1])), padding: '10px 20px', borderRadius: 22, background: '#fff', color: INK, fontSize: 20, fontWeight: 600, boxShadow: '0 10px 30px rgba(70,50,30,.18)', whiteSpace: 'nowrap'}}>{fl.text}</div>;
      })}
    </div>
  );
};

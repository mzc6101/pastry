import React from 'react';
import {Img, interpolate, spring, staticFile} from 'remotion';

export const FONT = '-apple-system, "SF Pro Display", "SF Pro", "Helvetica Neue", Helvetica, Arial, sans-serif';
export const MONO = '"SF Mono", ui-monospace, Menlo, monospace';
export const ACCENT = '#E8618F'; // brand pink: CTA + tiny accents only
export const INK = '#1d1d1f', GREY = '#86868b';
const clampOpts = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
export const ip = (f: number, i: number[], o: number[], easing?: (t: number) => number) =>
  interpolate(f, i, o, {...clampOpts, easing});
export const sp = (f: number, delay = 0, cfg = {damping: 24, stiffness: 120, mass: 1}) =>
  spring({frame: Math.max(0, f - delay), fps: 30, config: cfg});
export const SOFT = {damping: 22, stiffness: 160, mass: 1};

// ---------- icons ----------
export const Ico: React.FC<{n: string; s?: number; c?: string; fill?: boolean; w?: number}> = ({n, s = 16, c = 'currentColor', fill, w = 2}) => {
  const p = {fill: 'none', stroke: c, strokeWidth: w, strokeLinecap: 'round', strokeLinejoin: 'round'} as const;
  let body: React.ReactNode = null;
  switch (n) {
    case 'search': body = <g {...p}><circle cx="10.5" cy="10.5" r="6.5" /><path d="M15.5 15.5L21 21" /></g>; break;
    case 'gear': body = <g {...p}><circle cx="12" cy="12" r="3.2" /><circle cx="12" cy="12" r="6.6" />{[0, 45, 90, 135, 180, 225, 270, 315].map((a) => <path key={a} d="M12 3.2V5.4" transform={`rotate(${a} 12 12)`} strokeWidth={w + 1.2} />)}</g>; break;
    case 'sparkles': body = <g stroke={c} strokeWidth={fill ? 0 : w} strokeLinejoin="round" fill={fill ? c : 'none'}><path d="M10 4l1.9 5.1L17 11l-5.1 1.9L10 18l-1.9-5.1L3 11l5.1-1.9z" /><path d="M18.5 3l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z" /><path d="M18 14.5l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z" /></g>; break;
    case 'link': body = <g {...p}><path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1" /><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1" /></g>; break;
    case 'text': body = <g {...p}><path d="M4 6h16M4 11h11M4 16h16M4 21h8" /></g>; break;
    case 'photo': body = <g {...p}><rect x="3" y="4" width="18" height="16" rx="3" /><circle cx="9" cy="10" r="1.7" /><path d="M4 18l5-5 4 4 3-3 4 4" /></g>; break;
    case 'doc': body = <g {...p} fill={fill ? c : 'none'}><path d="M6 3h8l5 5v12a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z" /></g>; break;
    case 'pin': body = <g stroke={c} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round" fill={fill ? c : 'none'}><path d="M9 3h6l-1 7 3 3H7l3-3z" /><path d="M12 13v8" /></g>; break;
    case 'clip': body = <g {...p}><rect x="5" y="4" width="14" height="17" rx="3" /><rect x="9" y="2" width="6" height="4" rx="1.5" /></g>; break;
    case 'chip': body = <g {...p}><rect x="6" y="6" width="12" height="12" rx="2.5" /><rect x="9.5" y="9.5" width="5" height="5" rx="1" />{[9, 12, 15].flatMap((v) => [<path key={'a' + v} d={`M${v} 2.5V6M${v} 18v3.5`} />, <path key={'b' + v} d={`M2.5 ${v}H6M18 ${v}h3.5`} />])}</g>; break;
    case 'nocloud': body = <g {...p}><path d="M7 18a4 4 0 0 1-.6-7.96A6 6 0 0 1 18 9.5a4.2 4.2 0 0 1 .8 8.3" /><path d="M3 3l18 18" /></g>; break;
    case 'lock': body = <g {...p}><rect x="5" y="11" width="14" height="10" rx="3" /><path d="M8 11V8a4 4 0 0 1 8 0v3" /></g>; break;
    case 'hand': body = <g {...p}><path d="M12 3l7 3v5c0 5-3.2 8.5-7 10-3.8-1.5-7-5-7-10V6z" /><path d="M9 12l2.2 2.2L15.5 10" /></g>; break;
    case 'down': body = <g {...p}><path d="M12 4v12M6.5 11.5L12 17l5.5-5.5M5 21h14" /></g>; break;
  }
  return <svg width={s} height={s} viewBox="0 0 24 24" style={{display: 'block', flex: 'none'}}>{body}</svg>;
};

// ---------- apps ----------
export type AppKey = 'mail' | 'messages' | 'safari' | 'notes' | 'photos' | 'finder' | 'terminal' | 'xcode';
export const APPS: Record<AppKey, {name: string; tint: string; icon?: string}> = {
  mail: {name: 'Mail', tint: '#4A90E2', icon: 'apps/mail.png'},
  messages: {name: 'Messages', tint: '#2FB454', icon: 'apps/messages.png'},
  safari: {name: 'Safari', tint: '#2E8FEA', icon: 'apps/safari.png'},
  notes: {name: 'Notes', tint: '#E2A820', icon: 'apps/notes.png'},
  photos: {name: 'Photos', tint: '#E27D60', icon: 'apps/photos.png'},
  finder: {name: 'Finder', tint: '#3C9CE6', icon: 'apps/finder.png'},
  terminal: {name: 'Terminal', tint: '#58585C', icon: 'apps/terminal.png'},
  xcode: {name: 'Xcode', tint: '#4F67E8'},
};
export const AppIcon: React.FC<{app: AppKey; s: number}> = ({app, s}) =>
  APPS[app].icon ? <Img src={staticFile(APPS[app].icon!)} width={s} height={s} style={{display: 'block', flex: 'none'}} /> : (
    <svg width={s} height={s} viewBox="0 0 40 40" style={{display: 'block', flex: 'none'}}>
      <defs><linearGradient id="xg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#3FA4FF" /><stop offset="1" stopColor="#1451D6" /></linearGradient></defs>
      <rect x="2" y="2" width="36" height="36" rx="9" fill="url(#xg)" />
      <path d="M12 28l13-13M23 11l4 4M11 24l5 5" stroke="#fff" strokeWidth="3" strokeLinecap="round" fill="none" />
    </svg>
  );

// ---------- glass ----------
export const Glass: React.FC<{style?: React.CSSProperties; r?: number; tint?: number; children?: React.ReactNode}> = ({style, r = 36, tint = 0.62, children}) => (
  <div style={{position: 'absolute', borderRadius: r, backdropFilter: 'blur(40px) saturate(1.4)', WebkitBackdropFilter: 'blur(40px) saturate(1.4)',
    background: `rgba(255,255,255,${tint})`,
    boxShadow: '0 24px 60px rgba(70,50,30,.14), 0 2px 8px rgba(70,50,30,.06), inset 0 1px 0 rgba(255,255,255,.9), inset 0 0 0 1px rgba(0,0,0,.06)', ...style}}>
    {children}
  </div>
);

// ---------- cards ----------
export type Item = {id: string; app: AppKey; kind: 'text' | 'link' | 'image' | 'file'; text?: string; meta: string; ago: string};
const LABEL = {text: 'Text', link: 'Link', image: 'Image', file: 'File'};
const KIND_ICO = {text: 'text', link: 'link', image: 'photo', file: 'doc'};

const Shot: React.FC = () => (
  <svg width="100%" height="100%" viewBox="0 0 222 168" preserveAspectRatio="xMidYMid slice">
    <defs><linearGradient id="sh" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#E9DCCB" /><stop offset="1" stopColor="#D7BE9F" /></linearGradient></defs>
    <rect width="222" height="168" fill="url(#sh)" />
    <rect x="22" y="22" width="178" height="124" rx="10" fill="#fff" opacity=".95" />
    <rect x="22" y="22" width="178" height="18" rx="10" fill="#F1EDE8" />
    <circle cx="33" cy="31" r="3" fill="#FF5F57" /><circle cx="43" cy="31" r="3" fill="#FEBC2E" /><circle cx="53" cy="31" r="3" fill="#28C840" />
    <rect x="34" y="52" width="70" height="8" rx="4" fill="#B8A890" /><rect x="34" y="68" width="150" height="6" rx="3" fill="#E3DCD2" /><rect x="34" y="80" width="130" height="6" rx="3" fill="#E3DCD2" />
    <rect x="34" y="98" width="68" height="36" rx="8" fill="#C9B79C" /><rect x="110" y="98" width="74" height="36" rx="8" fill="#8E8579" />
  </svg>
);

export const CARD_W = 232, CARD_H = 264;
export const Card: React.FC<{item: Item; num?: number; pinned?: boolean; pinPop?: number; selected?: boolean; suggested?: boolean; badge?: number}> = ({item, num, pinned, pinPop = 1, selected, suggested, badge = 0}) => {
  const a = APPS[item.app], mono = item.app === 'xcode' || item.app === 'terminal';
  const hh = 56, white = 'rgba(255,255,255,';
  return (
    <div style={{position: 'relative', width: CARD_W, height: CARD_H, flex: 'none'}}>
      <div style={{position: 'absolute', inset: 5, borderRadius: 22, overflow: 'hidden', background: 'rgba(255,255,255,.78)', boxShadow: 'inset 0 0 0 .75px rgba(0,0,0,.1), 0 6px 18px rgba(70,50,30,.10)', fontFamily: FONT}}>
        <div style={{height: hh, background: `linear-gradient(180deg, ${a.tint}, ${a.tint}cc)`, position: 'relative', filter: 'saturate(1.1)'}}>
          <div style={{position: 'absolute', left: 14, top: 11, display: 'flex', alignItems: 'center', gap: 6, color: '#fff', fontSize: 15, fontWeight: 600}}>
            <Ico n={suggested ? 'sparkles' : KIND_ICO[item.kind]} s={15} c="#fff" w={2.2} fill={suggested} />{LABEL[item.kind]}
          </div>
          <div style={{position: 'absolute', left: 14, top: 33, color: white + '.85)', fontSize: 12, fontWeight: 500}}>{item.ago}</div>
          <div style={{position: 'absolute', right: 9, top: 8}}><AppIcon app={item.app} s={40} /></div>
        </div>
        <div style={{position: 'absolute', top: hh, left: 0, right: 0, bottom: 30, overflow: 'hidden'}}>
          {item.kind === 'image' && <Shot />}
          {item.kind === 'file' && (
            <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 22, gap: 12}}>
              <svg width="64" height="78" viewBox="0 0 64 78"><path d="M6 2h38l16 16v56a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z" fill="#fff" stroke="#cfcac4" strokeWidth="1.5" /><path d="M44 2l16 16H48a4 4 0 0 1-4-4z" fill="#D9DEE8" /><rect x="10" y="44" width="34" height="16" rx="4" fill="#E5484D" /><text x="27" y="56" textAnchor="middle" fontSize="11" fontWeight="700" fill="#fff" fontFamily={FONT}>PDF</text></svg>
              <div style={{color: INK, fontSize: 14, fontWeight: 500, textAlign: 'center', padding: '0 12px'}}>{item.text}</div>
            </div>
          )}
          {item.kind === 'link' && <div style={{padding: '14px 14px', color: '#0A6CFF', fontSize: 15, fontWeight: 500, lineHeight: 1.35, overflowWrap: 'anywhere'}}>{item.text}</div>}
          {item.kind === 'text' && <div style={{padding: '13px 14px', color: INK, fontSize: mono ? 13 : 15, lineHeight: 1.42, fontFamily: mono ? MONO : FONT, whiteSpace: 'pre-wrap'}}>{item.text}</div>}
        </div>
        <div style={{position: 'absolute', left: 0, right: 0, bottom: 0, height: 30, background: 'rgba(0,0,0,.04)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: GREY, fontSize: 12}}>
          {item.meta}
          {pinned && <div style={{position: 'absolute', left: 9, top: 5, color: '#FF9F0A', transform: `scale(${pinPop})`}}><Ico n="pin" s={17} fill c="#FF9F0A" /></div>}
          {num !== undefined && !suggested && <div style={{position: 'absolute', right: 11, color: badge > 0 ? INK : '#a1a1a6', fontSize: 12, fontWeight: 600, transform: `scale(${1 + badge * 0.4})`}}>⌘{num}</div>}
        </div>
      </div>
      {selected && <div style={{position: 'absolute', inset: 1.5, borderRadius: 25.5, border: '3px solid rgba(29,29,31,.8)'}} />}
    </div>
  );
};

// ---------- keycaps ----------
export const Key: React.FC<{k: string; s?: number; press?: number}> = ({k, s = 70, press = 0}) => {
  const w = k.length > 1 ? s * (k === 'esc' ? 1.3 : 1.55) : s;
  return (
    <div style={{width: w, height: s, borderRadius: s * 0.24, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: FONT, fontSize: s * (k.length > 1 ? 0.36 : 0.46), fontWeight: 500, color: press > 0.5 ? '#fff' : INK, flex: 'none',
      background: press > 0.5 ? '#3a3a3c' : 'linear-gradient(180deg, #ffffff, #f1eeeb)',
      boxShadow: `inset 0 0 0 1px rgba(0,0,0,.08), 0 ${s * 0.07 * (1 - press)}px 0 rgba(0,0,0,.14), 0 ${s * 0.2}px ${s * 0.35}px rgba(70,50,30,.12)`,
      transform: `translateY(${press * s * 0.07}px)`}}>{k}</div>
  );
};

// ---------- kinetic type ----------
export const Words: React.FC<{text: string; f: number; size: number; weight?: number; accentFrom?: number; stagger?: number; out?: number; color?: string; align?: 'center' | 'left'}> = ({text, f, size, weight = 700, accentFrom = 999, stagger = 5, out = 9999, color = INK, align = 'center'}) => {
  const words = text.split(' ');
  return (
    <div style={{display: 'flex', flexWrap: 'wrap', justifyContent: align === 'center' ? 'center' : 'flex-start', gap: `0 ${size * 0.26}px`, fontFamily: FONT, fontSize: size, fontWeight: weight, letterSpacing: '-0.03em', lineHeight: 1.08, color}}>
      {words.map((w, i) => {
        const e = sp(f, i * stagger, {damping: 22, stiffness: 120, mass: 1});
        const o = ip(f, [out + i * 1.5, out + 10 + i * 1.5], [0, 1]);
        const accent = i >= accentFrom;
        return (
          <span key={i} style={{display: 'inline-block', opacity: ip(e, [0, 0.5], [0, 1]) * (1 - o), transform: `translateY(${(1 - e) * size * 0.25 - o * size * 0.08}px) scale(${0.96 + 0.04 * e})`, filter: `blur(${(1 - e) * 8 + o * 8}px)`,
            ...(accent ? {color: GREY} : {})}}>{w}</span>
        );
      })}
    </div>
  );
};

export const Fill: React.FC<{children: React.ReactNode; style?: React.CSSProperties}> = ({children, style}) => (
  <div style={{position: 'absolute', inset: 0, ...style}}>{children}</div>
);

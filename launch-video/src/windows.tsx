import React from 'react';
import {FONT, MONO, ACCENT, ip, sp} from './ui';

export const WIN_W = 1040, WIN_H = 460;
const Chrome: React.FC<{title: string; dark?: boolean; children: React.ReactNode}> = ({title, dark, children}) => (
  <div style={{width: WIN_W, height: WIN_H, borderRadius: 18, overflow: 'hidden', background: dark ? '#1c1d23' : '#f7f6f9', fontFamily: FONT, boxShadow: '0 30px 70px rgba(70,50,30,.18), 0 0 0 1px rgba(0,0,0,.08)', position: 'relative'}}>
    <div style={{height: 46, background: dark ? '#26272e' : '#ecebf0', display: 'flex', alignItems: 'center', padding: '0 18px', gap: 9, position: 'relative'}}>
      {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <div key={c} style={{width: 13, height: 13, borderRadius: 7, background: c}} />)}
      <div style={{position: 'absolute', left: 0, right: 0, textAlign: 'center', fontSize: 15, fontWeight: 600, color: dark ? '#b9bac4' : '#6b6a75'}}>{title}</div>
    </div>
    {children}
  </div>
);
const Bar: React.FC<{w: number; c?: string}> = ({w, c = '#dcdae3'}) => <div style={{height: 12, width: w, borderRadius: 6, background: c, marginBottom: 14}} />;
const Pasted: React.FC<{p: number; children: React.ReactNode; style?: React.CSSProperties}> = ({p, children, style}) => (
  <div style={{opacity: ip(p, [0, 0.4], [0, 1]), transform: `translateY(${(1 - p) * 14}px)`, borderRadius: 8, padding: '4px 8px', margin: '0 -8px', background: `rgba(29,29,31,${0.07 * (1 - ip(p, [0.8, 1], [0, 1]))})`, ...style}}>{children}</div>
);

export const MailWin: React.FC<{p: number; p2: number}> = ({p, p2}) => (
  <Chrome title="New Message">
    <div style={{padding: '22px 36px', color: '#222'}}>
      {[['To:', 'Sam Rivera'], ['Subject:', 'Re: Q3 numbers']].map(([a, b]) => (
        <div key={a} style={{display: 'flex', gap: 16, fontSize: 19, padding: '9px 0', borderBottom: '1px solid #e2e0e8'}}><span style={{color: '#9a98a6', width: 90}}>{a}</span><span style={{fontWeight: 500}}>{b}</span></div>
      ))}
      <div style={{fontSize: 22, marginTop: 24, lineHeight: 1.5}}>Hi Sam,</div>
      <div style={{marginTop: 6}}><Pasted p={p}><div style={{fontSize: 22, lineHeight: 1.5}}>Thanks for the quick turnaround. Invoice attached — let me know if anything looks off.</div></Pasted></div>
      <div style={{marginTop: 6}}><Pasted p={p2}><div style={{fontSize: 22, lineHeight: 1.5}}>Best,<br />Alex</div></Pasted></div>
      <div style={{marginTop: 22}}><Bar w={300} /><Bar w={180} /></div>
    </div>
  </Chrome>
);

const kw = '#FF7AB2', ty = '#9BE7FF', fn = '#7DD3A8', st = '#FFA07A', cm = '#6c7086';
const code = (l: Array<[string, string]>) => l.map(([t, c], i) => <span key={i} style={{color: c}}>{t}</span>);
export const XcodeWin: React.FC<{p: number}> = ({p}) => {
  const lines: React.ReactNode[] = [
    code([['import ', kw], ['AppKit', ty]]), '',
    code([['final class ', kw], ['Shelf', ty], [': NSPanel {', '#d6d7e0']]),
    code([['    private var ', kw], ['items', '#d6d7e0'], [': [', '#d6d7e0'], ['ClipItem', ty], ['] = []', '#d6d7e0']]), '',
    code([['    // paste the selected item', cm]]),
  ];
  return (
    <Chrome title="Shelf.swift — Pastry" dark>
      <div style={{display: 'flex', fontFamily: MONO, fontSize: 19, lineHeight: '30px', padding: '16px 0', color: '#d6d7e0'}}>
        <div style={{width: 64, textAlign: 'right', paddingRight: 18, color: '#5b5d6e'}}>{Array.from({length: 11}, (_, i) => <div key={i}>{i + 1}</div>)}</div>
        <div style={{flex: 1, whiteSpace: 'pre'}}>
          {lines.map((l, i) => <div key={i}>{l || ' '}</div>)}
          <Pasted p={p} style={{margin: '0 24px 0 -8px'}}>
            {code([['    func ', kw], ['paste', fn], ['(_ item: ', '#d6d7e0'], ['ClipItem', ty], [') throws {', '#d6d7e0']])}<br />
            {code([['        try ', kw], ['Pasteboard', ty], ['.write(item)', '#d6d7e0']])}<br />
            {code([['    }', '#d6d7e0']])}
          </Pasted>
        </div>
      </div>
    </Chrome>
  );
};

export const MessagesWin: React.FC<{p: number}> = ({p}) => {
  const bub = (t: string, me?: boolean) => (
    <div style={{alignSelf: me ? 'flex-end' : 'flex-start', background: me ? '#2f8cff' : '#e6e5ea', color: me ? '#fff' : '#222', fontSize: 21, padding: '11px 20px', borderRadius: 24, maxWidth: 560}}>{t}</div>
  );
  return (
    <Chrome title="Alex">
      <div style={{padding: '24px 40px', display: 'flex', flexDirection: 'column', gap: 14}}>
        {bub('Where are we meeting?')}
        {bub('Send me the spot!')}
        {bub('Running 10 min late', true)}
        <div style={{alignSelf: 'flex-end', opacity: ip(p, [0, 0.4], [0, 1]), transform: `translateY(${(1 - p) * 30}px) scale(${0.9 + 0.1 * p})`, transformOrigin: 'right bottom'}}>
          <div style={{background: '#2f8cff', color: '#fff', fontSize: 21, padding: '11px 20px', borderRadius: 24, textDecoration: 'underline'}}>https://maps.apple.com/?q=Blue+Bottle</div>
        </div>
      </div>
      <div style={{position: 'absolute', left: 40, right: 40, bottom: 22, height: 46, borderRadius: 23, border: '1.5px solid #d4d2db', color: '#aaa8b4', fontSize: 19, display: 'flex', alignItems: 'center', padding: '0 20px'}}>iMessage</div>
    </Chrome>
  );
};
export {sp, ACCENT};

import React from 'react';
import {AbsoluteFill, Audio, Sequence, staticFile, useCurrentFrame} from 'remotion';
import {ip} from './ui';
import {Demo, DEMO_FRAMES} from './Demo';
import {Cold, End, Gather, Keyboard, Privacy, Problem} from './scenes';

const T = {cold: 0, problem: 75, gather: 210, demo: 330};
const AFTER = T.demo + DEMO_FRAMES;           // 1140
const T2 = {priv: AFTER, kbd: AFTER + 120, end: AFTER + 240};
export const TOTAL = T2.end + 210;            // 1590

const Bg: React.FC = () => {
  return (
    <AbsoluteFill style={{background: '#F8F5F3', overflow: 'hidden'}}>
      <AbsoluteFill style={{opacity: 0.035, mixBlendMode: 'multiply'}}>
        <svg width="100%" height="100%"><filter id="gr"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="4" /><feColorMatrix type="saturate" values="0" /></filter><rect width="100%" height="100%" filter="url(#gr)" /></svg>
      </AbsoluteFill>
      <AbsoluteFill style={{background: 'radial-gradient(ellipse at center, transparent 55%, rgba(60,40,20,.07) 100%)'}} />
    </AbsoluteFill>
  );
};

// blur-dissolve wrapper for scene edges
const Scene: React.FC<{from: number; dur: number; fin?: number; fout?: number; children: React.ReactNode}> = ({from, dur, fin = 8, fout = 8, children}) => (
  <Sequence from={from} durationInFrames={dur}>
    <Fade dur={dur} fin={fin} fout={fout}>{children}</Fade>
  </Sequence>
);
const Fade: React.FC<{dur: number; fin: number; fout: number; children: React.ReactNode}> = ({dur, fin, fout, children}) => {
  const f = useCurrentFrame();
  const o = Math.min(fin ? ip(f, [0, fin], [0, 1]) : 1, fout ? ip(f, [dur - fout, dur], [1, 0]) : 1);
  return <AbsoluteFill style={{opacity: o, filter: o < 1 ? `blur(${(1 - o) * 14}px)` : undefined}}>{children}</AbsoluteFill>;
};

export const Video: React.FC = () => (
  <AbsoluteFill>
    <Bg />
    <Scene from={T.cold} dur={T.problem - T.cold} fin={0}><Cold /></Scene>
    <Scene from={T.problem} dur={T.gather - T.problem}><Problem /></Scene>
    <Scene from={T.gather} dur={T.demo - T.gather} fout={4}><Gather /></Scene>
    <Scene from={T.demo} dur={DEMO_FRAMES} fin={4} fout={10}><Demo /></Scene>
    <Scene from={T2.priv} dur={120}><Privacy /></Scene>
    <Scene from={T2.kbd} dur={120}><Keyboard /></Scene>
    <Scene from={T2.end} dur={210} fout={0}><End /></Scene>
    <Audio src={staticFile('music.wav')} />
  </AbsoluteFill>
);

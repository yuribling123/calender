import React from 'react';
import {AbsoluteFill, Audio, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';

const ink = '#292625';
const muted = '#817976';
const paper = '#F8F3ED';
const screenshotWidth = 1290;
const displayWidth = 960;
const scale = displayWidth / screenshotWidth;
const cropHeight = 1625;

type Stamp = {x: number; y: number; width: number; height: number; frame: number; rotation: number};

// Coordinates refer to the supplied 1290 × 2796 screenshot.
const stamps: Stamp[] = [
  {x: 68, y: 742, width: 105, height: 98, frame: 44, rotation: -2},
  {x: 248, y: 738, width: 102, height: 105, frame: 61, rotation: 2},
  {x: 395, y: 747, width: 145, height: 86, frame: 78, rotation: -1},
  {x: 1125, y: 748, width: 96, height: 90, frame: 95, rotation: 3},
  {x: 210, y: 962, width: 168, height: 85, frame: 112, rotation: -2},
  {x: 758, y: 952, width: 132, height: 95, frame: 129, rotation: 1},
  {x: 1120, y: 949, width: 104, height: 103, frame: 146, rotation: -3},
  {x: 247, y: 1166, width: 102, height: 99, frame: 163, rotation: 2},
  {x: 390, y: 1170, width: 158, height: 83, frame: 180, rotation: -1},
  {x: 948, y: 1165, width: 110, height: 118, frame: 197, rotation: 2},
  {x: 238, y: 1370, width: 120, height: 125, frame: 214, rotation: -2},
  {x: 420, y: 1370, width: 105, height: 130, frame: 231, rotation: 1},
];

const PaperTexture: React.FC = () => (
  <AbsoluteFill style={{backgroundColor: paper, backgroundImage: 'radial-gradient(circle at 15% 8%, rgba(242,141,178,.18), transparent 27%), radial-gradient(circle at 90% 84%, rgba(169,154,185,.17), transparent 29%), repeating-linear-gradient(95deg, rgba(80,60,45,.015) 0px, rgba(80,60,45,.015) 1px, transparent 1px, transparent 6px)'}} />
);

const StampPiece: React.FC<{stamp: Stamp; imageTop: number}> = ({stamp, imageTop}) => {
  const frame = useCurrentFrame() - stamp.frame;
  const {fps} = useVideoConfig();
  if (frame < 0) return null;
  const landing = spring({frame, fps, config: {damping: 9, stiffness: 250, mass: 0.55}});
  const press = interpolate(frame, [0, 3, 6, 12], [1.17, 0.91, 1.04, 1], {extrapolateRight: 'clamp'});
  const opacity = interpolate(frame, [0, 2], [0, 1], {extrapolateRight: 'clamp'});
  const displayX = stamp.x * scale + 60;
  const displayY = stamp.y * scale + imageTop;
  const width = stamp.width * scale;
  const height = stamp.height * scale;
  return (
    <div style={{position: 'absolute', left: displayX, top: displayY, width, height, overflow: 'hidden', opacity, mixBlendMode: 'multiply', transformOrigin: '50% 70%', transform: `translateY(${interpolate(landing, [0, 1], [-38, 0])}px) scale(${press}) rotate(${stamp.rotation}deg)`}}>
      <Img src={staticFile('assets/november-calendar.png')} style={{position: 'absolute', width: displayWidth, height: 2796 * scale, left: -stamp.x * scale, top: -stamp.y * scale}} />
    </div>
  );
};

const CalendarScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({frame, fps, config: {damping: 19, stiffness: 90}});
  const exit = interpolate(frame, [272, 300], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  const imageTop = 250;
  const calendarHeight = cropHeight * scale;
  return (
    <AbsoluteFill style={{opacity: exit}}>
      <PaperTexture />
      <div style={{position: 'absolute', left: 72, top: 56, color: muted, fontWeight: 700, fontSize: 24, letterSpacing: 8}}>LITTLE TODAY · NOVEMBER</div>
      <div style={{position: 'absolute', left: 72, top: 105, color: ink, fontSize: 58, fontWeight: 760, letterSpacing: -3}}>日子，被一个个记住</div>
      <div style={{position: 'absolute', left: 60, top: imageTop, width: displayWidth, height: calendarHeight, overflow: 'hidden', borderRadius: 44, background: '#FBF9F6', boxShadow: '0 30px 76px rgba(70,50,45,.16)', transform: `translateY(${interpolate(enter, [0, 1], [80, 0])}px) scale(${interpolate(enter, [0, 1], [.96, 1])})`}}>
        <Img src={staticFile('assets/november-calendar.png')} style={{width: displayWidth, height: 2796 * scale}} />
        {stamps.map((stamp) => <div key={`${stamp.x}-${stamp.y}`} style={{position: 'absolute', left: stamp.x * scale - 4, top: stamp.y * scale - 4, width: stamp.width * scale + 8, height: stamp.height * scale + 8, background: '#FBF9F6', borderRadius: 10}} />)}
      </div>
      {stamps.map((stamp) => <StampPiece key={stamp.frame} stamp={stamp} imageTop={imageTop} />)}
      <div style={{position: 'absolute', bottom: 62, left: 0, right: 0, textAlign: 'center', color: muted, fontSize: 25, letterSpacing: 2}}>把每一天，过成自己的小图案</div>
    </AbsoluteFill>
  );
};

const LogoScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const local = frame - 286;
  const enter = spring({frame: Math.max(0, local), fps, config: {damping: 15, stiffness: 90}});
  const opacity = interpolate(local, [0, 14], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
  return (
    <AbsoluteFill style={{opacity}}>
      <PaperTexture />
      <div style={{position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center'}}>
        <Img src={staticFile('assets/app-icon.png')} style={{width: 300, height: 300, borderRadius: 68, boxShadow: '0 28px 65px rgba(68,49,45,.18)', transform: `translateY(${interpolate(enter, [0, 1], [38, 0])}px) scale(${interpolate(enter, [0, 1], [.84, 1])})`}} />
        <div style={{fontSize: 78, fontWeight: 780, color: ink, marginTop: 55, letterSpacing: -5}}>今天份</div>
        <div style={{fontSize: 29, color: muted, marginTop: 22, letterSpacing: 3}}>LITTLE TODAY</div>
        <div style={{fontSize: 37, color: ink, marginTop: 68}}>把每一天，过成自己的小图案</div>
      </div>
    </AbsoluteFill>
  );
};

export const LittleTodayVideo: React.FC = () => (
  <AbsoluteFill style={{fontFamily: '-apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif'}}>
    <Audio src={staticFile('audio/little-today-music.wav')} volume={(frame) => interpolate(frame, [0, 22, 320, 359], [0, 0.72, 0.72, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})} />
    <CalendarScene />
    <LogoScene />
  </AbsoluteFill>
);

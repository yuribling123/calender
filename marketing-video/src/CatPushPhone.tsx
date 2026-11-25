import React from 'react';
import {AbsoluteFill, Audio, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';

const clamp = {extrapolateLeft: 'clamp' as const, extrapolateRight: 'clamp' as const};

export const CatPushPhone: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const intro = spring({frame, fps, config: {damping: 16, stiffness: 95}});
  const effort = interpolate(frame, [34, 58], [0, 1], clamp);
  const travel = interpolate(frame, [58, 151], [0, 1], {
    ...clamp,
    easing: (value) => value * value * (3 - 2 * value),
  });
  const finish = interpolate(frame, [146, 172], [1, 0], clamp);
  const phoneX = interpolate(travel, [0, 1], [420, 1260]);
  // The generated sprite includes transparent padding; 265px aligns the visible paws to the phone edge.
  const catX = phoneX - 265;
  const bob = frame >= 58 && frame <= 151 ? Math.sin((frame - 58) * 0.9) * 7 : Math.sin(frame * 0.45) * effort * 4;
  const phoneTilt = Math.sin(frame * 0.22) * effort * 0.7 + Math.sin(frame * 0.7) * travel * 0.35;
  const speedLineOpacity = interpolate(travel, [0, 0.18, 0.82, 1], [0, 0.28, 0.28, 0], clamp);

  return (
    <AbsoluteFill style={{fontFamily: '-apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif', background: '#FFFFFF', overflow: 'hidden'}}>
      <Audio src={staticFile('audio/little-today-music.wav')} startFrom={0} volume={(f) => interpolate(f, [0, 15, 145, 179], [0, 0.56, 0.56, 0], clamp)} />

      <div style={{position: 'absolute', top: 92, left: 0, right: 0, textAlign: 'center', color: '#817976', fontSize: 25, fontWeight: 700, letterSpacing: 8, opacity: finish}}>
        LITTLE TODAY
      </div>
      <div style={{position: 'absolute', top: 145, left: 0, right: 0, textAlign: 'center', color: '#292625', fontSize: 57, fontWeight: 760, letterSpacing: -3, opacity: finish}}>
        今天也要向前一点点
      </div>

      {[0, 1, 2].map((index) => (
        <div key={index} style={{position: 'absolute', left: catX - 120 - index * 78, top: 1050 + index * 30, width: 115, height: 4, borderRadius: 4, background: '#A99AB9', opacity: speedLineOpacity * (1 - index * 0.2)}} />
      ))}

      <div style={{position: 'absolute', left: phoneX, top: 320 + bob * 0.25, width: 610, opacity: intro * finish, transformOrigin: '50% 80%', transform: `translateY(${interpolate(intro, [0, 1], [90, 0])}px) rotate(${phoneTilt}deg)`}}>
        <Img src={staticFile('assets/phone-calendar-cropped.png')} style={{width: '100%', display: 'block'}} />
      </div>

      <div style={{position: 'absolute', left: catX, top: 1010 + bob, width: 350, opacity: intro * finish, transformOrigin: '80% 60%', transform: `translateY(${interpolate(intro, [0, 1], [70, 0])}px) rotate(${interpolate(effort, [0, 1], [0, -3])}deg) scaleX(${interpolate(effort, [0, 1], [1, 0.96])})`, filter: 'drop-shadow(0 16px 12px rgba(60,45,40,.14))'}}>
        <Img src={staticFile('assets/cat-pushing-right.png')} style={{width: '100%', display: 'block'}} />
      </div>

      <div style={{position: 'absolute', left: 0, right: 0, bottom: 158, textAlign: 'center', color: '#817976', fontSize: 27, letterSpacing: 2, opacity: interpolate(frame, [0, 28, 116, 143], [0, 1, 1, 0], clamp)}}>
        推走一点点拖延，留下今天
      </div>
    </AbsoluteFill>
  );
};

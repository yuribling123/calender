import React from 'react';
import {Composition} from 'remotion';
import {LittleTodayVideo} from './Video';
import {CatPushPhone} from './CatPushPhone';

export const RemotionRoot: React.FC = () => (
  <>
    <Composition
      id="LittleTodayVertical"
      component={LittleTodayVideo}
      durationInFrames={360}
      fps={30}
      width={1080}
      height={1920}
    />
    <Composition
      id="CatPushPhone"
      component={CatPushPhone}
      durationInFrames={180}
      fps={30}
      width={1080}
      height={1920}
    />
  </>
);

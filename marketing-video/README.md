# Little Today Remotion 宣传视频

独立于 iOS App 的 9:16 竖屏宣传视频工程。成片为 1080 × 1920、30 fps、12 秒，使用十一月日历截图制作逐个盖章动画，最后显示 App Logo，不修改 SwiftUI 主工程。

## 使用

```bash
npm install
npm run music
npm start
```

在 Remotion Studio 中选择 `LittleTodayVertical` 预览。

导出 MP4：

```bash
npm run render
```

输出位置：`out/little-today-vertical.mp4`。

导出小猫推手机短片：

```bash
npm run render:cat-push
```

输出位置：`out/cat-pushes-phone.mp4`。

导出封面：

```bash
npm run still
```

## 时间线

- 0–8 秒：日历表情按日期逐个盖章出现
- 8–10 秒：完整日历停留
- 10–12 秒：App Logo 与品牌文案

配乐由 `scripts/generate-music.mjs` 本地生成，为轻柔八音盒与雨滴氛围，不使用外部版权音乐。

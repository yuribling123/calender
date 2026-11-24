# MoodCalendar project instructions

## Product rules

- This is a native iPhone mood calendar built with SwiftUI and SwiftData. The deployment target is iOS 17 or later.
- A calendar day has at most one mood entry. Today can always be created or edited. The allowPastDateEditing preference defaults to on and allows creating or editing past entries via the add/edit action; when off, past days are read-only, including dates without entries. Future days are always read-only. Enforce the edit rule in persistence as well as the UI.
- The five moods, in order, are 极好 `#F28DB2`, 好 `#F3A58F`, 一般 `#E8C982`, 不好 `#91A9C5`, and 很差 `#A99AB9`. Keep their saved numeric values stable.
- The mood images are in `MoodCalendar/Resources/Assets.xcassets`. `moodBad` represents 不好 and comes from the user's `差.jpg`. Keep the supplied artwork intact unless the user asks to change it.
- Notes are optional. The editor reveals the text field after the user taps 写文字. Past entries with no note show a placeholder. Entries are stored locally; do not introduce accounts, network storage, or synchronization without a product request.
- `MoodCalendar Demo` uses disposable, in-memory Debug data. Keep it separate from the normal persistent store and unavailable in Release.

## Code organization

- `Features` contains screens and reusable view components. Views present state and forward actions; keep date calculations and persistence queries out of small view components.
- `Domain` owns mood definitions and calendar-day/month rules. Treat a day as a calendar date, not an arbitrary timestamp. Keep day-key behavior consistent when changing date or time-zone handling.
- `Persistence` owns SwiftData models and read/write operations. Preserve existing saved entries when changing the model; plan a migration for incompatible schema changes.
- Prefer small, cohesive types and descriptive names. Extract shared logic when it has a clear responsibility. Do not add layers, protocols, view models, dependencies, or empty folders solely to follow a pattern.
- Keep the UI calm and readable: warm light background, supplied mood artwork, fixed-size calendar cells, a quiet date selection mark, an inline selected-date detail, and accessible labels. Follow the user's latest design direction over these defaults.

## Design direction / 设计风格

- 核心风格是「复古 · 少女感 · Y2K」：柔和、细腻、有一点怀旧电子产品与私人手账的感觉。少女感来自轻柔配色和细节，不等于所有元素都用粉色；Y2K 不默认意味着霓虹、高饱和、强金属反光或堆叠装饰。
- 保留现有设计语言，优先调整比例、间距、文字层级与材质细节。复古随身听圆盘、轻微实体按压、柔和色纸可作为已有风格参考；不要仅因风格关键词就重新设计页面或新增装饰。
- 主题色主要用于强调、选中状态与控件细节，正文与辅助文字使用可适配明暗的中性色。使用集中管理的主题配色；新增颜色应同时考虑浅色和深色。修改深色外观时保留浅色设计，除非用户明确要求一起修改。
- 保留用户提供的插画与各组表情的个性；深色下心情、日常、陪伴、小幸使用白色线条，随性和兔兔保留原色。风格不能牺牲可读性、触控区域和无障碍标签。

## Verification

- 默认由用户自行检查模拟器中的界面和交互。除非用户明确要求模拟器验证，否则不要启动或操作模拟器、向模拟器安装应用，也不要通过 Xcode Run 启动应用进行验证。不要为此反复询问确认；完成代码修改与适当的静态检查或编译后直接交付，并如实说明未做模拟器验证。

- 每次完成任何文件修改（包括代码、文案、配置和 Markdown，以及 agent 代做的修改），交付前都必须展示本次改动。用户明确要求优先看到带有 Edited 文件名、增删行数、Undo 和 View changes 的应用原生变更卡片；仅在回复中写“已修改”或提供文件链接不能替代展示。原生卡片由客户端生成，不得用文字伪造或声称已提供不可用的撤销功能；如果客户端未生成卡片或无法主动生成，则必须使用可用工具打开本次改动的差异面板，并在最终回复中提供修改文件的可点击链接及简短说明。工具仅返回 queued 时，只能说明已请求打开，不能声称面板已展示。不要为了生成卡片重复修改文件。

- Keep verification proportional to the change. For simple visual or content edits (such as font size, weight, color, spacing, labels, or removing a decorative element), edit the relevant files, review the small diff, and report completion directly. Do not automatically build, install, launch a simulator, or add tests for these changes.
- Build and run appropriate non-UI checks for changes to functionality, gestures, data, navigation, complex layout, dependencies, or resource registration, and whenever the user explicitly requests verification. Batch related edits into one build rather than repeating this for each small adjustment. Simulator interaction checks remain user-owned unless explicitly requested; a general request to verify does not authorize simulator use.
- Do not claim a build or simulator check was performed unless it actually completed. For simple edits, a concise description and clickable links to the modified files are sufficient.
- For date or persistence changes, check month boundaries, leap years, one-entry-per-day updates, and reopening saved records. Add focused tests when they verify a real risk.
- If the local environment lacks full Xcode, perform available static checks and clearly report that compilation and simulator behavior remain unverified.
- Keep `README.md` accurate when setup, behavior, or project structure changes.

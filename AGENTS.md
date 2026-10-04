# MoodCalendar project instructions

## Product rules

- This is a native iPhone mood calendar built with SwiftUI and SwiftData. The deployment target is iOS 17 or later.
- A calendar day has at most one mood entry. Only today can be created or edited. Past days are read-only, including dates without entries; future days are selectable for a read-only not-yet-arrived state. Enforce the edit rule in persistence as well as the UI.
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

## Verification

- After code changes, run the relevant Xcode build on an available iPhone simulator and check the affected interaction when Xcode is available. Do not claim simulator verification from a syntax check alone.
- For date or persistence changes, check month boundaries, leap years, one-entry-per-day updates, and reopening saved records. Add focused tests when they verify a real risk.
- If the local environment lacks full Xcode, perform available static checks and clearly report that compilation and simulator behavior remain unverified.
- Keep `README.md` accurate when setup, behavior, or project structure changes.

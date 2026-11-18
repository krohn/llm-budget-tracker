# Changelog

All notable changes to LLM Budget Tracker are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0] - 2026-11-18

### Highlights

- The effective budget limit is now resolved across key, team member, team and user levels; the lowest limit wins.
- Usage is shown even when no budget limit is configured.
- New "Today", "Yesterday", "This week", "Last week" and "Last month" ranges in the per-model spend breakdown,
  chosen from a dropdown.
- Menu bar pill redesigned as a dark capsule with a colored progress segment.
- New "Quit App" button in the popover.

### For users

#### Added

- **DMG download** on the [releases page](https://git.krohn.io/karsten/llm-budget-tracker/-/releases). The app is not
  notarized; allow the first launch under System Settings → Privacy & Security → `Open Anyway`.
- **Quit App** button next to "Settings" in the popover header.
- **"This week" and "Last week"** ranges in the per-model spend breakdown. Weeks always run Monday to Sunday,
  independent of your locale; "Last week" is the previous calendar week. All ranges are based on UTC, like the
  daily API data.
- **"Today"** range in the per-model spend breakdown, showing the current UTC day.
- **"Yesterday"** range in the per-model spend breakdown, showing the previous UTC day.
- **"Last month"** range in the per-model spend breakdown, showing the previous calendar month. It replaces
  "Last 28 days"; if that range was selected, the breakdown falls back to "This month".
- **Budget limits from all levels:** besides the user (`/v2/user/info`) and team-member (`/team/{id}/members/me`)
  budgets, the app now also considers the key's own budget (`/key/info`) and the team budget (`/team/info`).
  If several limits are set, the lowest one is used, together with the spend, reset time and duration of that level.
- **Keep the saved API key:** if an API key is already stored, you can change only the proxy URL and leave the API key
  field empty. "Test Connection" then uses the saved key, and "Save" keeps it unchanged. A hint below the field
  explains this.

#### Changed

- **New bundle ID `io.krohn.llm-budget-tracker`** (was `com.ilja82.llm-budget-tracker`). macOS treats it as a new app:
  settings, the API key in the Keychain and `Launch at Login` from the old app are not carried over, so set them up
  again.
- **Range dropdown:** the per-model spend breakdown picks its range from a dropdown (like "All Models") instead of
  segmented tabs, grouped into days, weeks and months.
- **Menu bar pill:** dark capsule with an inner segment tinted in the pacing color; the solid part shows the budget
  used.
- **Per-model breakdown layout:** each model name sits directly above its bar, with more space between models.
- **Better readability in light and dark mode:** colored text (remaining budget, status pill, "Optimum" label) uses
  darker shades in light mode and lighter shades in dark mode; secondary hints like "Resets in" use higher contrast;
  the daily-spend hint box adapts to the appearance instead of a fixed dark overlay; dropdowns and pickers are no
  longer dimmed.
- **No budget limit is no longer an error.** Instead of "No budget found", the popover shows your spend so far and
  explains that remaining budget and pacing require a limit. The menu bar tooltip reads "Used: … / No budget limit
  configured."
- **Daily activity charts no longer require a budget reset date** and are also available without a budget limit.
- **"All Models" filter:** the model menu above the daily activity chart now uses the same bordered style as the
  "Spend / Tokens / Requests" control and shows a single chevron instead of two.
- **VoiceOver:** without a budget limit, the menu bar item is announced as "Used …, no budget limit" instead of
  "No budget available".
- **Fresh numbers when opening the popover:** if the data is older than 5 minutes, opening the popover refreshes it.
  The regular refresh interval keeps the menu bar up to date in the background and now restarts after every
  successful refresh, so "Next refresh in" stays accurate.
- **Visible refresh:** while a refresh runs, a highlight sweeps across the menu bar pill and the "Refresh now" icon
  in the popover footer is replaced by an animated loading icon.
- **Softer red for "Likely to exceed":** the menu bar bar and budget card use a muted red instead of the bright system
  red.

#### Fixed

- A team membership without its own budget could produce a zero-spend row that hid the real budget; such rows are now
  ignored.
- The IPv6 loopback address `http://[::1]` is now accepted as a local proxy URL.
- Proxy URLs without a host are now rejected.

### For developers

#### Added

- **Unit test target `LLMBudgetTrackerTests`** with suites for budget usage, connection settings, daily activity,
  endpoint security, model ranges and response sanitizing. Tests use mocked Keychain access and API responses; no real
  credentials or network access are needed. The scheme collects code coverage.
- **`TeamInfo.swift`:** decoding of `GET /team/info` (team-level budget).
- **`ConnectionSettings.swift`:** testable form logic for the connection settings (form validation, which API key is
  used for testing, whether a key is saved).
- **`limits_found`** field in the Developer Mode request log, listing every limit that was found,
  e.g. `/key/info: $25.00, /v2/user/info: $100.00`.
- **GitLab CI (`.gitlab-ci.yml`)** with a `lint` job (`swiftlint lint --strict`) and a `test` job (`xcodegen generate`,
  then `xcodebuild test` without code signing). It runs on pushes and merge requests on a macOS shell runner tagged
  `macos`.
- **Release job:** pushing a tag `vX.Y.Z` runs `scripts/publish-release.sh` in CI. It builds the app, packages it as a
  DMG, uploads it to the generic package registry and creates a GitLab release with the version's CHANGELOG section as
  notes. The tag must match `MARKETING_VERSION` in `project.yml`.

#### Changed

- **`APIService.fetchResolvedBudgetInfo`** collects all sources with a limit as candidates and picks the lowest
  (`min(by:)` keeps the first of equal limits, so the more specific source wins ties). HTTP and decoding failures mark a
  source as unavailable via the new `bestEffort` helper; transport errors and cancellation still propagate. If no
  source has a limit, user-level usage is returned; if that also fails, its error is surfaced. A `/team/info` response
  without `team_info` fails decoding and is skipped.
- **`APIService.init`** accepts a `URLSessionConfiguration` (default `.ephemeral`) so tests can inject a mock protocol.
- **`KeyInfoDetails`** now also decodes `user_id`, `spend`, `max_budget`, `budget_duration` and `budget_reset_at`
  (leniently, so an unexpected shape never hides the team attachment). `KeyInfoFetch` exposes `details` instead of
  `teamId`; `teamId` remains as a computed property.
- **`BudgetFetchResult`** has a new `limitSources` field.
- **`BudgetInfo`** gained `hasBudgetLimit`, `canLoadDailyActivity` and `withUserId(_:)`.
- **`BudgetViewModel`:** `.noBudget` is now set after a regular load (budget info and daily activity are kept)
  instead of clearing the data; pacing stays `nil` without a limit. `StatsView` renders `.noBudget` like `.loaded`.
  Daily activity is gated on `canLoadDailyActivity` (a known user ID) instead of `budgetResetAt`.
- **Date ranges moved into `ModelRange.dateRange(relativeTo:)`** in `ChartSelection.swift`. It returns a half-open UTC
  `Range<String>` (`yyyy-MM-dd`) instead of a start-only cutoff, which is needed for "Last week".
  `modelGroupSpendTotals(range:)` in `BudgetViewModelSupport.swift` now only uses this range.
- **`EndpointSecurity`:** the loopback allow list contains `[::1]` (the host as reported by `URLComponents`), and
  empty hosts are rejected.
- **SwiftLint** now also lints `LLMBudgetTrackerTests`.
- **Repository moved** to `git.krohn.io/karsten/llm-budget-tracker`.

#### Removed

- **GitHub Actions workflows** (build, PR checks, CodeQL) and the Dependabot config. Releases are built by the GitLab
  release job instead and are no longer signed with a Developer ID or notarized.
- **Homebrew install** from `ilja82/tap`; that cask ships the upstream app without these changes.

[Unreleased]: https://git.krohn.io/karsten/llm-budget-tracker/-/compare/v0.1.0...main
[0.1.0]: https://git.krohn.io/karsten/llm-budget-tracker/-/compare/v0.0.8...v0.1.0

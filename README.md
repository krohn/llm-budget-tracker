# LLM Budget Tracker

The LLM Budget Tracker is a macOS application that sits in your status bar and monitors your LiteLLM budget usage. It retrieves your budget from your
LiteLLM proxy and displays daily activity charts.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)

## What it does

- Shows current budget usage directly in the macOS status bar.
- Colors the menu bar progress indicator based on pacing status.
- Opens a popover with remaining budget, reset timing, projected spend, and pacing details.
- Optionally loads daily activity data for spend, token usage, and request success/failure charts, filterable by model.
- Breaks down spend per model for "Today", "Yesterday", "This week", "Last week", "This month", and "Last month" (weeks run Monday to Sunday).
  Like the daily API data, these ranges are based on UTC.
- Shows spend even without a configured budget limit. Remaining budget and projections require a limit;
  daily charts require neither a limit nor a budget reset time.
- Resolves the budget limit across all available levels: key (`/key/info`), team member (`/team/{id}/members/me`),
  team (`/team/info`), and user (`/v2/user/info`). If several limits are set, the lowest one applies; spend, reset time,
  and duration come from the same level. On equal limits, the level listed first wins. Levels without a limit or without
  access are skipped. In the Developer Mode request log, `limits_found` shows which limits were found.
- If no limit is found, the user data (spend) is shown.
- Checks for a newer release, on demand via `Check Now` in Settings and, if `Check for updates daily` is on
  (default), at launch and once a day. A newer version is shown in Settings and in the popover footer, with a link to
  its release page. The check asks the public GitLab API of git.krohn.io for the latest release tag; nothing else is
  sent.

## Install the app

Download the DMG of the latest version from the
[releases page](https://git.krohn.io/karsten/llm-budget-tracker/-/releases), open it and drag `LLMBudgetTracker.app`
into `Applications`.

The app is not notarized, so macOS blocks the first launch. Allow it once under System Settings → Privacy & Security →
`Open Anyway`, or remove the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/LLMBudgetTracker.app
```

You can also build the app yourself, see [Build from source](#build-from-source).

## Run the app

Open the installed app `LLMBudgetTracker.app` using Spotlight (`⌘` + `SPACE`). The app will then appear in the menu bar.
To quit the app, click `Quit App` in the popover.

## Configure the app

Click the menu bar item, then open Settings.

* Enter your LiteLLM proxy URL and API key, test the connection.
* Activate `Launch at Login` if you want the app to start automatically on system startup.
* Save the settings.
* If an API key is already saved, you can change only the URL and leave the API key field empty.
  `Test Connection` then uses the saved key, and `Save` keeps it unchanged.
  Only enter a new key if you want to replace the existing one.
* Use HTTPS for remote proxies. HTTP is only allowed for local loopback addresses.

## Build from source

A full Xcode installation is required (not just the Command Line Tools).

```bash
# 1. Clone
git clone https://git.krohn.io/karsten/llm-budget-tracker.git
cd llm-budget-tracker

# 2. Install XcodeGen and additional tools (if not already installed)
brew install xcodegen swiftlint

# 3. Generate the Xcode project
xcodegen generate

# 4. Open in Xcode and run
open LLMBudgetTracker.xcodeproj
```

In Xcode run `⌘` + `R` to build and run the app.

## Tests

The unit tests cover connection settings, endpoint security, response sanitizing, budget data, daily activity, and
analysis ranges, using mocked Keychain access and API responses, without real credentials or external services.

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -scheme LLMBudgetTracker -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

GitLab CI (`.gitlab-ci.yml`) runs SwiftLint and the unit tests on every push and merge request. The jobs need a macOS
shell runner with Xcode, tagged `macos`.

## Release

Bump `MARKETING_VERSION` in `project.yml`, add the version's section to `CHANGELOG.md`, then run
`./scripts/release.sh` on `main`. It pushes the tag `vX.Y.Z`; the `release` CI job then builds the app, packages it as
a DMG, uploads it to the package registry and creates the GitLab release with the version's CHANGELOG section as notes.

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.

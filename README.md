# Catch

A native iOS idea-capture app (SwiftUI, iOS 17+). The design spec lives in
[`design_handoff_catch_ios/`](design_handoff_catch_ios/README.md).

## Building (macOS)

The Xcode project is generated from `project.yml` and isn't checked in.

```sh
brew install xcodegen
xcodegen generate
open Catch.xcodeproj
```

Run `xcodegen generate` again after adding or removing files.

Debug runs from Xcode pass `-seedSampleData`, which fills an empty database with
the prototype's demo items, projects and places. To start over, delete the app
from the simulator.

### Running on an iPhone

The app and its widget extension share data through the App Group
`group.com.buildmonkeys.catch`, which needs a signing team:

1. `DEVELOPMENT_TEAM` in `project.yml` is set to the team (`S7G8QLJ85J`).
2. Run `xcodegen generate` and build to your phone. Xcode registers the App
   Group with automatic signing.

### TestFlight

`.github/workflows/testflight.yml` archives a Release build and uploads it to
App Store Connect. It only runs on demand:

```sh
gh workflow run testflight.yml --ref main
```

The build number is the workflow's run number, so every upload is new; bump
`MARKETING_VERSION` in `project.yml` for a new version. One-time setup:

1. In the Apple Developer portal, register the App IDs `com.buildmonkeys.catch`
   and `com.buildmonkeys.catch.widgets`, both with the App Group
   `group.com.buildmonkeys.catch`. (Xcode can also do this the first time it
   signs with the API key.)
2. In App Store Connect, create the app with the bundle ID
   `com.buildmonkeys.catch`.
3. In App Store Connect under Users and Access → Integrations, create an API
   key with the **Admin** role, so Xcode can create certificates and profiles
   itself. Download the `.p8` file (it can only be downloaded once).
4. Add the repo secrets `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8` (the
   whole `.p8` file, including the BEGIN and END lines).

A build appears in TestFlight 10–30 minutes after the upload. Internal testers
can install it right away; external testers need Apple's beta review first.

## What's where

| Folder | What |
|---|---|
| `Catch/Models` | SwiftData models (items, projects, steps, places) |
| `Catch/Logic` | The rules: lists and the Now limit, Up first, reminders, voice parsing, wrap-up. No UI. |
| `Catch/Settings` | Settings and their storage |
| `Catch/App` | App setup, the shared app model, root view, notifications |
| `Catch/Today`, `Inbox`, `Someday`, `Projects`, `Capture`, `Sheets`, `Voice`, `Places`, `Onboarding` | Screens |
| `Catch/Intents` | Siri, App Shortcuts and the Action button |
| `Catch/Shared` | Code compiled into both the app and the widget extension |
| `CatchWidgets` | Home screen and Lock Screen widgets, the Control, the Live Activity |
| `CatchTests` | Unit tests |

## CI

`.github/workflows/ci.yml` builds, runs the tests and saves simulator
screenshots of every screen (the **Screenshots** artifact on each run). It runs
on every push to `main`, on pull requests, and on demand:

```sh
gh workflow run ci.yml --ref <branch>
```

Debug-only launch arguments open specific screens for those screenshots, for
example `-openRemind`, `-openPlaces`, `-evening`, `-voiceDemo -startVoice` and
`-widgetGallery`. See the `.task` in `RootView`.

## Check on a real iPhone

CI can't touch the screen, so these have only been checked by tests and
screenshots:

- Swipes on Now and Later rows, haptics, check-mark and sheet animations
- Hold + to talk with real speech recognition; mic and speech permissions
- Reminder notifications arriving (time and place), Done and In 1 Hour on them
- Widgets on the home screen and Lock Screen, and their buttons
- The Control (iOS 18) and the Action button listening in the Dynamic Island
- Siri phrases ("Catch a thought in Catch", "What's up first in Catch")
- VoiceOver, Reduce Motion, and larger text sizes

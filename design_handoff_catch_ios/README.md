# Handoff: Catch, a native iOS idea-capture app

## Overview
Catch is an iPhone app for getting thoughts out of your head fast and making sure the right one comes back at the right time. You capture by typing or talking, and everything is sorted into four lists:

- **Inbox**: unsorted captures land here first.
- **Now**: today, at most 3 items (the limit can be changed in Settings).
- **Later**: comes back at a set time or place, with a reminder.
- **Someday**: no date and no rush.

**Projects** group multi-step work, optionally split into phases. **Up first** suggests the single next thing to do. The **evening wrap-up** clears what's left of the day.

## About the design files
The files in this bundle are **design references made in HTML**. They show the intended look and behavior; they are not production code to copy. Rebuild them natively. **SwiftUI is recommended** (iOS 17+, for interactive widgets, App Intents and Live Activities), using system components wherever one exists: `List`, `.sheet`, `.swipeActions`, `DatePicker`, `Toggle`, `Picker(.segmented)`, `sensoryFeedback`, `ControlWidget`.

- `Catch Prototype.dc.html` is **the source of truth for behavior**. Open it in a browser. A side panel has demo switches for evening mode, error states, dark mode, text size and haptic labels.
- `Catch.dc.html` and `Catch Extras.dc.html` hold the static design explorations. Each option has an id such as `6b`; the chosen ids are listed below.
- `ios-frame.jsx` and `support.js` only exist to render the HTML. Ignore them for the build.

## Fidelity
**High fidelity.** Colors, type sizes, spacing, radii, motion and copy are final. In SwiftUI, prefer system equivalents (SF Pro, Dynamic Type text styles, system colors) over hard-coded values where they match. The hex values below are the iOS system colors.

---

## Chosen designs (screen map)
| Area | Chosen | Where |
|---|---|---|
| Home (Today) | 3a layout + Up first card (5a) that collapses into a pinned bar (5b) | Catch.dc.html, prototype |
| Capture | 2b: tap + to type, hold + to talk | prototype |
| Project detail | 6b phases timeline + progress ring | prototype |
| Reminders for Later | 6g suggested times + date picker | prototype |
| Voice capture | 6j live highlights | prototype |
| Evening wrap-up | 7a on the Today screen, plus "All to Tomorrow" | prototype |
| First launch | 8a guided first capture | prototype ("Replay First Launch") |
| Settings | 9a grouped list (+ Display: Appearance, Haptics) | prototype |
| Error/empty states | 10a–10f, all of them | Catch.dc.html, prototype |
| Places | 12a (list + editor, with suggestions at the top) | Catch Extras.dc.html |
| Home screen widget | 12b–12d (Up first layout that changes through the day) | Catch Extras.dc.html |
| Lock screen / Action button | 11f + 11g | Catch Extras.dc.html |
| Siri / Shortcuts | 11h + 11i | Catch Extras.dc.html |

---

## Screens / views

All measurements are in points on a 402 × 874 device (iPhone 16 Pro). Content starts below the status bar (58 pt).

### 1. Today (home)
- **Header**: date label (15/600, secondary; reads "Friday evening" in orange text during the wrap-up) above the large title "Today" (34/700, tracking -0.01em). Padding 8 20 12. On the right: a 40 pt round Settings button (fill tint, gear icon 22 pt, blue).
- **Up first card** (when there is a suggestion and it's not evening): margin 0 16 14, radius 22, card background, shadow `0 4 16 rgba(0,0,0,.06)`, padding 14 14 14 16.
  - Left: a 36 pt circle (blue 12% tint) with an arrow icon.
  - Middle: "Up first" (13/600 blue, nowrap), a Skip text button (13, tertiary), the task title (17/600) and the reason (12, secondary), e.g. "In Now since Tuesday · about 10 min".
  - Right: a "Start" pill (36 tall, radius 18, blue, white 15/600). It opens Focus.
- **All clear card** (no suggestion): a green check in a 60 pt tinted circle, "Today is clear" (22/700), "N done. Nothing left in Now and no project steps waiting." Then "Sort Inbox (N)" and "Pull from Someday" pills.
- **Section headers**: title 20/700 (Now in blue, Later in orange text, Projects in ink) and no counts: the rows are right there. Now alone shows "Full" on the right (13, secondary, nowrap) when it's at `maxNow`, since that's why sorting into it is refused. Padding 20 36 8.
- **Now and Later order**: open items first, then done ones (oldest first), like a Notes checklist. A row checked off stays put for 0.7 s, then slides down. From 3 done, they fold into one "N done" row (grey check, chevron) that shows or hides them on tap.
- **List cards**: margin 0 16, radius 20, padding-left 16, overflow hidden.
  - Rows have padding 11 16 11 0 and a 1 pt separator (`sep`) that starts at the text inset.
  - A row has a 24 pt check circle (1.5 pt border in `ink4`, filled blue for Now or orange for Later when done), the title at 17, and an optional note line (13, secondary, one line).
  - Later rows also show the time at the end (15, orange text). It is tappable and opens the Remind sheet. When notifications are off, a crossed-out bell icon shows next to the time.
- **Projects**:
  - Header: "Projects" with a 36 pt round + button (blue 12% tint), labelled "New Project".
  - Project row: progress ring (26 pt, conic fill in blue, green at 100%), name (17/600), "2 of 5", and a 44 pt chevron button that expands the steps inline. Tapping the name opens Project Detail.
  - Inline steps: indented 38 pt so they line up with the project name. They have a 20 pt circle and 15 pt text, and the next step is shown at 600 weight with a "Next" chip (12/600 blue on a 12% tint, radius 8).
  - Empty state: a "Start a project · For anything with more than one step" row.
- **Floating tab bar**: left 20, right 96, bottom 30, height 62, radius 31, background `bar` with a 20 pt blur, shadow `0 8 24 rgba(0,0,0,.12)`, inner 1 pt edge `barEdge`. Three tabs (Today, Inbox, Someday). Each has a 22 pt icon and an 11 pt label; the active tab gets a 52 pt pill in a 12% blue tint with blue text. Inbox shows a red count badge.
- **Capture button (+)**: 62 pt circle, blue, at right 20 / bottom 30, shadow `0 8 24 rgba(0,122,255,.35)`. Tap opens the Capture sheet; hold for 380 ms starts voice.
- **Pinned Up first bar**: left 16, right 16, bottom 104, radius 22, `bar` background with blur. It shows "Up first" (12/600 blue), the title (16/600, one line), Skip, and a 40 pt blue check button.
  - It appears when Today is scrolled more than 150 pt, on other tabs, and on Project Detail.
  - It is hidden during the wrap-up, onboarding, any sheet, and voice capture.
  - It animates in by sliding up 24 pt and fading, over 0.28 s with `cubic-bezier(.2,.8,.2,1)`.

### 2. Capture sheet (tap +)
A bottom sheet with radius 38 at the top, `bg` background, padding 8 16 14, and the keyboard up.
- **Header row**: a 44 pt close button (fill), the title, and a 44 pt save button (blue, at 35% opacity when empty). The title depends on the destination: "New Idea", "Add to Now", "Remind Me Later" or "Someday".
- **Text field**: 22/600 on a card, radius 20, padding 16. Placeholder "What's on your mind?".
- **Destination**: segmented control Inbox / Now / Later / Someday. Now is dimmed when full.
- **Later**: shows time chips.
- **Return**: saves and clears the field for the next idea. The hint reads "Return saves and clears for the next idea."
- **Saving to a full Now**: the item goes to Inbox, with the toast "Now is full. Saved to Inbox".

### 3. Voice capture (hold +)
A white sheet with a red "Listening" label, a timer and a live transcript (28/600).
- **Highlighting while you talk**:
  - Filler words ("Remind me to", "Add", "to", "for") fade to `ink4`.
  - Times get an orange 18% tint with orange-ink text and 4 pt padding.
  - Projects get a purple 12% tint with purple text.
- **"Will save as" card**: shows the title, built from the normal words with the first letter capitalized, plus chips: "Later · Sat 10:00 AM", the project name, or "Inbox".
- **Waveform** and a footer that reads "Let go to save".
- **What happens on release**:
  - A time was heard: the item goes to Later with that time.
  - Only a project was heard: it is added as a step in that project's current phase.
  - Neither: the item goes to Inbox.
- The real build should use SFSpeechRecognizer on-device plus NSDataDetector / Foundation date parsing. Project names are fuzzy-matched against existing project names.

### 4. Inbox
- **Header**: "Inbox" (34/700) with "N to sort" under it.
- **Current item card**: radius 26, 230 tall, shadow `0 10 30 rgba(0,0,0,.08)`. It shows "Caught 8:14 AM" (13), the item text (26/600, tap to edit) and a red trash button (`trash`, 18 pt, 44 pt target, labelled "Delete").
- **Sort buttons**: three 64 pt circle buttons in a row.
  - Someday: white with a grey archive icon.
  - Later: white with an orange clock icon. Opens the Remind sheet.
  - Now: blue with a white sun icon. Opens the Swap sheet if Now is full.
- **Up next**: a list of up to 4 queued items.
- **Empty**: "Inbox is empty" card with a "Back to Today" button.

### 5. Someday
A large title with the subtitle "No dates. Look through it once a month." Each row has a "Move to Now" pill (30 tall, 12% blue tint). Empty state 10e: a grey archive icon in a 60 pt circle, "Nothing here yet", and an explanatory line.

### 6. Project Detail (6b)
- **Navigation**: back button "‹ Today".
- **Header**: a 44 pt progress ring (inner 32 pt in `bg`), the name (30/700) and "2 of 5 steps · Phase 2 of 3".
- **Phases as a vertical timeline**: a 24 pt marker column with a 2 pt connecting line.
  - Done phase: filled blue check; the line below it is blue. Shown collapsed as "Step · Step" (15, secondary) with "Done" on the right.
  - Current phase: 2 pt blue ring with a 10 pt dot, name in blue. Shown expanded in a white card (radius 18) with toggleable steps, a "Next" chip and an "Add Step" field at the bottom.
  - Upcoming phases: hollow `ink4` circle, dimmed name, "After ‹previous phase›".
  - Projects without phases show as a single "Steps" phase.

### 7. Remind sheet (6g)
- **Header**: close, "Remind Me" with the item title under it, and a blue check to save.
- **Options** (28 pt colored icon tiles):
  - This afternoon · 3:00 PM
  - After work · ‹setting› · "when you usually leave"
  - Tonight · 8:00 PM
  - When I leave the office · Halden Studio, Mill St
  - Tomorrow morning · Sat 9:00 AM
  - Pick date and time
- **Date picker**: a "‹ Suggestions" back link, 7 day chips (48 wide; the selected one is filled blue) and three wheel columns (hour 1–12, minute 00/15/30/45, AM/PM). The wheels are 36 pt rows with a 180 pt viewport, a selection band and a mask fade. A summary line reads "Saturday, October 10 at 9:00 AM". Native: use `DatePicker(.wheel)` plus a day strip.
- **"Nudge again if I miss it"**: a toggle, "Once, 30 min later". Its default comes from Settings.

### 8. Edit sheet (tap an item's text)
- **Fields**: title (22/600) and note (16, multiline, placeholder "Add a note"). Return in the title field saves.
- **List**: segmented control Inbox / Now / Later / Someday. Now is disabled when full, and tapping it shows the toast "Now is full (3). Move something out first".
- **Later**: a "Remind me ‹time chip› ›" row that opens the Remind sheet.
- **Also shown**: "Caught today at ‹time›" and a "Delete Item" button (red text on a card). Deleting can be undone.

### 9. New Project sheet
- **Fields**: name (22/600, placeholder "Project name") and a Steps card listing the steps, each with a remove button.
- **Steps**: the first step is marked "Next". The "Add a step" field adds a step on Return.
- **Add a Phase**: inserts a heading (13/700 uppercase blue, editable), named Plan → Do → Finish by default. Steps after a heading belong to it.
- **Add from your Inbox**: up to 4 Inbox items as chips. Tapping one adds it as a step, and it leaves the Inbox when the project is created.
- **Creating**: the check is dimmed until the project has a name. Creating opens Project Detail, with the toast "Created ‹name›" and Undo. A project with no steps gets the placeholder step "Decide the first step".

### 10. Swap sheet (Now is full, 10d)
"Now holds 3 things" / "To add “X”, move one out. It goes back to Inbox." A radio list of the open Now items (the last one is preselected; selected uses an orange fill), a Swap button, and "Keep It in Inbox/Someday/Later".

### 11. Evening wrap-up (7a)
From the wrap-up time (default 9:00 PM):
- The Up first card is replaced by an evening card: a moon in an orange tint, "2 left for today" / "Move them on, then finish the day", and a Finish pill (orange tint with orange text).
- Now rows each get a Tomorrow | Someday segmented button.
- The Now header shows "All to Tomorrow" (15/600 blue).
- Below Now: a "N done today" row and an Inbox card reading "N new ideas · Can wait until tomorrow".
- **Finish** moves the leftovers to tomorrow. The card then reads "Day finished · Good night. Up first is ready in the morning."
- Items moved to tomorrow come back the next day with the reason "Carried over from last night".

### 12. First launch (8a)
1. **Welcome**: a 96 pt app icon, "Catch" (40/700), the line "Say or type whatever's on your mind…", a "Try It" button, and "Takes about a minute. No account needed."
2. **Step 1 of 3**: Today is dimmed with a radial spotlight around + and a coach bubble (#1c1c1e, radius 18): "Hold + and say something you need to do". A plain tap shows "Hold it down to talk".
3. **Step 2 of 3**: a coach bubble over the voice sheet. Once a time is heard: "Orange means a time / Catch heard 'tomorrow at 10' and will remind you then. Let go to save." Letting go before a time is heard goes back to step 1.
4. **Step 3 of 3**: a pre-permission sheet, "Remind you Saturday at 10?", with "Turn On Reminders" (then the system prompt) and "Not Now" (turns notifications off and shows the 10c banner).

### 13. Settings (9a)
A page sheet (radius 14) with a round blue check button to close.

| Group | Rows |
|---|---|
| Reminders | Notifications (toggle) · Nudge again if missed (toggle) · "After work" means (5:00 / 5:30 / 6:00 PM) |
| Evening wrap-up | Time · Style (On Today / Off) |
| Today | Max in Now (stepper, 1–5) · Up first includes project steps (toggle) |
| Display | Appearance (System / Light / Dark, segmented; default System) · Haptics (toggle, default on) |
| Places | Home · Office (opens Places, 12a) |
| Capture | Voice language · Action button |
| — | Replay the Tutorial |

### 14. Error and empty states (10a–10f)
- **10a No mic access**: a sheet with a red mic-off icon, "Catch can't use the mic", "Open iOS Settings" and "Type Instead" (opens the Capture sheet).
- **10b Not understood**: "Didn't catch all of that". The gap is an inline editable field in the sentence, with Try Again, Save / Save as Is, and Discard. Nothing is saved until the user chooses.
- **10c Notifications off**: an orange-tinted banner above Later, "Reminders are off / These won't alert you…", with a Turn On button. Each time shows a muted bell.
- **10d Now is full**: see the Swap sheet above.
- **10e Empty Someday** and **10f All done**: see the Someday and Today sections above.

### 15. Extras (Catch Extras.dc.html)
- **Places (12a)**:
  - The list shows Home and Office, each with a name, address and radius, plus "Add Place".
  - When Catch notices a regular place, a "Catch noticed" card appears at the top with name chips, "Save as Gym" and "Not Now".
  - Settings: "Offer When I leave / When I arrive" and "Suggest places". Footer: "Locations stay on this iPhone." The place editor has a map, name, address, a radius slider (100–300 m) and Remove Place.
- **Widget (12b–12d)**: small and medium interactive widgets (AppIntents) that change over the day:
  - Morning: Up first with Done / Skip.
  - When a Later item is due: that reminder with Done / "In 1 hour".
  - From the wrap-up time: "2 left for today" with To Tomorrow / Review.
  - Use a `TimelineProvider` with entries at those boundaries.
- **Lock screen (11f)**: a circular mic widget, a rectangular Up first widget and a circular Inbox count, plus a `ControlWidget` that can replace the flashlight.
- **Action button (11g)**: an App Intent. Hold to listen in a Live Activity / Dynamic Island with the same highlighting, release to save. It confirms "Saved to Later · Sat 10 AM" with Undo.
- **Siri (11h) / App Shortcuts (11i)**:
  - Catch a thought — “Catch call Dana tomorrow”
  - What's up first? — “What's up first in Catch”
  - Add to Now — “Add buy milk to Now in Catch”
  - Wrap up my day — “Wrap up my day in Catch”
  - Read my Now list — “What's in my Now list”
  - Sort my Inbox — “Sort my Catch Inbox”
  - Siri shows a snippet card with Saved, the title, a destination chip, Undo and Open Catch.

---

## Interactions & behavior

### Up first algorithm
1. Build the candidates in order: open Now items (not done, not moved to tomorrow), then each project's first unfinished step, if "Up first includes project steps" is on.
2. Return the first candidate that isn't in `skipped`. Skip adds the current one to `skipped`; once every candidate has been skipped, `skipped` resets.
3. Reason strings:
   - The item's stored reason ("In Now since Tuesday · about 10 min", "Sorted into Now from Inbox", "Moved up from Later", "Carried over from last night").
   - "Next step in ‹Project›".
   - "First open item in Now".
4. Start opens Focus: a full-screen white view with the reason, the title (36/700), an elapsed timer (64/300 blue, tabular figures), "Mark Done" and "Not Now" (which skips).

### Swipe actions (Now and Later rows)
- Right swipe: Done (green). If the item is already done, the action reads "Undo".
- Left swipe on a Now row: "Later" (orange). Opens the Remind sheet.
- Left swipe on a Later row: "Now" (blue). Moves it to Now, or opens the Swap sheet if Now is full.
- The action triggers past 90 pt (the label scales to 1.12 and there is a Light haptic). Below that, the row springs back.
- Native: `.swipeActions(edge:allowsFullSwipe: true)`.

### Toasts
A toast slides in at the top (top 60, radius 22, `rgba(30,30,32,.92)`, white 15/500, green check) and auto-hides after 3.2 s. **Every destructive or moving action can be undone** from its toast: done, delete, swap, move, all-to-tomorrow, reminder set, project created, step added.

### Motion
Under Reduce Motion, all animations below are replaced by instant changes or cross-fades.

| What | Duration | Curve |
|---|---|---|
| Sheets rise from the bottom | 0.34 s | `cubic-bezier(.2,.8,.2,1)` |
| Backdrops fade in | 0.25 s | |
| New rows (fade + 6 pt rise) | 0.30 s | |
| Toasts (from −12 pt, scale .96) | 0.30 s | |
| Check mark (scale .4 → 1, overshoot) | 0.30 s | `cubic-bezier(.3,1.7,.5,1)` |
| Check circle fill | 0.20 s | |
| Row snap-back after a swipe | 0.30 s | |
| Pinned bar | 0.28 s | |

### Haptics (`sensoryFeedback`)
Users can turn haptics off in Settings → Display → Haptics.

| Event | Haptic |
|---|---|
| Swipe passes the threshold | `.impact(.light)` |
| Item or Up first done | `.success` |
| Voice starts (hold +) | `.impact(.medium)` |
| Now full, delete, missing project name | `.warning` |
| Picker ticks, day chips, segmented controls, appearance | `.selection` |
| Reminder saved, edit saved, phase added, Inbox chip added | `.impact(.light)` |

### Validation and limits
- Now holds at most `maxNow` open items (default 3, range 1–5). The limit is enforced in capture, sort, edit, Someday and Later.
- An item title can't be empty: edit falls back to the previous title.
- A project name is required.
- A Later item always has a `when`; it defaults to the "After work" time.

---

## State / data model
```swift
enum ListKind { case inbox, now, later, someday }
struct Item { id, text, note?, list: ListKind, done: Bool, when: ReminderTime?,
              nudge: Bool?, reason: String?, capturedAt: Date, movedToTomorrow: Bool }
struct Project { id, name, isExpanded: Bool, steps: [Step] }      // order = priority
struct Step { id, text, done: Bool, phase: String }               // phase order = first appearance
struct Place { id, name, address, coordinate, radiusMeters }
struct Settings { notifications, nudgeDefault, afterWork: Time, wrapUpTime: Time,
                  wrapUpStyle: .onToday/.off, maxNow: 1...5, upFirstIncludesSteps,
                  appearance: .system/.light/.dark, haptics, suggestPlaces,
                  offerLeave, offerArrive, voiceLanguage, actionButton }
```
- **Local-first.** SwiftData plus iCloud sync later. Location stays on device.
- **ReminderTime** is either a date-time or a place trigger (`leave` / `arrive` + Place). Use UNCalendarNotificationTrigger or UNLocationNotificationTrigger.
- **Nudge** re-fires once, 30 min after the first alert. An ignored Later reminder then moves into Now.
- **Transient UI state**: tab, scrolled, skipped, and which sheet is open (capture, voice, remind with its picker values, edit draft, new project draft, swap, settings).

## Design tokens
| Token | Light | Dark | Use |
|---|---|---|---|
| bg | #F2F2F7 | #000000 | grouped background |
| card | #FFFFFF | #1C1C1E | cards, rows, sheets |
| ink | #000000 | #FFFFFF | primary text |
| ink2 | rgba(60,60,67,.6) | rgba(235,235,245,.6) | secondary text |
| ink3 | rgba(60,60,67,.45) | rgba(235,235,245,.42) | done text, upcoming phases |
| ink4 | rgba(60,60,67,.3) | rgba(235,235,245,.28) | check rings, chevrons, placeholders |
| sep | rgba(60,60,67,.12) | rgba(84,84,88,.6) | separators |
| fill | rgba(120,120,128,.14) | rgba(120,120,128,.3) | tinted buttons, segmented track |
| bar | rgba(255,255,255,.84) | rgba(30,30,32,.86) | tab bar, pinned bar (+20 pt blur) |
| blue | #007AFF | #0A84FF | accent, Now |
| orange | #FF9500 | #FF9F0A | Later fills and icons |
| orangeText | #C93400 | #FF9F0A | orange text (meets contrast) |
| red | #FF3B30 | #FF453A | destructive, Inbox badge |
| green | #34C759 | #30D158 | done swipe, success |
| purple | #5856D6 | #5E5CE6 | projects in voice, haptic labels |
| seg | #FFFFFF | #636366 | selected segment |

- **Tints**: blue 12% `rgba(0,122,255,.12)`, orange 14–16%, purple 12%, green 14%.
- **Type** (SF Pro, Dynamic Type):

  | Style | Size / weight | Use |
  |---|---|---|
  | Large Title | 34 / 700 | screen titles |
  | Title | 28–30 / 700 | |
  | Title 2 | 22 / 600–700 | |
  | Section | 20 / 700 | section headers |
  | Body | 17 / 400–600 | rows |
  | Callout | 15–16 | |
  | Footnote | 13 | |
  | Caption | 11–12 | |

  Every size must scale with Dynamic Type. The prototype's Text size control previews up to 130%, and buttons grow taller instead of clipping.
- **Radii**: sheets 38 (top only), page sheets 14, cards 20, Up first and pinned bar 22, Inbox card 26, round buttons are half their size, pills 18 (36 tall) and 26 (52 tall), chips 8–9, tiles 7–8.
- **Shadows**: card `0 4 16 rgba(0,0,0,.06)`, floating items `0 8 24 rgba(0,0,0,.12–.14)`, primary + `0 8 24 rgba(0,122,255,.35)`.
- **Spacing**: screen inset 16, section header inset 36, row padding 11 vertical, gaps between sections 20–22.

## Accessibility
- Small orange text uses `orangeText`. Orange buttons with labels use a tint fill with `orangeText` labels, never white on orange.
- VoiceOver:
  - Check circle: "Mark done: ‹title›".
  - Row: "‹title›, ‹time›. Double-tap to edit." Swipe actions must be exposed as `accessibilityActions`.
  - The haptic demo labels are prototype-only and should be hidden from VoiceOver.
- **Tap targets below 44 pt that need larger hit areas**:
  - remove (×) buttons in New Project (28 pt)
  - the Projects + button (30 pt)
  - segmented options
  - the Skip link on the Up first card
- Respect Reduce Motion, Increase Contrast and Bold Text.

## Assets
- No images. All icons are **SF Symbols**: `plus`, `mic.fill`, `sun.max`, `tray`, `archivebox`, `clock`, `moon`, `checkmark`, `xmark`, `gearshape`, `trash`, `bell.slash`, `mic.slash`, `location`, `house`, `briefcase`, `folder`, `arrow.right`, `waveform`.
- Map areas in Places are placeholders; use MapKit.
- The app icon is in [`app-icon/`](app-icon/): two pills, a long blue one (Now) over a shorter orange one (Later), on light grey. Default, Dark and Tinted are the iOS 18 appearances. The regular icon is used at every size; Small-Default (no dots) was an option and isn't shipped.

## Files
- `Catch Prototype.dc.html`: the interactive prototype and source of truth for behavior. Side panel: Replay First Launch, Reset demo, Evening mode, Dark mode, haptic labels, Text size, Block mic, Garbled voice.
- `Catch.dc.html`: static explorations, rounds 1–10 (option ids are referenced above).
- `Catch Extras.dc.html`: rounds 11–12 (places, widgets, lock screen, Siri).
- `ios-frame.jsx` and `support.js`: render helpers for the HTML only.

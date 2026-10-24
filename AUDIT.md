# Audit checklist (2026-10-23)

Tick each item when its fix is pushed and CI is green.

## Fix first

- [x] 1. Widget reads SwiftData objects after their context is freed (`CatchWidgets/CatchWidgets.swift` `load(at:)`, since 7b40436)
- [x] 2. App version still `0.1.0`: check App Store Connect, raise `MARKETING_VERSION` before the next upload (`project.yml:10`)
- [x] 3. Going to the background during the save wait drops the capture (`AppModel.appMovedToBackground`)
- [ ] 4. A short first phrase is lost when the recognizer starts over after a pause (`TranscriptAccumulator.startedOver`)
- [ ] 5a. Siri and Action button Later captures never ask for notification permission
- [ ] 5b. Notifications turned off in iOS Settings are never noticed (no banner, alerts silently stop)
- [ ] 6. Time alerts fire at floating wall-clock time after a time zone change (`Notifications.swift:79`)
- [ ] 7. "Listening" Live Activity stays up if the app is killed mid-session (no stale date, no cleanup at launch)
- [ ] 8. Control Center button starts the mic under an open sheet, Focus or onboarding (`StartTalkingIntent`)

## Worth fixing

- [ ] 9. Voice: "remind me to book a table for two" becomes 2 PM
- [ ] 10. Voice: "after work" / "this weekend" override any other day or time said, and the other words stay in the title
- [ ] 11. Voice: a day word anywhere sets the date ("send the Friday report" → Friday)
- [ ] 12. Voice: one-word project names fuzzy-match any word ("more" → project "Move")
- [ ] 13. Undoing Finish leaves the day marked finished, so the wrap-up alert is dropped
- [ ] 14. Undo closes any open sheet, losing unrelated edits (`AppModel.undo`)
- [ ] 15. Edit sheet / Project Detail can redraw a deleted model while dismissing
- [ ] 16. Action button help shows iOS 18-only steps on iOS 17 (`SettingsPages.swift` `ActionButtonHelpView`)
- [ ] 17. Reminder sync removes all pending alerts before re-adding them, with no background time
- [ ] 18. Freeze the shipped models as `SchemaV1` with a migration plan

## Smaller

- [ ] 19. Widget Skip list never resets across days (`SharedStore.widgetSkipped`)
- [ ] 20. Widget shows an empty day when a fetch fails, instead of "Open Catch"
- [ ] 21. `addStep` reports success when the save failed
- [ ] 22. Overdue Later items move to Now in capture order, not due order
- [ ] 23. An Inbox item's note is lost when it becomes a project step
- [ ] 24. "This weekend" on Saturday after 10 AM or Sunday means next week
- [ ] 25. "Tonight at twelve" means noon
- [ ] 26. Pasting multi-line text joins the words ("Buy milkCall Dana")
- [ ] 27. Notifications toggle snaps back off with no explanation when permission is denied
- [ ] 28. Place reminders accepted with Precise Location off
- [ ] 29. Place reminders re-arm on every sync after firing
- [ ] 30. Delivered alerts stay in Notification Center after the item is done or deleted
- [ ] 31. New Project draft is discarded by a swipe down without warning
- [ ] 32. All Clear card says "no project steps waiting" when steps are only hidden from Up first
- [ ] 33. Edit sheet's list can undo a move made while it was open (overdue promotion)
- [ ] 34. Action button: a time with no title is discarded as "Didn't hear anything"
- [ ] 35. Voice stop timeout doesn't cancel the recognition task
- [ ] 36. `beginBackgroundTask` has no expiration handler (`VoiceActivityController`)
- [ ] 37. Mic can keep recording with no Live Activity after a quick second Action button press (race)
- [ ] 38. Toast Undo can become untappable when a new toast replaces an old one
- [ ] 39. CI and TestFlight don't pin the Xcode version

## Not bugs, for later

- Projects and steps can't be renamed or deleted.

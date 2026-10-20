import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

@main
struct CatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpFirstWidget()
        InboxCountWidget()
        TalkWidget()
        VoiceActivityWidget()
        if #available(iOS 18.0, *) {
            CatchControl()
        }
    }
}

// MARK: - Timeline

struct CatchEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Reads the shared database and lays out the day: now, each Later reminder
/// still to come today, the wrap-up time, and the 4 AM day change.
struct CatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> CatchEntry {
        CatchEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CatchEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let now = Date.now
        // Only the moment now, not the whole day's timeline.
        let snapshot = load(at: now).map { $0.snapshot(at: now) } ?? .unavailable
        completion(CatchEntry(date: now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CatchEntry>) -> Void) {
        let now = Date.now
        guard let day = load(at: now) else {
            // Not readable yet, as before Catch first runs: try again soon.
            completion(Timeline(entries: [CatchEntry(date: now, snapshot: .unavailable)],
                                policy: .after(now.addingTimeInterval(15 * 60))))
            return
        }
        let entries = WidgetTimeline.entryDates(now: now, items: day.items, settings: day.settings,
                                                calendar: day.calendar).map { date in
            CatchEntry(date: date, snapshot: day.snapshot(at: date))
        }
        let nextDay = DayClock.nextStart(after: now, calendar: .current)
        completion(Timeline(entries: entries, policy: .after(nextDay)))
    }

    /// Today as read from the shared store.
    private struct Day {
        /// Kept so the fetched items and projects can still be read after `load` returns.
        let context: ModelContext
        let items: [Item]
        let projects: [Project]
        let inboxCount: Int
        let settings: CatchSettings
        let calendar: Calendar

        func snapshot(at date: Date) -> WidgetSnapshot {
            WidgetTimeline.snapshot(at: date, items: items, projects: projects, settings: settings,
                                    skipped: SharedStore.widgetSkipped, calendar: calendar,
                                    formatter: ReminderFormatter(), inboxCount: inboxCount)
        }
    }

    /// Nil when the shared store can't be opened.
    private func load(at now: Date) -> Day? {
        // Read-only: only the app writes (and migrates) the shared store.
        guard let container = try? ModelContainer(for: Schema(CatchSchema.models),
                                                  configurations: ModelConfiguration(allowsSave: false)) else {
            return nil
        }
        let context = ModelContext(container)
        let calendar = Calendar.current
        // Only what's on screen today, so years of done items don't load into the widget's memory.
        let items = (try? context.fetch(WidgetTimeline.itemsDescriptor(now: now, calendar: calendar))) ?? []
        let projects = (try? context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\Project.sortOrder)]))) ?? []
        let inboxCount = (try? context.fetchCount(WidgetTimeline.inboxDescriptor())) ?? 0
        return Day(context: context, items: items, projects: projects, inboxCount: inboxCount,
                   settings: SettingsStore(defaults: SharedStore.defaults).settings, calendar: calendar)
    }
}

/// The mic button shows no data, so it never needs to read the store.
struct MicProvider: TimelineProvider {
    func placeholder(in context: Context) -> CatchEntry { CatchEntry(date: .now, snapshot: .placeholder) }
    func getSnapshot(in context: Context, completion: @escaping (CatchEntry) -> Void) {
        completion(placeholder(in: context))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CatchEntry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .never))
    }
}

// MARK: - Widgets

/// 12b–12d on the home screen; Up first on the Lock Screen (11f).
struct UpFirstWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpFirst", provider: CatchProvider()) { entry in
            UpFirstWidgetView(entry: entry)
        }
        .configurationDisplayName("Up First")
        .description("The one thing to do next. Changes through the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct UpFirstWidgetView: View {
    let entry: CatchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        CatchWidgetView(snapshot: entry.snapshot, family: family)
            .widgetURL(URL(string: "catch://today"))
            .containerBackground(for: .widget) {
                if family == .accessoryRectangular {
                    Color.clear
                } else {
                    Theme.card
                }
            }
    }
}

/// 11f: the Inbox count under the clock.
struct InboxCountWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "InboxCount", provider: CatchProvider()) { entry in
            LockScreenInboxCount(count: entry.snapshot.mode == .unavailable ? nil : entry.snapshot.inboxCount)
                .widgetURL(URL(string: "catch://inbox"))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Inbox")
        .description("How many ideas are waiting to be sorted.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// 11f: a mic button under the clock that opens Catch listening.
struct TalkWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Talk", provider: MicProvider()) { _ in
            LockScreenMic()
                .widgetURL(URL(string: "catch://voice"))
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Catch by Voice")
        .description("Opens Catch listening.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// 11g: listening after the Action button, on the Lock Screen and in the Dynamic Island.
struct VoiceActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VoiceActivityAttributes.self) { context in
            VoiceActivityView(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    VoiceActivityView(state: context.state)
                        .padding(.horizontal, 6)
                }
            } compactLeading: {
                IslandIcon(phase: context.state.phase, compact: true)
            } compactTrailing: {
                Text(context.state.phase.islandLabel)
                    .font(.caption.weight(.semibold))
            } minimal: {
                IslandIcon(phase: context.state.phase, compact: false)
            }
            .widgetURL(URL(string: "catch://today"))
        }
    }
}

/// The island's small icon: a red mic only while it's actually listening.
private struct IslandIcon: View {
    let phase: VoiceActivityAttributes.ContentState.Phase
    /// The compact island has room for the filled circle; the minimal one doesn't.
    let compact: Bool

    var body: some View {
        switch phase {
        case .listening:
            Image(systemName: "mic.fill").foregroundStyle(Theme.red)
        case .saved:
            Image(systemName: compact ? "checkmark.circle.fill" : "checkmark").foregroundStyle(Theme.green)
        case .nothing:
            Image(systemName: "mic.slash").foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.orange)
        }
    }
}

private extension VoiceActivityAttributes.ContentState.Phase {
    var islandLabel: String {
        switch self {
        case .listening: return "Listening"
        case .saved: return "Saved"
        case .nothing: return "Nothing heard"
        case .failed: return "Not saved"
        }
    }
}

/// 11f: a control that can replace the flashlight on the Lock Screen.
@available(iOS 18.0, *)
struct CatchControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "CatchControl") {
            // An intent with openAppWhenRun, compiled into both targets: the documented way
            // for a control to open the app and act.
            ControlWidgetButton(action: StartTalkingIntent()) {
                Label("Catch", systemImage: "mic.fill")
            }
        }
        .displayName("Catch a Thought")
        .description("Opens Catch listening.")
    }
}

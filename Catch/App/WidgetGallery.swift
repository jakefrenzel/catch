#if DEBUG
import SwiftUI
import WidgetKit

/// Draws the real widget views at widget sizes, for CI screenshots (the
/// simulator can't place widgets on a home screen from a script).
struct WidgetGallery: View {
    enum Page { case small, medium }

    let store: CatchStore
    let page: Page

    var body: some View {
        let moments = moments()
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(page == .small ? "Widgets" : "Medium Widgets")
                    .font(.largeTitle.bold())
                switch page {
                case .small:
                    LazyVGrid(columns: [GridItem(.fixed(158), spacing: 14), GridItem(.fixed(158))],
                              alignment: .leading, spacing: 14) {
                        ForEach(moments, id: \.label) { moment in
                            VStack(alignment: .leading, spacing: 6) {
                                caption(moment.label)
                                tile(moment.snapshot, family: .systemSmall)
                                    .frame(width: 158, height: 158)
                            }
                        }
                    }
                    caption("11f · Lock Screen")
                    HStack(spacing: 14) {
                        LockScreenMic()
                            .frame(width: 64, height: 64)
                        LockScreenUpFirst(snapshot: moments.first?.snapshot ?? .placeholder)
                            .frame(width: 160, height: 64)
                        LockScreenInboxCount(count: moments.first?.snapshot.inboxCount ?? 0)
                            .frame(width: 64, height: 64)
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Color.indigo.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                case .medium:
                    ForEach(moments, id: \.label) { moment in
                        caption(moment.label)
                        tile(moment.snapshot, family: .systemMedium)
                            .frame(width: 338, height: 158)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.ink2)
    }

    private func tile(_ snapshot: WidgetSnapshot, family: WidgetFamily) -> some View {
        CatchWidgetView(snapshot: snapshot, family: family)
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .cardShadow()
    }

    /// Morning, when the first Later reminder is due, and the wrap-up.
    private func moments() -> [(label: String, snapshot: WidgetSnapshot)] {
        let calendar = Calendar.current
        let items = store.allItems()
        let projects = store.projects()
        let settings = store.settings
        let later = items.filter { $0.list == .later }.compactMap(\.remindAt).min() ?? .now
        let day = calendar.startOfDay(for: later)
        let morning = day.addingTimeInterval(8.5 * 3600)
        let wrapUp = calendar.date(bySettingHour: settings.wrapUpTime.hour, minute: settings.wrapUpTime.minute,
                                   second: 0, of: day) ?? day
        func snapshot(_ date: Date) -> WidgetSnapshot {
            WidgetTimeline.snapshot(at: date, items: items, projects: projects, settings: settings,
                                    skipped: [], calendar: calendar, formatter: ReminderFormatter())
        }
        return [("12b · Morning", snapshot(morning)),
                ("12c · Later is due", snapshot(later.addingTimeInterval(60))),
                ("12d · Evening", snapshot(wrapUp.addingTimeInterval(60)))]
    }
}
#endif

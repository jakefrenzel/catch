import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Item.capturedAt) private var items: [Item]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Now items just checked off, held in place for a moment before they move down.
    @State private var settling: Set<UUID> = []
    /// The folded done items in Now are showing.
    @State private var showsDoneInNow = false

    var body: some View {
        let settings = model.settings
        let isEvening = model.isEvening
        let visible = items.filter { WrapUp.isVisibleToday($0, now: model.now, calendar: .current) }
        // In the evening, done items step aside so only what's left shows.
        let nowItems = visible.filter { $0.list == .now && !$0.movedToTomorrow && !(isEvening && $0.isDone) }
        let laterItems = visible.filter { $0.list == .later }
        let candidates = UpFirst.candidates(items: items, projects: projects,
                                            includeSteps: settings.upFirstIncludesSteps)

        ScrollViewReader { proxy in
            List {
                // The inset-grouped list already adds a 16 pt margin; these rows add only the difference.
                header(isEvening: isEvening)
                    .plainListRow(EdgeInsets(top: 8, leading: 4, bottom: 12, trailing: 0))

                if isEvening {
                    EveningCard(card: eveningCard) { model.finishDay() }
                        .plainListRow(EdgeInsets(top: 0, leading: 0, bottom: 3, trailing: 0))
                } else if let upFirst = model.upFirst.current(in: candidates) {
                    UpFirstCard(candidate: upFirst,
                                onStart: { model.startFocus(on: upFirst) },
                                onSkip: { model.skipUpFirst(in: candidates) })
                        .onGeometryChange(for: Bool.self) { proxy in
                            proxy.frame(in: .global).maxY < 100
                        } action: { scrolledAway in
                            model.upFirstCardScrolledAway = scrolledAway
                        }
                        // A fast scroll can recycle the row before its last geometry
                        // update, so treat leaving the screen as scrolled away too.
                        .onDisappear {
                            // Ignore tab switches, Focus covering the screen and Project Detail.
                            if model.tab == .today && model.focus == nil && model.projectPath.isEmpty {
                                model.upFirstCardScrolledAway = true
                            }
                        }
                        .plainListRow(EdgeInsets(top: 0, leading: 0, bottom: 3, trailing: 0))
                } else if model.onboarding == nil {
                    AllClearCard(doneToday: doneTodayCount,
                                 inboxCount: items.filter { $0.list == .inbox }.count,
                                 hasSomeday: items.contains { $0.list == .someday })
                        .plainListRow(EdgeInsets(top: 0, leading: 0, bottom: 3, trailing: 0))
                }

                nowSection(nowItems, isEvening: isEvening)
                if isEvening {
                    eveningExtras
                }
                laterSection(laterItems)
                projectsSection
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            // The navigation bar is hidden, so give the status bar a backing to scroll under.
            .overlay {
                GeometryReader { geo in
                    Theme.bg
                        .frame(height: geo.safeAreaInsets.top)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .contentMargins(.top, 0, for: .scrollContent)
            // Room for the tab bar and the pinned Up first bar, so the last row can scroll clear.
            .contentMargins(.bottom, model.listBottomMargin, for: .scrollContent)
            .environment(\.defaultMinListHeaderHeight, 0)
            .navigationTitle("Today")
            .toolbar(.hidden, for: .navigationBar)
            .onDisappear {
                if model.projectPath.isEmpty { model.upFirstCardScrolledAway = false }
            }
            #if DEBUG
            .task {
                // Used by CI to screenshot the lower half of Today.
                guard ProcessInfo.processInfo.arguments.contains("-scrollToProjects"),
                      let first = projects.first else { return }
                try? await Task.sleep(for: .milliseconds(600))
                proxy.scrollTo(first.id, anchor: .top)
            }
            #endif
        }
    }

    // MARK: - Header

    private func header(isEvening: Bool) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isEvening
                     ? "\(DayClock.day(of: model.now, calendar: .current).formatted(.dateTime.weekday(.wide))) evening"
                     : model.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isEvening ? Theme.orangeText : Theme.ink2)
                Text("Today")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Button {
                model.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.blue)
                    .frame(width: 40, height: 40)
                    .background(Theme.fill, in: Circle())
                    .contentShape(Rectangle().inset(by: -2))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Settings")
            .padding(.bottom, 4)
        }
    }

    // MARK: - Now

    private func nowSection(_ nowItems: [Item], isEvening: Bool) -> some View {
        let openCount = nowItems.filter { !$0.isDone }.count
        let showsAllToTomorrow = isEvening && openCount > 0
        return Section {
            if nowItems.isEmpty {
                EmptyRow(text: isEvening ? "Nothing left in Now." : "Nothing in Now. Sort your Inbox to add some.")
            }
            // One ForEach, so a checked-off row slides down rather than vanishing and reappearing.
            ForEach(nowRows(nowItems)) { row in
                switch row {
                case .item(let item):
                    nowItemRow(item, isEvening: isEvening)
                case .doneFold(let count):
                    DoneFoldRow(count: count, isExpanded: showsDoneInNow) {
                        withAnimation(reduceMotion ? nil : .catchEaseOut(0.3)) { showsDoneInNow.toggle() }
                    }
                }
            }
        } header: {
            // Only says something when it explains why nothing more fits.
            SectionHeader(title: "Now", color: Theme.blue,
                          detail: !showsAllToTomorrow && openCount >= model.settings.maxNow ? "Full" : "") {
                if showsAllToTomorrow {
                    Button("All to Tomorrow") { model.moveAllToTomorrow() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    /// Open items first, then what's done, oldest first, like a Notes checklist.
    /// From 3 done items on, they fold into one row that opens on tap.
    private func nowRows(_ nowItems: [Item]) -> [NowRow] {
        // Just checked off: stays put for a moment so the check is seen before it moves.
        let isOpen = { (item: Item) in !item.isDone || settling.contains(item.id) }
        let open = nowItems.filter(isOpen)
        let done = nowItems.filter { !isOpen($0) }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        var rows = open.map(NowRow.item)
        if done.count >= foldDoneAt {
            rows.append(.doneFold(count: done.count))
            if showsDoneInNow { rows += done.map(NowRow.item) }
        } else {
            rows += done.map(NowRow.item)
        }
        return rows
    }

    private var foldDoneAt: Int {
        #if DEBUG
        // CI screenshots the fold with the sample data's one done item.
        if ProcessInfo.processInfo.arguments.contains("-foldDoneEarly") { return 1 }
        #endif
        return 3
    }

    private func nowItemRow(_ item: Item, isEvening: Bool) -> some View {
        let showsEveningActions = isEvening && !item.isDone
        return ItemRow(item: item, accent: Theme.blue,
                       onToggle: { toggleNowItem(item) },
                       onEdit: { model.openEditor(for: item) },
                       onTomorrow: showsEveningActions ? { model.moveToTomorrow(item) } : nil,
                       onSomeday: showsEveningActions ? { model.move(item, to: .someday) } : nil)
            .focusMenu(item.isDone ? nil : { model.startChosenFocus(.item(item)) })
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button { toggleNowItem(item) } label: {
                    Label(item.isDone ? "Undo" : "Done",
                          systemImage: item.isDone ? "arrow.uturn.backward" : "checkmark")
                }
                .tint(Theme.green)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button { model.move(item, to: .later) } label: {
                    Label("Later", systemImage: "clock")
                }
                .tint(Theme.orangeText)
            }
    }

    private func toggleNowItem(_ item: Item) {
        let finishing = !item.isDone
        model.toggleDone(item)
        guard finishing else { return }
        settling.insert(item.id)
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(reduceMotion ? nil : .catchEaseOut(0.35)) { _ = settling.remove(item.id) }
        }
    }

    // MARK: - Evening

    private var eveningCard: WrapUp.Card {
        WrapUp.card(left: items.filter(\.isOpenInNow).count,
                    movedToTomorrow: items.filter(\.movedToTomorrow).count,
                    isFinished: model.isDayFinished)
    }

    /// Under Now in the evening: what got done, and what's waiting in Inbox.
    @ViewBuilder
    private var eveningExtras: some View {
        let done = doneTodayCount
        let inboxCount = items.filter { $0.list == .inbox }.count
        if done > 0 {
            Section {
                DoneTodayRow(count: done)
            }
        }
        if inboxCount > 0 {
            Section {
                EveningInboxRow(count: inboxCount) { model.tab = .inbox }
            } header: {
                SectionHeader(title: "Inbox", color: .primary, detail: "") {
                    Button("Sort") { model.tab = .inbox }
                        .font(.subheadline)
                        .foregroundStyle(Theme.blue)
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: - Later

    private func laterSection(_ laterItems: [Item]) -> some View {
        let notificationsOn = model.settings.notifications
        return Section {
            if !notificationsOn && !laterItems.isEmpty {
                RemindersOffBanner { Task { await model.turnOnNotifications() } }
            }
            if laterItems.isEmpty {
                EmptyRow(text: "No reminders set.")
            }
            ForEach(laterItems) { item in
                ItemRow(item: item, accent: Theme.orange,
                        showsTime: true, notificationsOn: notificationsOn,
                        onToggle: { model.toggleDone(item) },
                        onEdit: { model.openEditor(for: item) },
                        onTime: { model.openReminder(for: item) })
                    .focusMenu(item.isDone ? nil : { model.startChosenFocus(.item(item)) })
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        doneSwipe(for: item)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button { model.move(item, to: .now) } label: {
                            Label("Now", systemImage: "sun.max")
                        }
                        .tint(Theme.blue)
                    }
            }
        } header: {
            SectionHeader(title: "Later", color: Theme.orangeText, detail: "")
        }
    }

    // MARK: - Projects

    private var projectsSection: some View {
        Section {
            if projects.isEmpty {
                StartProjectRow { model.openNewProject() }
            }
            ForEach(projects) { project in
                ProjectRow(project: project,
                           onOpen: { model.openProject(project) },
                           onToggleExpanded: { model.setExpanded(project, !project.isExpanded) })
                if project.isExpanded {
                    ForEach(project.orderedSteps) { step in
                        StepRow(step: step, isNext: step.id == project.nextStep?.id) {
                            model.toggleDone(step)
                        }
                        .focusMenu(step.isDone ? nil : { model.startChosenFocus(.step(step, project: project)) })
                    }
                }
            }
        } header: {
            SectionHeader(title: "Projects", color: .primary, detail: "") {
                Button {
                    model.openNewProject()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                        .frame(width: 36, height: 36)
                        .background(Theme.blueTint, in: Circle())
                        .contentShape(Rectangle().inset(by: -4))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("New Project")
            }
        }
    }

    // MARK: - Helpers

    private func doneSwipe(for item: Item) -> some View {
        Button { model.toggleDone(item) } label: {
            Label(item.isDone ? "Undo" : "Done",
                  systemImage: item.isDone ? "arrow.uturn.backward" : "checkmark")
        }
        .tint(Theme.green)
    }

    private var doneTodayCount: Int {
        items.filter { item in
            guard let completedAt = item.completedAt else { return false }
            return (item.list == .now || item.list == .later) && DayClock.isSameDay(completedAt, model.store.currentDate(), calendar: model.store.calendar)
        }.count
    }
}

// MARK: - Pieces

private struct SectionHeader<Accessory: View>: View {
    let title: String
    let color: Color
    let detail: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(color)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if !detail.isEmpty {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
            }
            accessory
        }
        .textCase(nil)
        .padding(.bottom, 2)
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(title: String, color: Color, detail: String) {
        self.init(title: title, color: color, detail: detail) { EmptyView() }
    }
}

/// A row in Now: an item, or the fold that holds what's done.
private enum NowRow: Identifiable {
    case item(Item)
    case doneFold(count: Int)

    var id: String {
        switch self {
        case .item(let item): return item.id.uuidString
        case .doneFold: return "doneFold"
        }
    }
}

/// "3 done", at the bottom of Now once enough is checked off. Tap to show or hide them.
private struct DoneFoldRow: View {
    let count: Int
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.ink4)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                Text("\(count) done")
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink4)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(count) done")
        .accessibilityHint(isExpanded ? "Hides them." : "Shows them.")
    }
}

private struct EmptyRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.ink2)
            .padding(.vertical, 4)
    }
}

private struct RemindersOffBanner: View {
    let onTurnOn: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .foregroundStyle(Theme.orangeText)
            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders are off")
                    .font(.subheadline.weight(.semibold))
                Text("These won't alert you. You'll only see them here.")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
            }
            Spacer(minLength: 8)
            Button("Turn On", action: onTurnOn)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.orangeText)
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .listRowBackground(Theme.orangeTint)
    }
}

private struct StartProjectRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .foregroundStyle(Theme.blue)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start a project")
                        .foregroundStyle(Color.primary)
                    Text("For anything with more than one step")
                        .font(.footnote)
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
    }
}

extension View {
    /// A list row with no card background or separator, for content that draws its own card.
    func plainListRow(_ insets: EdgeInsets) -> some View {
        listRowInsets(insets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

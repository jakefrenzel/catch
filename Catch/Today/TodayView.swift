import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Item.capturedAt) private var items: [Item]
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    var body: some View {
        let settings = model.settings
        let nowItems = items.filter { $0.list == .now && !$0.movedToTomorrow }
        let laterItems = items.filter { $0.list == .later }
        let candidates = UpFirst.candidates(items: items, projects: projects,
                                            includeSteps: settings.upFirstIncludesSteps)

        ScrollViewReader { proxy in
            List {
                header
                    .plainListRow(EdgeInsets(top: 8, leading: 20, bottom: 12, trailing: 16))

                if let upFirst = model.upFirst.current(in: candidates) {
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
                            // Ignore tab switches and Focus covering the screen.
                            if model.tab == .today && model.focus == nil {
                                model.upFirstCardScrolledAway = true
                            }
                        }
                        .plainListRow(EdgeInsets(top: 0, leading: 16, bottom: 14, trailing: 16))
                } else {
                    AllClearCard(doneToday: doneTodayCount,
                                 inboxCount: items.filter { $0.list == .inbox }.count,
                                 hasSomeday: items.contains { $0.list == .someday })
                        .plainListRow(EdgeInsets(top: 0, leading: 16, bottom: 14, trailing: 16))
                }

                nowSection(nowItems)
                laterSection(laterItems)
                projectsSection
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .contentMargins(.top, 0, for: .scrollContent)
            .contentMargins(.bottom, 120, for: .scrollContent)
            .environment(\.defaultMinListHeaderHeight, 0)
            .onDisappear { model.upFirstCardScrolledAway = false }
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

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink2)
                Text("Today")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Button {
                model.notBuiltYet("Settings")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.blue)
                    .frame(width: 36, height: 36)
                    .background(Theme.fill, in: Circle())
                    .contentShape(Rectangle().inset(by: -4))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Settings")
            .padding(.bottom, 4)
        }
    }

    // MARK: - Now

    private func nowSection(_ nowItems: [Item]) -> some View {
        let openCount = nowItems.filter { !$0.isDone }.count
        return Section {
            if nowItems.isEmpty {
                EmptyRow(text: "Nothing in Now. Sort your Inbox to add some.")
            }
            ForEach(nowItems) { item in
                ItemRow(item: item, accent: Theme.blue,
                        onToggle: { model.toggleDone(item) },
                        onEdit: { model.notBuiltYet("Editing") })
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        doneSwipe(for: item)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button { model.move(item, to: .later) } label: {
                            Label("Later", systemImage: "clock")
                        }
                        .tint(Theme.orangeText)
                    }
            }
        } header: {
            SectionHeader(title: "Now", color: Theme.blue,
                          detail: "\(openCount) of \(model.settings.maxNow) open")
        }
    }

    // MARK: - Later

    private func laterSection(_ laterItems: [Item]) -> some View {
        let notificationsOn = model.settings.notifications
        return Section {
            if !notificationsOn && !laterItems.isEmpty {
                RemindersOffBanner { model.turnOnNotifications() }
            }
            if laterItems.isEmpty {
                EmptyRow(text: "No reminders set.")
            }
            ForEach(laterItems) { item in
                ItemRow(item: item, accent: Theme.orange,
                        showsTime: true, notificationsOn: notificationsOn,
                        onToggle: { model.toggleDone(item) },
                        onEdit: { model.notBuiltYet("Editing") },
                        onTime: { model.notBuiltYet("Reminders") })
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
            SectionHeader(title: "Later", color: Theme.orangeText,
                          detail: "\(laterItems.filter { !$0.isDone }.count)")
        }
    }

    // MARK: - Projects

    private var projectsSection: some View {
        Section {
            if projects.isEmpty {
                StartProjectRow { model.notBuiltYet("New Project") }
            }
            ForEach(projects) { project in
                ProjectRow(project: project,
                           onOpen: { model.notBuiltYet("Project Detail") },
                           onToggleExpanded: { model.setExpanded(project, !project.isExpanded) })
                if project.isExpanded {
                    ForEach(project.orderedSteps) { step in
                        StepRow(step: step, isNext: step.id == project.nextStep?.id) {
                            model.toggleDone(step)
                        }
                    }
                }
            }
        } header: {
            SectionHeader(title: "Projects", color: .primary, detail: "\(projects.count)") {
                Button {
                    model.notBuiltYet("New Project")
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                        .frame(width: 30, height: 30)
                        .background(Theme.blueTint, in: Circle())
                        .contentShape(Rectangle().inset(by: -7))
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
            return (item.list == .now || item.list == .later) && Calendar.current.isDateInToday(completedAt)
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
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Theme.ink2)
                .lineLimit(1)
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

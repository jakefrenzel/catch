import SwiftData
import SwiftUI

/// The tab content plus the floating chrome: tab bar, + button, pinned Up first bar and toasts.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Item.capturedAt) private var items: [Item]
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    var body: some View {
        @Bindable var model = model
        let candidates = UpFirst.candidates(items: items, projects: projects,
                                            includeSteps: model.settings.upFirstIncludesSteps)
        let upFirst = model.upFirst.current(in: candidates)

        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            switch model.tab {
            case .today: TodayView()
            case .inbox: PlaceholderScreen(title: "Inbox", subtitle: "Sorting comes next.")
            case .someday: PlaceholderScreen(title: "Someday", subtitle: "No dates. Look through it once a month.")
            }

            VStack(spacing: 12) {
                if let upFirst, model.showsPinnedUpFirst {
                    PinnedUpFirstBar(candidate: upFirst,
                                     onDone: { model.complete(upFirst) },
                                     onSkip: { model.skipUpFirst(in: candidates) })
                        .padding(.horizontal, 16)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
                HStack(spacing: 14) {
                    FloatingTabBar(selection: $model.tab,
                                   inboxCount: items.filter { $0.list == .inbox }.count)
                    CaptureButton(onTap: { model.notBuiltYet("Capture") },
                                  onHold: { model.notBuiltYet("Voice capture") })
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 8)
            .animation(reduceMotion ? nil : .catchEaseOut(0.28), value: model.showsPinnedUpFirst && upFirst != nil)
        }
        .overlay(alignment: .top) {
            if let toast = model.toast {
                ToastView(toast: toast, onUndo: { model.undo() })
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .catchEaseOut(0.3), value: model.toast)
        .fullScreenCover(item: $model.focus) { candidate in
            FocusView(candidate: candidate,
                      onDone: { model.finishFocus() },
                      onNotNow: { model.skipFocus(in: candidates) },
                      onClose: { model.focus = nil })
        }
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch model.settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

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
            case .inbox: InboxView()
            case .someday: SomedayView()
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
                    CaptureButton(onTap: { model.isCaptureOpen = true },
                                  onHold: { model.notBuiltYet("Voice capture") })
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 8)
            .animation(reduceMotion ? nil : .catchEaseOut(0.28), value: model.showsPinnedUpFirst && upFirst != nil)
        }
        .background(ToastWindowInstaller(model: model))
        .sheet(isPresented: $model.isCaptureOpen) {
            CaptureSheet()
        }
        .fullScreenCover(item: $model.focus) { candidate in
            FocusView(candidate: candidate,
                      onDone: { model.finishFocus() },
                      onNotNow: { model.skipFocus(in: candidates) },
                      onClose: { model.focus = nil })
        }
        .preferredColorScheme(colorScheme)
        #if DEBUG
        .task {
            // Used by CI to screenshot the capture sheet and a toast.
            let arguments = ProcessInfo.processInfo.arguments
            try? await Task.sleep(for: .milliseconds(500))
            if arguments.contains("-showInbox") { model.tab = .inbox }
            if arguments.contains("-showSomeday") { model.tab = .someday }
            if arguments.contains("-openCapture") { model.isCaptureOpen = true }
            if arguments.contains("-sampleToast") {
                try? await Task.sleep(for: .seconds(4))  // still showing when CI captures at 6 s
                model.flash("Saved to Inbox", undo: false)
            }
        }
        #endif
    }

    private var colorScheme: ColorScheme? {
        switch model.settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

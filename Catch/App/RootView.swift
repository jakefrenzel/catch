import SwiftData
import SwiftUI
import UIKit

/// The tab content plus the floating chrome: tab bar, + button, pinned Up first bar and toasts.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Query(sort: \Item.capturedAt) private var items: [Item]
    @Query(sort: \Project.sortOrder) private var projects: [Project]

    var body: some View {
        @Bindable var model = model
        let candidates = UpFirst.candidates(items: items, projects: projects,
                                            includeSteps: model.settings.upFirstIncludesSteps)
        let upFirst = model.upFirst.current(in: candidates)

        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            Group {
                switch model.tab {
                case .today:
                    NavigationStack(path: $model.projectPath) {
                        TodayView()
                            .navigationDestination(for: Project.self) { project in
                                ProjectDetailView(project: project)
                            }
                    }
                case .inbox: InboxView()
                case .someday: SomedayView()
                }
            }
            .disabled(model.onboarding != nil)

            if model.onboarding == .hold {
                // Step 1 dims everything but + (which sits above this layer).
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            VStack(spacing: 12) {
                if model.onboarding == .hold {
                    OnboardingHoldPrompt { model.skipOnboarding() }
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                }
                if let upFirst, model.showsPinnedUpFirst {
                    PinnedUpFirstBar(candidate: upFirst,
                                     onDone: { model.complete(upFirst) },
                                     onSkip: { model.skipUpFirst(in: candidates) },
                                     onHide: { model.hidePinnedUpFirst() })
                        .padding(.horizontal, 16)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
                HStack(spacing: 14) {
                    FloatingTabBar(selection: $model.tab,
                                   inboxCount: items.filter { $0.list == .inbox }.count)
                        // Dimmed like the rest of the app, but solid, so rows don't show through.
                        .overlay {
                            if model.onboarding == .hold {
                                Capsule().fill(Color.black.opacity(0.55)).allowsHitTesting(false)
                            }
                        }
                        .disabled(model.onboarding != nil)
                    CaptureButton(onTap: {
                                      if model.onboarding == .hold {
                                          model.tapCaptureDuringOnboarding()
                                      } else {
                                          model.isCaptureOpen = true
                                      }
                                  },
                                  onHoldStart: { model.startListening() },
                                  onHoldEnd: { save in Task { await model.stopListening(save: save) } })
                }
                .padding(.horizontal, 20)
            }
            // 30 pt from the bottom edge, as in the handoff, on every iPhone.
            .padding(.bottom, 30)
            .ignoresSafeArea(.container, edges: .bottom)
            // Stay at the bottom behind the keyboard instead of riding up over text fields.
            .ignoresSafeArea(.keyboard)
            .animation(reduceMotion ? nil : .catchEaseOut(0.28), value: model.showsPinnedUpFirst && upFirst != nil)
        }
        .overlay(alignment: .bottom) {
            if model.isListening {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    VoiceSheet(startedAt: model.listeningStartedAt)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                    if model.onboarding == .talk {
                        OnboardingTalkCoach()
                            .frame(maxHeight: .infinity, alignment: .top)
                            .padding(.top, 96)
                            .padding(.horizontal, 20)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                // VoiceOver stays in the sheet and starts there, not in the app behind it.
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .onAppear { UIAccessibility.post(notification: .screenChanged, argument: nil) }
                // The finger is still on +; only VoiceOver and tap-to-talk need to touch the sheet.
                .allowsHitTesting(voiceOverEnabled || model.isTapToTalk)
            }
        }
        .animation(reduceMotion ? nil : .catchEaseOut(0.34), value: model.isListening)
        // Tap +: the capture card, docked on the keyboard, over a backdrop that closes it.
        .overlay {
            if model.isCaptureOpen {
                Button { model.isCaptureOpen = false } label: {
                    Color.black.opacity(0.22).ignoresSafeArea()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if model.isCaptureOpen {
                CaptureCard()
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .animation(reduceMotion ? nil : .catchEaseOut(0.3), value: model.isCaptureOpen)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.onboarding)
        .overlay {
            if model.onboarding == .welcome {
                WelcomeView { model.beginOnboarding() }
                    .transition(.opacity)
            }
        }
        .background(ToastWindowInstaller(model: model))
        .background(KeyboardWarmup())
        .onChange(of: upFirst?.key, initial: true) { _, key in model.currentUpFirst = key }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .edit(let item): EditSheet(item: item)
            case .remind(let item): RemindSheet(item: item, settings: model.settings)
            case .swap(let item): SwapSheet(incoming: item)
            case .newProject: NewProjectSheet()
            case .settings: SettingsSheet()
            case .micDenied: MicDeniedSheet()
            case .voiceRetry(let heard): VoiceRetrySheet(heard: heard)
            case .onboardingPermission(let date): OnboardingPermissionSheet(reminderDate: date)
            }
        }
        .fullScreenCover(item: $model.focus) { candidate in
            FocusView(candidate: candidate,
                      reason: model.focusReason(for: candidate),
                      onDone: { model.finishFocus() },
                      onNotNow: { model.skipFocus(in: candidates) },
                      onClose: { model.focus = nil })
        }
        .preferredColorScheme(colorScheme)
        .task {
            while !Task.isCancelled {
                model.refreshClock()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refreshClock()
                model.scheduleReminderSync()
            } else if phase == .background {
                model.appMovedToBackground()
            }
        }
        .onChange(of: model.settings) { old, new in
            model.settingsChanged(from: old, to: new)
        }
        .onOpenURL { model.handle($0) }
        #if DEBUG
        .overlay {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-widgetGallery") {
                WidgetGallery(store: model.store,
                              page: arguments.contains("-medium") ? .medium
                                  : arguments.contains("-activity") ? .activity : .small)
            }
        }
        #endif
        #if DEBUG
        .task {
            // Used by CI to screenshot the capture card and a toast.
            let arguments = ProcessInfo.processInfo.arguments
            try? await Task.sleep(for: .milliseconds(500))
            if arguments.contains("-evening") { model.forceEvening = true }
            if arguments.contains("-showInbox") { model.tab = .inbox }
            if arguments.contains("-showSomeday") { model.tab = .someday }
            if arguments.contains("-openCapture") { model.isCaptureOpen = true }
            if arguments.contains("-openRemind"), let item = items.first(where: { $0.list == .now }) {
                model.sheet = .remind(item)
            }
            if arguments.contains("-openEdit"), let item = items.first(where: { $0.list == .later }) {
                if arguments.contains("-longTitle") {
                    item.text = "Book dentist for Mia, and ask whether they can fit in a cleaning the same afternoon so we don't have to make two trips across town"
                }
                model.sheet = .edit(item)
            }
            if arguments.contains("-openProject"), let project = projects.first {
                model.openProject(project)
            }
            if arguments.contains("-openNewProject") { model.sheet = .newProject }
            if arguments.contains("-openSettings") { model.sheet = .settings }
            if arguments.contains("-openVoiceLanguage") {
                model.sheet = .settings
                model.settingsPath = [.voiceLanguage]
            }
            if arguments.contains("-openPlaces") {
                model.sheet = .settings
                model.settingsPath = [.list]
                if arguments.contains("-openPlaceEditor"), let place = model.store.places().first {
                    model.settingsPath = [.list, .edit(place)]
                }
            }
            if arguments.contains("-onboardingWelcome") { model.onboarding = .welcome }
            if arguments.contains("-onboardingHold") { model.onboarding = .hold }
            if arguments.contains("-onboardingPermission"), let date = items.first(where: { $0.list == .later })?.remindAt {
                model.onboarding = .permission
                model.sheet = .onboardingPermission(date)
            }
            if arguments.contains("-startVoice") { model.startListening() }
            if arguments.contains("-openMicDenied") { model.sheet = .micDenied }
            if arguments.contains("-openVoiceRetry") {
                model.sheet = .voiceRetry("Send the slides to Priya before")
            }
            if arguments.contains("-openSwap"), let item = items.first(where: { $0.list == .inbox }) {
                model.sheet = .swap(incoming: item)
            }
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

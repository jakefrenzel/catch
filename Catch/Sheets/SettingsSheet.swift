import SwiftData
import SwiftUI
import UIKit

/// 9a: grouped settings, presented as a page sheet with a round check to close.
struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Place.name) private var places: [Place]

    private static let afterWorkOptions = [
        TimeOfDay(hour: 17, minute: 0), TimeOfDay(hour: 17, minute: 30), TimeOfDay(hour: 18, minute: 0),
    ]

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.settingsPath) {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationTitle("Settings")
                .navigationDestination(for: SettingsRoute.self) { route in
                    switch route {
                    case .list: PlacesListView()
                    case .edit(let place): PlaceEditorView(place: place)
                    case .new(let name): PlaceEditorView(place: nil, suggestedName: name)
                    case .voiceLanguage: VoiceLanguageView()
                    case .actionButton: ActionButtonHelpView()
                    }
                }
        }
        .presentationCornerRadius(14)
        .presentationBackground(Theme.bg)
        .onChange(of: model.settings.appearance) { model.haptic(.selection) }
        .onDisappear { model.settingsPath = [] }
    }

    private var content: some View {
        @Bindable var settingsStore = model.settingsStore

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.blue, in: Circle())
                        .shadow(color: Theme.blue.opacity(0.3), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Text("Settings")
                .font(.largeTitle.bold())
                .padding(.horizontal, 20)
                .accessibilityAddTraits(.isHeader)

            List {
                Section("Reminders") {
                    Toggle(isOn: $settingsStore.settings.notifications) {
                        SettingLabel("Notifications", icon: "bell.fill", tint: Theme.red)
                    }
                    Toggle(isOn: $settingsStore.settings.nudgeDefault) {
                        SettingLabel("Nudge again if missed", icon: "arrow.clockwise", tint: Theme.orange)
                    }
                    Picker(selection: $settingsStore.settings.afterWork) {
                        ForEach(afterWorkOptions(including: settingsStore.settings.afterWork), id: \.self) { time in
                            Text(label(for: time)).tag(time)
                        }
                    } label: {
                        SettingLabel("“After work” means", icon: "clock.fill", tint: Theme.orange)
                    }
                }

                Section("Evening wrap-up") {
                    DatePicker(selection: timeBinding($settingsStore.settings.wrapUpTime),
                               displayedComponents: .hourAndMinute) {
                        SettingLabel("Time", icon: "moon.fill", tint: Theme.purple)
                    }
                    Picker(selection: $settingsStore.settings.wrapUpStyle) {
                        Text("On Today").tag(CatchSettings.WrapUpStyle.onToday)
                        Text("Off").tag(CatchSettings.WrapUpStyle.off)
                    } label: {
                        SettingLabel("Style", icon: "sun.horizon.fill", tint: Theme.purple)
                    }
                }

                Section {
                    Stepper(value: $settingsStore.settings.maxNow, in: CatchSettings.maxNowRange) {
                        HStack {
                            SettingLabel("Max in Now", icon: "sun.max.fill", tint: Theme.blue)
                            Spacer()
                            Text("\(settingsStore.settings.maxNow)")
                                .foregroundStyle(Theme.ink2)
                                .monospacedDigit()
                        }
                    }
                    Toggle(isOn: $settingsStore.settings.upFirstIncludesSteps) {
                        SettingLabel("Up first includes project steps", icon: "arrow.right", tint: Theme.blue)
                    }
                    Toggle(isOn: $settingsStore.settings.pinnedUpFirst) {
                        SettingLabel("Pin Up first above the tabs", icon: "pin.fill", tint: Theme.blue)
                    }
                } header: {
                    Text("Today")
                } footer: {
                    Text("The pinned bar shows when the Up first card is off screen. Swipe it down to hide it until something else is up first.")
                }

                Section("Display") {
                    HStack {
                        SettingLabel("Appearance", icon: "circle.lefthalf.filled",
                                     tint: Color(light: UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1),
                                                 dark: UIColor(red: 72 / 255, green: 72 / 255, blue: 74 / 255, alpha: 1)))
                            .fixedSize()
                            .layoutPriority(1)
                        Spacer(minLength: 12)
                        Picker("Appearance", selection: $settingsStore.settings.appearance) {
                            Text("System").tag(CatchSettings.Appearance.system)
                            Text("Light").tag(CatchSettings.Appearance.light)
                            Text("Dark").tag(CatchSettings.Appearance.dark)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    Toggle(isOn: $settingsStore.settings.haptics) {
                        SettingLabel("Haptics", icon: "iphone.radiowaves.left.and.right", tint: Theme.purple)
                    }
                }

                Section {
                    NavigationLink(value: SettingsRoute.list) {
                        HStack {
                            SettingLabel("Places", icon: "mappin.and.ellipse", tint: Theme.green)
                            Spacer(minLength: 12)
                            Text(places.isEmpty ? "None yet" : places.map(\.name).joined(separator: ", "))
                                .foregroundStyle(Theme.ink2)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text("Places")
                } footer: {
                    Text("Locations stay on this iPhone.")
                }

                Section("Capture") {
                    NavigationLink(value: SettingsRoute.voiceLanguage) {
                        HStack {
                            SettingLabel("Voice language", icon: "globe", tint: Theme.gray)
                            Spacer(minLength: 12)
                            Text(VoiceLanguageView.name(for: settingsStore.settings.voiceLanguage))
                                .foregroundStyle(Theme.ink2)
                                .lineLimit(1)
                        }
                    }
                    NavigationLink(value: SettingsRoute.actionButton) {
                        SettingLabel("Action button", icon: "hand.tap.fill", tint: Theme.gray)
                    }
                }

                Section {
                    valueRow("Replay the Tutorial", icon: "arrow.counterclockwise", value: nil) {
                        model.replayOnboarding()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.bg)
    }

    // MARK: - Rows

    private func valueRow(_ title: String, icon: String, tint: Color = Theme.gray,
                          value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                SettingLabel(title, icon: icon, tint: tint)
                Spacer(minLength: 12)
                if let value {
                    Text(value)
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func afterWorkOptions(including current: TimeOfDay) -> [TimeOfDay] {
        Self.afterWorkOptions.contains(current) ? Self.afterWorkOptions : Self.afterWorkOptions + [current]
    }

    private func label(for time: TimeOfDay) -> String {
        let date = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func timeBinding(_ time: Binding<TimeOfDay>) -> Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: time.wrappedValue.hour, minute: time.wrappedValue.minute,
                                  second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            time.wrappedValue = TimeOfDay(hour: parts.hour ?? 21, minute: parts.minute ?? 0)
        }
    }
}

/// A settings row label: a 30 pt colored icon tile and the title.
private struct SettingLabel: View {
    let title: String
    let icon: String
    let tint: Color

    init(_ title: String, icon: String, tint: Color) {
        self.title = title
        self.icon = icon
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(Color.primary)
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        }
    }
}

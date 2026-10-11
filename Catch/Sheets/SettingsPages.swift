import Speech
import SwiftUI

/// Settings → Voice language: the languages speech recognition supports.
struct VoiceLanguageView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let locales = SFSpeechRecognizer.supportedLocales()
            .map(\.identifier)
            .sorted { Self.name(for: $0) < Self.name(for: $1) }

        List {
            Section {
                row(nil)
            } footer: {
                Text("Catch listens in the language your iPhone uses.")
            }
            Section("Languages") {
                ForEach(locales, id: \.self) { row($0) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("Voice Language")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func row(_ identifier: String?) -> some View {
        let isSelected = model.settings.voiceLanguage == identifier
        return Button {
            model.haptic(.selection)
            model.settingsStore.settings.voiceLanguage = identifier
        } label: {
            HStack {
                Text(Self.name(for: identifier))
                    .foregroundStyle(Color.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// "English (United Kingdom)", or "Same as iPhone" for nil.
    static func name(for identifier: String?) -> String {
        guard let identifier else { return "Same as iPhone" }
        return Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }
}

/// Settings → Action button: how to put Catch on it.
struct ActionButtonHelpView: View {
    var body: some View {
        List {
            Section {
                step(1, "Open the Settings app and choose Action Button.")
                step(2, "Swipe to Shortcut, then tap Choose a Shortcut.")
                step(3, "Under Catch, pick Catch by Voice in the Background to listen in the Dynamic Island without opening Catch. Catch saves when you stop talking.")
            } header: {
                Text("Catch a thought with one press")
                    .textCase(nil)
            } footer: {
                Text("Catch a Thought by Voice opens the app listening instead, and Catch a Thought asks Siri.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("Action Button")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.blue)
                .frame(width: 18)
            Text(text)
        }
        .padding(.vertical, 2)
    }
}

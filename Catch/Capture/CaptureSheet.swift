import SwiftData
import SwiftUI

/// Tap + to type. Return saves and clears the field for the next idea; the
/// check button saves and closes.
struct CaptureSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Item.capturedAt) private var items: [Item]

    @State private var text = ""
    @State private var destination: ListKind = .inbox
    @State private var quickTime: QuickTime.Kind?
    @State private var height: CGFloat = 280
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        let quickTimes = QuickTimes.options(now: .now, calendar: .current)

        VStack(spacing: 14) {
            header

            TextField("What's on your mind?", text: $text, axis: .vertical)
                .font(.title2.weight(.semibold))
                .lineLimit(1...4)
                .focused($isFieldFocused)
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onChange(of: text) { _, newValue in
                    // A vertical text field inserts Return as a newline. Treat it as
                    // "save and keep going" so the keyboard never drops.
                    guard newValue.contains("\n") else { return }
                    text = newValue.replacingOccurrences(of: "\n", with: "")
                    saveAndContinue()
                }
                .accessibilityLabel("New idea")

            ListPicker(selection: $destination, isNowFull: isNowFull)

            if destination == .later {
                timeChips(quickTimes)
            }

            Text(hint)
                .font(.footnote)
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .padding(EdgeInsets(top: 22, leading: 16, bottom: 14, trailing: 16))
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(height)])
        .presentationCornerRadius(38)
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
        .onAppear { isFieldFocused = true }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 44, height: 44)
                    .background(Theme.fill, in: Circle())
            }
            .accessibilityLabel("Close")

            Spacer()
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()

            Button(action: saveAndClose) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.blue.opacity(canSave ? 1 : 0.35), in: Circle())
            }
            .accessibilityLabel("Save")
        }
    }

    private func timeChips(_ quickTimes: [QuickTime]) -> some View {
        let selected = selectedQuickTime(in: quickTimes)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickTimes) { option in
                    let isSelected = option.kind == selected?.kind
                    Button {
                        model.haptic(.selection)
                        quickTime = option.kind
                    } label: {
                        Text("\(option.title) \(ReminderFormatter().detail(for: option))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? Theme.orangeText : Color.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? Theme.orange.opacity(0.18) : Theme.fill,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contentShape(Rectangle().inset(by: -6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 6)
        }
        .padding(.vertical, -6)
        .scrollClipDisabled()
    }

    // MARK: - State

    private var isNowFull: Bool {
        items.filter(\.isOpenInNow).count >= model.settings.maxNow
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var title: String {
        switch destination {
        case .inbox: return "New Idea"
        case .now: return "Add to Now"
        case .later: return "Remind Me Later"
        case .someday: return "Someday"
        }
    }

    private var hint: String {
        let hint = "Return saves and clears for the next idea."
        guard isNowFull && destination != .now else { return hint }
        let max = model.settings.maxNow
        return "\(hint) Now is full (\(max) of \(max))."
    }

    private func selectedQuickTime(in options: [QuickTime]) -> QuickTime? {
        options.first { $0.kind == quickTime } ?? options.first
    }

    // MARK: - Saving

    private func save() -> Bool {
        let remindAt = destination == .later
            ? selectedQuickTime(in: QuickTimes.options(now: .now, calendar: .current))?.date
            : nil
        return model.capture(text, to: destination, remindAt: remindAt)
    }

    private func saveAndContinue() {
        if save() { text = "" }
    }

    private func saveAndClose() {
        _ = save()
        dismiss()
    }
}

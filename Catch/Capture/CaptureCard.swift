import SwiftData
import SwiftUI

/// Tap + to type: a card docked on top of the keyboard. It's not a sheet, so it
/// and the keyboard come up together. Return saves and clears the field for the
/// next idea; the arrow saves and closes. Swipe it down to close (RootView adds
/// the dimmed backdrop, which closes it when tapped).
struct CaptureCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Item.capturedAt) private var items: [Item]

    @State private var text = ""
    @State private var destination: ListKind = .inbox
    @State private var quickTime: QuickTime.Kind?
    @State private var drag: CGFloat = 0
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        card
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .offset(y: drag)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { drag = max(0, $0.translation.height) }
                    .onEnded { value in
                        if value.translation.height > 60 || value.predictedEndTranslation.height > 140 {
                            close()
                        } else {
                            withAnimation(.catchEaseOut(0.25)) { drag = 0 }
                        }
                    }
            )
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, close)
            // Focused straight away, so the keyboard starts rising with the card.
            .onAppear { isFieldFocused = true }
    }

    private var card: some View {
        let quickTimes = QuickTimes.options(now: .now, calendar: .current)
        return VStack(alignment: .leading, spacing: 14) {
            TextField("What's on your mind?", text: $text, axis: .vertical)
                .font(.title3.weight(.semibold))
                .lineLimit(1...5)
                .focused($isFieldFocused)
                .onChange(of: text) { _, newValue in
                    // A vertical text field inserts Return as a newline. Treat it as
                    // "save and keep going" so the keyboard never drops.
                    guard newValue.contains("\n") else { return }
                    text = newValue.replacingOccurrences(of: "\n", with: "")
                    saveAndContinue()
                }
                .accessibilityLabel("New idea")
                .accessibilityHint("Return saves it and clears for the next one.")

            if destination == .later {
                timeChips(quickTimes)
            }

            HStack(spacing: 6) {
                ForEach(ListKind.allCases) { kind in
                    destinationButton(kind)
                }
                Spacer(minLength: 0)
                Button(action: saveAndClose) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Theme.blue.opacity(canSave ? 1 : 0.35), in: Circle())
                        .contentShape(Rectangle().inset(by: -4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save")
                .accessibilityValue(canSave ? "" : "Nothing to save yet")
            }
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 12, trailing: 14))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 15, x: 0, y: 10)
    }

    // MARK: - Pieces

    /// Icons for the lists you aren't using; the chosen one also shows its name.
    private func destinationButton(_ kind: ListKind) -> some View {
        let isSelected = destination == kind
        let isBlocked = kind == .now && isNowFull && !isSelected
        let style = Self.style(for: kind)
        return Button {
            if isBlocked {
                model.haptic(.warning)
                model.flash("Now is full (\(model.settings.maxNow)). Move something out first", undo: false)
            } else if !isSelected {
                model.haptic(.selection)
                withAnimation(reduceMotion ? nil : .catchEaseOut(0.25)) { destination = kind }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: style.icon)
                    .font(.system(size: 16, weight: .semibold))
                if isSelected {
                    Text(kind.title)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize()
                }
            }
            .foregroundStyle(style.color)
            .padding(.horizontal, isSelected ? 12 : 0)
            .frame(minWidth: 36, minHeight: 36)
            .background(isSelected ? style.tint : Theme.fill, in: Capsule())
            .contentShape(Capsule().inset(by: -4))
        }
        .buttonStyle(.plain)
        .opacity(isBlocked ? 0.4 : 1)
        .accessibilityLabel(kind.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isBlocked ? "Now is full." : "")
    }

    private static func style(for kind: ListKind) -> (icon: String, color: Color, tint: Color) {
        switch kind {
        case .inbox: return ("tray", Theme.blue, Theme.blueTint)
        case .now: return ("sun.max", Theme.blue, Theme.blueTint)
        case .later: return ("clock", Theme.orangeText, Theme.orangeTint)
        case .someday: return ("archivebox", Theme.ink2, Theme.fill)
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
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
    }

    // MARK: - State

    private var isNowFull: Bool {
        items.filter(\.isOpenInNow).count >= model.settings.maxNow
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        close()
    }

    private func close() {
        isFieldFocused = false
        model.isCaptureOpen = false
    }
}

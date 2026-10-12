import SwiftData
import SwiftUI

/// Tap an item's text: change its title, note and list, set its reminder, or delete it.
/// The title and note read like a page; list, reminder and Focus are one settings group.
struct EditSheet: View {
    let item: Item

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Item.capturedAt) private var items: [Item]

    @State private var text: String
    @State private var note: String
    @State private var list: ListKind
    @FocusState private var isTitleFocused: Bool

    init(item: Item) {
        self.item = item
        _text = State(initialValue: item.text)
        _note = State(initialValue: item.note ?? "")
        _list = State(initialValue: item.list)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                SheetCloseButton { dismiss() }
                Spacer()
                Button(role: .destructive) {
                    model.deleteFromEditor(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.red)
                        .frame(width: 44, height: 44)
                        .background(Theme.red.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
                SheetSaveButton(action: save)
            }

            // The title and note sit on the sheet itself, like a page, not in a box.
            VStack(alignment: .leading, spacing: 4) {
                // A long item shows 3 lines and "…" until tapped, then opens up to 8
                // (scrolling inside past that) so it can be read and edited in full.
                TextField("Title", text: $text, axis: .vertical)
                    .font(Self.titleFont)
                    .lineLimit(1...(isTitleFocused ? 8 : 3))
                    .focused($isTitleFocused)
                    .submitLabel(.done)
                    .onChange(of: text) { _, new in
                        guard new.contains("\n") else { return }
                        // Return saves rather than adding a line; pasted line breaks become spaces.
                        let typedReturn = new.filter { $0 == "\n" }.count == 1
                        let cleaned = new.replacingOccurrences(of: "\n", with: typedReturn ? "" : " ")
                        text = cleaned
                        if typedReturn {
                            model.saveEdit(item, text: cleaned, note: note, list: list)
                        }
                    }
                    .accessibilityLabel("Title")
                    // The field doesn't add "…" itself; this covers it until tapped.
                    // Taps pass through to the field underneath.
                    .overlay(alignment: .topLeading) {
                        if !isTitleFocused {
                            Text(text)
                                .font(Self.titleFont)
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .background(Theme.bg)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                TextField("Add a note", text: $note, axis: .vertical)
                    .lineLimit(1...6)
                    .foregroundStyle(Theme.ink2)
                    .accessibilityLabel("Note")
            }
            .padding(EdgeInsets(top: 12, leading: 6, bottom: 20, trailing: 6))

            // List, reminder and Focus as one settings-style group.
            VStack(spacing: 0) {
                listRow
                if list == .later {
                    separator
                    remindRow
                }
                if !item.isDone {
                    separator
                    focusRow
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(caughtLabel)
                .font(.footnote)
                .foregroundStyle(Theme.ink2)
                .padding(EdgeInsets(top: 10, leading: 6, bottom: 0, trailing: 6))
        }
        .padding(EdgeInsets(top: 22, leading: 16, bottom: 20, trailing: 16))
        .fittedSheet()
    }

    private static let titleFont = Font.title2.bold()

    // MARK: - Rows

    /// Which list it's in, picked from a menu. Now can't be picked while it's full.
    private var listRow: some View {
        let style = Self.listStyle(for: list)
        return Menu {
            ForEach(ListKind.allCases) { kind in
                let isBlocked = kind == .now && isNowFull
                Button {
                    guard kind != list else { return }
                    model.haptic(.selection)
                    list = kind
                } label: {
                    if kind == list {
                        Label(kind.title, systemImage: "checkmark")
                    } else {
                        Text(isBlocked ? "Now (full)" : kind.title)
                    }
                }
                .disabled(isBlocked)
            }
        } label: {
            row(icon: style.icon, tint: style.tint, title: "List") {
                Text(list.title)
                    .foregroundStyle(Theme.ink2)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("List, \(list.title)")
    }

    /// Later only: shows when it comes back and opens the Remind sheet.
    private var remindRow: some View {
        Button {
            model.saveEditAndPickTime(item, text: text, note: note)
        } label: {
            row(icon: "bell.fill", tint: Theme.orange, title: "Remind me") {
                Text(reminderLabel)
                    .foregroundStyle(Theme.orangeText)
                chevron
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remind me, \(reminderLabel)")
    }

    /// Opens Focus, the timer view Up first's Start opens, on this item.
    private var focusRow: some View {
        Button {
            model.saveEditAndFocus(item, text: text, note: note, list: list)
        } label: {
            row(icon: "timer", tint: Theme.blue, title: "Start Focus") {
                chevron
            }
        }
        .buttonStyle(.plain)
    }

    private func row<Trailing: View>(icon: String, tint: Color, title: String,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.ink4)
    }

    /// Lines up with the row titles, past the icon.
    private var separator: some View {
        Theme.sep.frame(height: 1).padding(.leading, 56)
    }

    private static func listStyle(for kind: ListKind) -> (icon: String, tint: Color) {
        switch kind {
        case .inbox: return ("tray.fill", Theme.blue)
        case .now: return ("sun.max.fill", Theme.blue)
        case .later: return ("clock.fill", Theme.orange)
        case .someday: return ("archivebox.fill", Theme.gray)
        }
    }

    // MARK: - State

    /// Now is full and this item isn't already in it.
    private var isNowFull: Bool {
        item.list != .now && items.filter(\.isOpenInNow).count >= model.settings.maxNow
    }

    private var reminderLabel: String {
        let now = Date.now
        if item.list == .later, let reminder = item.reminder {
            return ReminderFormatter().label(for: reminder, now: now)
        }
        let afterWork = model.settings.afterWork.next(after: now, calendar: .current)
        return ReminderFormatter().label(for: afterWork, now: now)
    }

    private var caughtLabel: String {
        let now = Date.now
        let label = ReminderFormatter().caughtLabel(for: item.capturedAt, now: now)
        return Calendar.current.isDate(item.capturedAt, inSameDayAs: now)
            ? "Caught today at \(label)"
            : "Caught \(label)"
    }

    private func save() {
        model.saveEdit(item, text: text, note: note, list: list)
    }
}

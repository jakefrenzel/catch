import SwiftData
import SwiftUI

/// Tap an item's text: change its title, note and list, set its reminder, or delete it.
struct EditSheet: View {
    let item: Item

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Item.capturedAt) private var items: [Item]

    @State private var text: String
    @State private var note: String
    @State private var list: ListKind

    init(item: Item) {
        self.item = item
        _text = State(initialValue: item.text)
        _note = State(initialValue: item.note ?? "")
        _list = State(initialValue: item.list)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                SheetCloseButton { dismiss() }
                Spacer()
                Text("Edit")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                SheetSaveButton(action: save)
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Title", text: $text)
                    .font(.title2.weight(.semibold))
                    .submitLabel(.done)
                    .onSubmit(save)
                    .accessibilityLabel("Title")
                TextField("Add a note", text: $note, axis: .vertical)
                    .font(.callout)
                    .lineLimit(3...6)
                    .accessibilityLabel("Note")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            ListPicker(selection: $list, isNowFull: isNowFull) {
                model.flash("Now is full (\(model.settings.maxNow)). Move something out first", undo: false)
            }

            if list == .later {
                remindRow
            }

            Text(caughtLabel)
                .font(.footnote)
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)

            Button(role: .destructive) {
                model.deleteFromEditor(item)
            } label: {
                Text("Delete Item")
                    .foregroundStyle(Theme.red)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 22, leading: 16, bottom: 20, trailing: 16))
        .fittedSheet()
    }

    /// Later only: shows when it comes back and opens the Remind sheet.
    private var remindRow: some View {
        Button {
            model.saveEditAndPickTime(item, text: text, note: note)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Theme.orange, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
                Text("Remind me")
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(reminderLabel)
                    .font(.subheadline)
                    .foregroundStyle(Theme.orangeText)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remind me, \(reminderLabel)")
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

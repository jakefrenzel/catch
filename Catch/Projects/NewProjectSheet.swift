import SwiftData
import SwiftUI

/// 9: name a project, list its steps, optionally group them into phases, and
/// pull steps in from the Inbox.
struct NewProjectSheet: View {
    /// A row being edited. Kept separate from ProjectDraft so each row has a stable id.
    private struct Row: Identifiable {
        enum Kind { case phase, step }
        let id = UUID()
        let kind: Kind
        var text: String
        var fromInbox: Item?
    }

    private enum Field: Hashable { case name, newStep }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Item> { $0.listRaw == "inbox" }, sort: \Item.capturedAt)
    private var inbox: [Item]

    @State private var name = ""
    @State private var rows: [Row] = []
    @State private var newStep = ""
    @FocusState private var focus: Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SheetCloseButton { dismiss() }
                    Spacer()
                    Text("New Project")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    SheetSaveButton(isEnabled: draft.hasName, label: "Create", action: create)
                }

                TextField("Project name", text: $name)
                    .font(.title2.weight(.semibold))
                    .focused($focus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focus = .newStep }
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityLabel("Project name")

                HStack(alignment: .firstTextBaseline) {
                    Text("Steps")
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    if stepCount > 0 {
                        Text("\(stepCount)")
                            .font(.footnote)
                    }
                }
                .foregroundStyle(Theme.ink2)
                .padding(.horizontal, 20)
                .padding(.top, 4)

                stepsCard

                Button {
                    model.haptic(.light)
                    rows.append(Row(kind: .phase, text: draft.nextPhaseName))
                } label: {
                    Label("Add a Phase", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, -10)

                Text("Phases are optional. Use them when steps happen in stages, like Plan, Choose, Build.")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
                    .padding(.horizontal, 8)

                if !availableInbox.isEmpty {
                    inboxChips
                }
            }
            .padding(EdgeInsets(top: 22, leading: 16, bottom: 40, trailing: 16))
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationCornerRadius(38)
        .presentationBackground(Theme.bg)
        .presentationDragIndicator(.visible)
        .onAppear { focus = .name }
    }

    // MARK: - Steps

    private var stepsCard: some View {
        let firstStepID = rows.first { $0.kind == .step }?.id
        return VStack(spacing: 0) {
            ForEach($rows) { $row in
                switch row.kind {
                case .phase:
                    phaseRow($row)
                case .step:
                    stepRow(row, isFirst: row.id == firstStepID)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                TextField("Add a step", text: $newStep)
                    .font(.callout)
                    .focused($focus, equals: .newStep)
                    .submitLabel(.next)
                    .onSubmit(addStep)
            }
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
        .padding(.leading, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func phaseRow(_ row: Binding<Row>) -> some View {
        HStack(spacing: 8) {
            TextField("Phase name", text: row.text)
                .font(.footnote.weight(.bold))
                .textInputAutocapitalization(.characters)
                .kerning(0.4)
                .foregroundStyle(Theme.blue)
                .accessibilityLabel("Phase name")
            removeButton(for: row.wrappedValue.id, named: "phase \(row.wrappedValue.text)")
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .padding(.trailing, 12)
    }

    private func stepRow(_ row: Row, isFirst: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .strokeBorder(isFirst ? Theme.blue : Theme.ink4, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.text)
                    .font(.callout.weight(isFirst ? .semibold : .regular))
                if row.fromInbox != nil {
                    Text("From Inbox")
                        .font(.caption)
                        .foregroundStyle(Theme.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isFirst {
                NextChip()
            }
            removeButton(for: row.id, named: row.text)
        }
        .padding(.vertical, 10)
        .padding(.trailing, 12)
        .overlay(alignment: .bottom) { Theme.sep.frame(height: 1) }
    }

    private func removeButton(for id: UUID, named name: String) -> some View {
        Button {
            rows.removeAll { $0.id == id }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.ink2)
                .frame(width: 28, height: 28)
                .background(Theme.fill, in: Circle())
                .contentShape(Rectangle().inset(by: -8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(name)")
    }

    // MARK: - Inbox

    private var inboxChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add from your Inbox")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink2)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(availableInbox) { item in
                    Button {
                        model.haptic(.light)
                        rows.append(Row(kind: .step, text: item.text, fromInbox: item))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.blue)
                            Text(item.text)
                                .font(.subheadline)
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(item.text) as a step")
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    /// Up to four Inbox items not already added.
    private var availableInbox: [Item] {
        let used = Set(rows.compactMap { $0.fromInbox?.id })
        return Array(inbox.filter { !used.contains($0.id) }.prefix(4))
    }

    // MARK: - Saving

    private var stepCount: Int { rows.filter { $0.kind == .step }.count }

    private var draft: ProjectDraft {
        ProjectDraft(name: name, rows: rows.map { row in
            switch row.kind {
            case .phase: return .phase(row.text)
            case .step: return .step(row.text, fromInbox: row.fromInbox)
            }
        })
    }

    private func addStep() {
        let text = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        rows.append(Row(kind: .step, text: text))
        newStep = ""
        focus = .newStep
    }

    private func create() {
        // A step typed but not yet added with Return still counts.
        addStep()
        model.createProject(from: draft)
    }
}

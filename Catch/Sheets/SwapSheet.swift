import SwiftData
import SwiftUI

/// 10d: Now is full. Pick one to send back to Inbox so the new item can come in.
struct SwapSheet: View {
    let incoming: Item

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Item.capturedAt) private var items: [Item]
    @State private var selectedID: UUID?

    var body: some View {
        let open = items.filter(\.isOpenInNow)
        let maxNow = model.settings.maxNow

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Now holds \(maxNow) thing\(maxNow == 1 ? "" : "s")")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("To add “\(incoming.text)”, move one out. It goes back to Inbox.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink2)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 0) {
                ForEach(Array(open.enumerated()), id: \.element.id) { index, item in
                    row(item, isSelected: item.id == selectedID, showsSeparator: index < open.count - 1)
                }
            }
            .padding(.leading, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button {
                guard let outgoing = open.first(where: { $0.id == selectedID }) else { return }
                model.swap(incoming: incoming, outgoing: outgoing)
            } label: {
                Text("Swap")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.blue.opacity(selectedID == nil ? 0.35 : 1), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selectedID == nil)

            Button("Keep It in \(incoming.list.title)") { dismiss() }
                .font(.body)
                .foregroundStyle(Theme.blue)
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 26, leading: 16, bottom: 16, trailing: 16))
        .fittedSheet(showsHandle: false)
        .onAppear {
            if selectedID == nil { selectedID = open.last?.id }
        }
    }

    private func row(_ item: Item, isSelected: Bool, showsSeparator: Bool) -> some View {
        Button {
            model.haptic(.selection)
            selectedID = item.id
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if isSelected {
                        Circle().fill(Theme.orange)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle().strokeBorder(Theme.ink4, lineWidth: 1.5)
                    }
                }
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.text)
                        .foregroundStyle(Color.primary)
                    if let reason = item.reason {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(Theme.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
            .padding(.trailing, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                Theme.sep.frame(height: 1).padding(.leading, 36)
            }
        }
        .accessibilityLabel(item.text)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

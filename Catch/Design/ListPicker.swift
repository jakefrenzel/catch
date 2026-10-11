import SwiftUI

/// Inbox / Now / Later / Someday segmented control. Now is dimmed and can't be
/// picked while it's full; tapping it calls `onNowFull` instead.
struct ListPicker: View {
    @Binding var selection: ListKind
    let isNowFull: Bool
    var onNowFull: () -> Void = {}

    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ListKind.allCases) { kind in
                segment(kind)
            }
        }
        .padding(2)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func segment(_ kind: ListKind) -> some View {
        let isSelected = selection == kind
        let isBlocked = kind == .now && isNowFull && !isSelected
        return Button {
            if isBlocked {
                model.haptic(.warning)
                onNowFull()
            } else if !isSelected {
                model.haptic(.selection)
                selection = kind
            }
        } label: {
            Text(kind.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.seg)
                            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
                    }
                }
                .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
        .opacity(isBlocked ? 0.4 : 1)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isBlocked ? "Now is full." : "")
    }
}

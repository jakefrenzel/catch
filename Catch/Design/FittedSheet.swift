import SwiftUI

extension View {
    /// Presents this view as a bottom sheet exactly as tall as its content,
    /// with the handoff's 38 pt corners and grouped background.
    func fittedSheet(showsHandle: Bool = true, background: Color = Theme.bg) -> some View {
        modifier(FittedSheet(showsHandle: showsHandle, background: background))
    }
}

private struct FittedSheet: ViewModifier {
    let showsHandle: Bool
    let background: Color
    @State private var height: CGFloat = 320

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .frame(maxHeight: .infinity, alignment: .top)
            .presentationDetents([.height(height)])
            .presentationCornerRadius(38)
            .presentationBackground(background)
            .presentationDragIndicator(showsHandle ? .visible : .hidden)
    }
}

/// The 44 pt round buttons at the top corners of sheets.
struct SheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
                .background(Theme.fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

struct SheetSaveButton: View {
    var isEnabled = true
    var label = "Save"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Theme.blue.opacity(isEnabled ? 1 : 0.35), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isEnabled ? "" : "Nothing to save yet")
    }
}

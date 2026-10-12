import SwiftUI

extension View {
    /// Presents this view as a bottom sheet exactly as tall as its content,
    /// with the handoff's 38 pt corners and grouped background. Content taller
    /// than the screen (large text sizes) scrolls instead of being clipped.
    /// Give a `rememberAs` name to have the sheet open at the height it had last
    /// time, rather than opening at a guess and resizing as it measures itself.
    func fittedSheet(showsHandle: Bool = true, background: Color = Theme.bg,
                     rememberAs key: String? = nil) -> some View {
        modifier(FittedSheet(showsHandle: showsHandle, background: background, key: key))
    }
}

/// Measured sheet heights, kept between launches so even the first open is the right size.
private enum SheetHeights {
    static func last(_ key: String) -> CGFloat? {
        let height = UserDefaults.standard.double(forKey: "sheetHeight.\(key)")
        return height > 0 ? height : nil
    }

    static func remember(_ height: CGFloat, as key: String) {
        UserDefaults.standard.set(Double(height), forKey: "sheetHeight.\(key)")
    }
}

private struct FittedSheet: ViewModifier {
    let showsHandle: Bool
    let background: Color
    let key: String?
    @State private var measured: CGFloat?

    func body(content: Content) -> some View {
        let height = measured ?? key.flatMap(SheetHeights.last) ?? 320
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    // Remember how it opens, not how tall it grew (Later's time chips).
                    if measured == nil, let key { SheetHeights.remember($0, as: key) }
                    measured = $0
                }
        }
        .scrollBounceBehavior(.basedOnSize)
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

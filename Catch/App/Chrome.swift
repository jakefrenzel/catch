import SwiftUI

/// Today / Inbox / Someday, floating at the bottom left of every screen.
///
/// Press anywhere on the bar and the selection pill follows your finger, then
/// settles on the tab you let go over. (The system controls' magnifying glass
/// lens isn't available to custom views, so this doesn't try to imitate it.)
struct FloatingTabBar: View {
    @Binding var selection: AppModel.Tab
    let inboxCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Off during onboarding, when RootView disables the bar.
    @Environment(\.isEnabled) private var isEnabled
    @State private var width: CGFloat = 0
    /// Where the finger is along the bar while it's down. Resets by itself
    /// if the touch is cancelled (a call, an alert).
    @GestureState private var fingerX: CGFloat?

    private static let tabs: [AppModel.Tab] = [.today, .inbox, .someday]

    var body: some View {
        // While pressed, the tab under the finger is the one that lights up.
        let highlighted = fingerX.map(tab(at:)) ?? selection

        HStack(spacing: 0) {
            tab(.today, title: "Today", icon: "sun.max", highlighted: highlighted)
            tab(.inbox, title: "Inbox", icon: "tray", badge: inboxCount, highlighted: highlighted)
            tab(.someday, title: "Someday", icon: "archivebox", highlighted: highlighted)
        }
        .background(alignment: .leading) {
            Capsule()
                .fill(Theme.blueTint)
                .frame(width: segmentWidth)
                .frame(maxHeight: .infinity)
                .offset(x: pillOffset)
                .allowsHitTesting(false)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($fingerX) { value, fingerX, _ in fingerX = value.location.x }
                .onEnded { selection = tab(at: $0.location.x) },
            including: isEnabled ? .all : .subviews
        )
        // Only the bar animates; the screen behind it still switches instantly.
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.78), value: selection)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: fingerX)
        .padding(5)
        .frame(minHeight: 62)
        .barBackground()
    }

    private var segmentWidth: CGFloat {
        width / CGFloat(Self.tabs.count)
    }

    /// Under the finger while it's down, otherwise over the selected tab.
    private var pillOffset: CGFloat {
        if let fingerX {
            return min(max(fingerX - segmentWidth / 2, 0), max(width - segmentWidth, 0))
        }
        return CGFloat(Self.tabs.firstIndex(of: selection) ?? 0) * segmentWidth
    }

    private func tab(at x: CGFloat) -> AppModel.Tab {
        guard segmentWidth > 0 else { return selection }
        let index = Int(x / segmentWidth)
        return Self.tabs[min(max(index, 0), Self.tabs.count - 1)]
    }

    private func tab(_ tab: AppModel.Tab, title: String, icon: String, badge: Int = 0,
                     highlighted: AppModel.Tab) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Theme.red, in: Capsule())
                            .offset(x: 12, y: -6)
                    }
                }
            Text(title)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(highlighted == tab ? Theme.blue : .primary)
        .frame(maxWidth: .infinity, minHeight: 52)
        // The bar's drag gesture handles touch; VoiceOver and Voice Control use these.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge > 0 ? "\(title), \(badge) to sort" : title)
        .accessibilityAddTraits(selection == tab ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { selection = tab }
    }
}

private extension View {
    /// Liquid Glass on iOS 26, like the system tab bar; a blurred capsule before that.
    @ViewBuilder
    func barBackground() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            glassEffect(.regular, in: Capsule())
        } else {
            materialBarBackground()
        }
        #else
        materialBarBackground()
        #endif
    }

    func materialBarBackground() -> some View {
        background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .floatingShadow()
    }
}

/// The blue + button. Tap to type; hold 0.38 s to talk and let go to save.
/// Dragging well away before letting go cancels.
struct CaptureButton: View {
    let onTap: () -> Void
    let onHoldStart: () -> Void
    let onHoldEnd: (_ save: Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var isHolding = false
    @State private var holdTimer: Task<Void, Never>?
    /// True while a finger is down. SwiftUI resets it even when the touch is
    /// cancelled (a permission alert, a call), which onEnded never hears about.
    @GestureState private var isTouching = false

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 62, height: 62)
            .background(Theme.blue, in: Circle())
            .shadow(color: Theme.blue.opacity(0.35), radius: 12, x: 0, y: 8)
            .scaleEffect(isPressed && !reduceMotion ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isTouching) { _, touching, _ in touching = true }
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        holdTimer = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(380))
                            guard !Task.isCancelled else { return }
                            isHolding = true
                            onHoldStart()
                        }
                    }
                    .onEnded { value in
                        holdTimer?.cancel()
                        let draggedAway = hypot(value.translation.width, value.translation.height) > 80
                        if isHolding {
                            onHoldEnd(!draggedAway)
                        } else if !draggedAway {
                            onTap()
                        }
                        isPressed = false
                        isHolding = false
                    }
            )
            .onChange(of: isTouching) { _, touching in
                // Ended normally: onEnded already reset everything.
                guard !touching, isPressed else { return }
                holdTimer?.cancel()
                if isHolding { onHoldEnd(false) }
                isPressed = false
                isHolding = false
            }
            .accessibilityElement()
            .accessibilityLabel("Capture")
            .accessibilityHint("Opens a new idea. Use the Talk action to speak instead.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, onTap)
            .accessibilityAction(named: "Talk", onHoldStart)
    }
}

/// The toast that slides in from the top after an action. Swipe it up to dismiss it.
struct ToastView: View {
    let toast: AppModel.Toast
    let onUndo: () -> Void
    let onDismiss: () -> Void
    @State private var drag: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.green)
                .accessibilityHidden(true)
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if toast.canUndo {
                Button("Undo", action: onUndo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 100 / 255, green: 210 / 255, blue: 1))
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, toast.canUndo ? 2 : 13)
        .background(Theme.toastBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .floatingShadow()
        .offset(y: drag)
        .gesture(
            DragGesture(minimumDistance: 10)
                // Follows the finger up; resists being pulled down.
                .onChanged { drag = $0.translation.height < 0 ? $0.translation.height : $0.translation.height / 4 }
                .onEnded { value in
                    if value.translation.height < -30 || value.predictedEndTranslation.height < -80 {
                        // Leaves from where it was dragged to; a new toast starts fresh.
                        onDismiss()
                    } else {
                        withAnimation(.catchEaseOut(0.25)) { drag = 0 }
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Dismiss", onDismiss)
    }
}

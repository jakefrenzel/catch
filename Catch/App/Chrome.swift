import SwiftUI

/// Today / Inbox / Someday, floating at the bottom left of every screen.
struct FloatingTabBar: View {
    @Binding var selection: AppModel.Tab
    let inboxCount: Int

    var body: some View {
        HStack(spacing: 0) {
            tab(.today, title: "Today", icon: "sun.max")
            tab(.inbox, title: "Inbox", icon: "tray", badge: inboxCount)
            tab(.someday, title: "Someday", icon: "archivebox")
        }
        .padding(5)
        .frame(minHeight: 62)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .floatingShadow()
    }

    private func tab(_ tab: AppModel.Tab, title: String, icon: String, badge: Int = 0) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20))
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
            .foregroundStyle(isSelected ? Theme.blue : .primary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isSelected ? Theme.blueTint : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badge > 0 ? "\(title), \(badge) to sort" : title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// The blue + button. Tap to type; hold 0.38 s to talk and let go to save.
/// Dragging well away before letting go cancels.
struct CaptureButton: View {
    let onTap: () -> Void
    let onHoldStart: () -> Void
    let onHoldEnd: (_ save: Bool) -> Void

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
            .scaleEffect(isPressed ? 0.94 : 1)
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

/// The toast that slides in from the top after an action.
struct ToastView: View {
    let toast: AppModel.Toast
    let onUndo: () -> Void

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
        .accessibilityElement(children: .contain)
    }
}

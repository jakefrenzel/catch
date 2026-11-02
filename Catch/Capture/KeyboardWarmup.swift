import SwiftUI
import UIKit

/// The first keyboard after launch is slow to appear while iOS loads it. Bringing
/// one up and straight back down once, soon after launch, does that loading up
/// front, so tapping + to catch an idea gets the keyboard quickly.
///
/// SwiftUI lays out around a keyboard as it comes and goes, even one that's only
/// up for an instant, which made the tab bar drop and come back. So for the
/// moment of the warm-up the whole screen ignores the keyboard, and nothing moves.
/// Add it once to the root view, outside anything that should follow the keyboard.
struct KeyboardWarmup: ViewModifier {
    @State private var isWarming = false

    func body(content: Content) -> some View {
        content
            // Empty edges ignore nothing, so this is a no-op outside the warm-up
            // and the view keeps its identity either way.
            .ignoresSafeArea(.keyboard, edges: isWarming ? .all : [])
            .background(Trigger(isWarming: $isWarming))
    }

    private struct Trigger: UIViewRepresentable {
        @Binding var isWarming: Bool

        func makeUIView(context: Context) -> WarmupView {
            WarmupView(setWarming: { isWarming = $0 })
        }

        func updateUIView(_ uiView: WarmupView, context: Context) {}
    }

    final class WarmupView: UIView {
        private let setWarming: (Bool) -> Void
        private var didWarmUp = false

        init(setWarming: @escaping (Bool) -> Void) {
            self.setWarming = setWarming
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard !didWarmUp, window != nil else { return }
            didWarmUp = true
            // VoiceOver would move its focus to the field and back.
            guard !UIAccessibility.isVoiceOverRunning else { return }
            // After launch has settled, so loading the keyboard (which holds up
            // the main thread) doesn't stall the app as it appears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startWarmUp()
            }
        }

        private func startWarmUp() {
            // Skip it if a keyboard is already up: it's loaded, and the field in use keeps focus.
            guard let window, !Self.hasFirstResponder(in: window) else { return }
            setWarming(true)
            // Let SwiftUI lay out with the keyboard ignored before raising it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self, let window = self.window, !Self.hasFirstResponder(in: window) else {
                    self?.setWarming(false)
                    return
                }
                // Follow the keyboard again once this one has gone (there's no
                // keyboard then, so nothing moves), or after a second at most,
                // so a field opened soon after still rides up with its keyboard.
                var observer: NSObjectProtocol?
                let finish = { [weak self] in
                    guard let token = observer else { return }
                    NotificationCenter.default.removeObserver(token)
                    observer = nil
                    self?.setWarming(false)
                }
                observer = NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardDidHideNotification, object: nil, queue: .main
                ) { _ in finish() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: finish)

                let field = UITextField(frame: .zero)
                field.isAccessibilityElement = false
                window.addSubview(field)
                field.becomeFirstResponder()
                field.resignFirstResponder()
                field.removeFromSuperview()
            }
        }

        private static func hasFirstResponder(in view: UIView) -> Bool {
            view.isFirstResponder || view.subviews.contains { hasFirstResponder(in: $0) }
        }
    }
}

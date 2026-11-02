import SwiftUI
import UIKit

/// The first keyboard after launch is slow to appear while iOS loads it. Bringing
/// one up and straight back down once at launch does that loading up front, so
/// tapping + to catch an idea gets the keyboard quickly. Nothing shows: both
/// happen before the screen next draws. Loading it holds up the main thread, so
/// it waits until launch has settled rather than freezing the app as it appears.
/// Add it once as a background of the root view.
struct KeyboardWarmup: UIViewRepresentable {
    func makeUIView(context: Context) -> WarmupView {
        WarmupView()
    }

    func updateUIView(_ uiView: WarmupView, context: Context) {}

    final class WarmupView: UIView {
        private var didWarmUp = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard !didWarmUp, let window else { return }
            didWarmUp = true
            // VoiceOver would move its focus to the field and back.
            guard !UIAccessibility.isVoiceOverRunning else { return }
            // Well after the first frame, so the app opens smoothly and the
            // launch animation isn't cut short by a stall.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                // Skip it if something already brought up a keyboard, or the view's gone.
                guard let self, let window = self.window,
                      !UIResponder.isAnyFirstResponder(in: window) else { return }
                let field = UITextField(frame: .zero)
                field.isAccessibilityElement = false
                window.addSubview(field)
                field.becomeFirstResponder()
                field.resignFirstResponder()
                field.removeFromSuperview()
            }
        }
    }
}

private extension UIResponder {
    static func isAnyFirstResponder(in view: UIView) -> Bool {
        view.isFirstResponder || view.subviews.contains { isAnyFirstResponder(in: $0) }
    }
}

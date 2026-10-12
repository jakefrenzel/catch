import SwiftUI
import UIKit

/// The first keyboard after launch is slow to appear while iOS loads it. Bringing
/// one up and straight back down once at launch does that loading up front, so
/// tapping + to catch an idea gets the keyboard quickly. Nothing shows: both
/// happen before the screen next draws. Add it once as a background of the root view.
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
            // After the first frame, so launch isn't held up.
            DispatchQueue.main.async {
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

import SwiftUI
import UIKit

/// Shows `content` docked on top of the keyboard, moving exactly with it.
///
/// SwiftUI follows the keyboard with its own animation, which trails the real
/// keyboard a little, so a card docked by SwiftUI lagged behind it. Here a UIKit
/// view is pinned to `keyboardLayoutGuide`, which the system moves inside the
/// keyboard's own animation. The content also slides its own height below the
/// keyboard's edge as it comes and goes, on the keyboard's curve, so it rises
/// out of the keyboard when it opens and sinks back into it when it closes.
///
/// Fills the screen but only takes touches on the content.
struct KeyboardDock<Content: View>: UIViewControllerRepresentable {
    let content: Content

    func makeUIViewController(context: Context) -> KeyboardDockController<Content> {
        KeyboardDockController(rootView: content)
    }

    func updateUIViewController(_ controller: KeyboardDockController<Content>, context: Context) {
        controller.host.rootView = content
    }
}

final class KeyboardDockController<Content: View>: UIViewController {
    let host: UIHostingController<Content>
    /// Below the keyboard's edge: before the keyboard has come up, and after it starts down.
    private var isTuckedAway = true
    private var observers: [NSObjectProtocol] = []

    init(rootView: Content) {
        host = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func loadView() {
        view = PassThroughView()
        view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        host.view.backgroundColor = .clear
        host.sizingOptions = .intrinsicContentSize
        // The content sits on the keyboard, so it needs no insets of its own; without
        // this it would pad itself for the home indicator while the keyboard is down.
        host.safeAreaRegions = []
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        // Track the keyboard's top edge all the way down to the bottom of the screen.
        view.keyboardLayoutGuide.usesBottomSafeArea = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])

        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] note in
                self?.setTuckedAway(false, alongside: note)
            },
            center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] note in
                self?.setTuckedAway(true, alongside: note)
            },
        ]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep the tucked-away offset right as the content's height settles.
        if isTuckedAway { host.view.transform = tuckedTransform }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // A hardware keyboard may never come up: show the content anyway.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.isTuckedAway, self.view.window != nil, !self.didHide else { return }
            self.setTuckedAway(false, alongside: nil)
        }
    }

    private var didHide = false

    private var tuckedTransform: CGAffineTransform {
        CGAffineTransform(translationX: 0, y: host.view.bounds.height + 16)
    }

    /// Moves the content with the keyboard's own duration and curve.
    private func setTuckedAway(_ tucked: Bool, alongside note: Notification?) {
        if tucked { didHide = true }
        isTuckedAway = tucked
        let target = tucked ? tuckedTransform : .identity
        guard !UIAccessibility.isReduceMotionEnabled else {
            host.view.transform = target
            return
        }
        let info = note?.userInfo
        let duration = info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curve = info?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int ?? UIView.AnimationCurve.easeInOut.rawValue
        UIView.animate(withDuration: duration, delay: 0,
                       options: [UIView.AnimationOptions(rawValue: UInt(curve) << 16), .beginFromCurrentState]) {
            self.host.view.transform = target
        }
    }

    /// Lets touches outside the content through to the views underneath.
    private final class PassThroughView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let hit = super.hitTest(point, with: event)
            return hit === self ? nil : hit
        }
    }
}

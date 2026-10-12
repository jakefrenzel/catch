import SwiftUI
import UIKit

/// Puts toasts in their own window above the app, so they show (and Undo can be
/// tapped) even while a sheet is open. Add it once as a background of the root view.
struct ToastWindowInstaller: UIViewRepresentable {
    let model: AppModel

    func makeUIView(context: Context) -> InstallerView {
        InstallerView(model: model)
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        private let model: AppModel
        private var toastWindow: PassThroughWindow?

        init(model: AppModel) {
            self.model = model
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            // Keep the toast window's light/dark matching the app's, which can
            // differ from the system's when Appearance is set in Settings.
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: InstallerView, _) in
                view.toastWindow?.overrideUserInterfaceStyle = view.traitCollection.userInterfaceStyle
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard toastWindow == nil, let scene = window?.windowScene else { return }

            let toastWindow = PassThroughWindow(windowScene: scene)
            let host = UIHostingController(rootView: ToastLayer(window: toastWindow).environment(model))
            host.view.backgroundColor = .clear
            toastWindow.rootViewController = host
            toastWindow.windowLevel = .alert
            toastWindow.overrideUserInterfaceStyle = traitCollection.userInterfaceStyle
            toastWindow.isHidden = false
            self.toastWindow = toastWindow
        }
    }
}

/// A window that only takes touches inside the visible toast.
final class PassThroughWindow: UIWindow {
    var interactiveRect: CGRect = .null

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard interactiveRect.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

private struct ToastLayer: View {
    let window: PassThroughWindow

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            if let toast = model.toast {
                ToastView(toast: toast, onUndo: { model.undo() }, onDismiss: { model.dismissToast() })
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                        window.interactiveRect = frame
                    }
                    .onDisappear { window.interactiveRect = .null }
                    .transition(reduceMotion
                                ? .opacity
                                : .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.96)))
            }
            Spacer()
        }
        .animation(reduceMotion ? nil : .catchEaseOut(0.3), value: model.toast)
    }
}

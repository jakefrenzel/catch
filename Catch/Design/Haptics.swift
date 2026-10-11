import UIKit

/// The haptic events from the handoff's table.
enum Haptic {
    /// Swipe threshold, reminder saved, edit saved, phase added.
    case light
    /// Voice starts.
    case medium
    /// Item or Up first done.
    case success
    /// Now full, delete, missing project name.
    case warning
    /// Picker ticks, segmented controls.
    case selection

    @MainActor
    func play() {
        switch self {
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

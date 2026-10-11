import SwiftUI
import UIKit

/// Design tokens from the handoff. System colors are used where they match exactly.
enum Theme {
    static let bg = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let ink2 = Color(.secondaryLabel)
    static let ink3 = Color(light: rgba(60, 60, 67, 0.45), dark: rgba(235, 235, 245, 0.42))
    static let ink4 = Color(.tertiaryLabel)
    static let sep = Color(light: rgba(60, 60, 67, 0.12), dark: rgba(84, 84, 88, 0.6))
    static let fill = Color(light: rgba(120, 120, 128, 0.14), dark: rgba(120, 120, 128, 0.3))
    /// The selected segment in a segmented control.
    static let seg = Color(light: .white, dark: rgba(99, 99, 102, 1))

    static let blue = Color(.systemBlue)
    static let orange = Color(.systemOrange)
    /// Orange for text; meets contrast on light backgrounds.
    static let orangeText = Color(light: rgba(201, 52, 0, 1), dark: rgba(255, 159, 10, 1))
    static let red = Color(.systemRed)
    static let green = Color(.systemGreen)
    static let purple = Color(.systemIndigo)

    static let blueTint = blue.opacity(0.12)
    static let orangeTint = orange.opacity(0.15)
    static let greenTint = green.opacity(0.14)

    /// rgba(30,30,32,.92) in both appearances.
    static let toastBackground = Color(red: 30 / 255, green: 30 / 255, blue: 32 / 255).opacity(0.92)

    private static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> UIColor {
        UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }
}

extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

extension View {
    /// Card shadow: 0 4 16 rgba(0,0,0,.06).
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    /// Floating items: 0 8 24 rgba(0,0,0,.12).
    func floatingShadow() -> some View {
        shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
    }
}

extension Animation {
    /// cubic-bezier(.2,.8,.2,1), used for sheets and the pinned bar.
    static func catchEaseOut(_ duration: Double) -> Animation {
        .timingCurve(0.2, 0.8, 0.2, 1, duration: duration)
    }
}

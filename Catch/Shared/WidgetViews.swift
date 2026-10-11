import AppIntents
import SwiftUI
import WidgetKit

/// The home screen widget (12b–12d) for both sizes. Shared by the widget
/// extension and the app's debug gallery.
struct CatchWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .systemMedium:
            // Buttons span the full width under both columns so labels fit.
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    TopSpot(snapshot: snapshot, compact: false, part: .text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !snapshot.list.isEmpty {
                        SideList(title: snapshot.listTitle, items: snapshot.list)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer(minLength: 4)
                TopSpot(snapshot: snapshot, compact: false, part: .buttons)
            }
        case .accessoryRectangular:
            LockScreenUpFirst(snapshot: snapshot)
        default:
            TopSpot(snapshot: snapshot, compact: true)
        }
    }
}

/// The main block: label, title, detail, and the two buttons.
private struct TopSpot: View {
    enum Part { case all, text, buttons }

    let snapshot: WidgetSnapshot
    let compact: Bool
    var part: Part = .all

    var body: some View {
        if part == .buttons {
            buttons
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(labelColor)
                .lineLimit(1)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(compact ? 3 : 2)
                .minimumScaleFactor(0.85)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(Theme.ink2)
                .lineLimit(1)
            if part == .all {
                Spacer(minLength: 4)
                buttons
            }
        }
        .frame(maxWidth: .infinity, maxHeight: part == .all ? .infinity : nil, alignment: .topLeading)
    }

    @ViewBuilder
    private var buttons: some View {
        switch snapshot.mode {
        case .upFirst(let itemID, let stepID, _, _):
            HStack(spacing: 6) {
                if let itemID {
                    Button(intent: CompleteItemIntent(itemID: itemID)) { checkLabel }
                        .buttonStyle(.plain)
                } else if let stepID {
                    Button(intent: CompleteStepIntent(stepID: stepID)) { checkLabel }
                        .buttonStyle(.plain)
                }
                if let id = itemID ?? stepID {
                    Button(intent: SkipUpFirstIntent(id: id)) {
                        secondaryLabel(compact ? nil : "Skip", icon: "forward.fill")
                    }
                    .buttonStyle(.plain)
                }
            }
        case .laterDue(let itemID, _, _, _):
            HStack(spacing: 6) {
                Button(intent: CompleteItemIntent(itemID: itemID)) { checkLabel }
                    .buttonStyle(.plain)
                Button(intent: SnoozeItemIntent(itemID: itemID)) {
                    secondaryLabel(compact ? nil : "In 1 hour", icon: "clock.arrow.circlepath")
                }
                .buttonStyle(.plain)
            }
        case .evening(let left, _, _):
            if left > 0 {
                HStack(spacing: 6) {
                    Button(intent: AllToTomorrowIntent()) {
                        secondaryLabel(compact ? nil : "To Tomorrow", icon: "arrow.right.to.line", tint: Theme.orangeText)
                    }
                    .buttonStyle(.plain)
                    if !compact {
                        Link(destination: URL(string: "catch://today")!) {
                            secondaryLabel("Review", icon: nil)
                        }
                    }
                }
            }
        case .clear:
            EmptyView()
        }
    }

    private var checkLabel: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Theme.blue, in: Circle())
            .accessibilityLabel("Done")
    }

    private func secondaryLabel(_ title: String?, icon: String?, tint: Color = Theme.blue) -> some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon) }
            if let title { Text(title).lineLimit(1) }
        }
        .fixedSize()
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, title == nil ? 0 : 10)
        .frame(minWidth: 30, minHeight: 30)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private var label: String {
        switch snapshot.mode {
        case .upFirst: return "UP FIRST"
        case .laterDue(_, _, let time, _): return "LATER · \(time)"
        case .evening(_, _, let time): return "\(time) · WRAP UP"
        case .clear: return "TODAY"
        }
    }

    private var labelColor: Color {
        switch snapshot.mode {
        case .upFirst, .clear: return Theme.blue
        case .laterDue, .evening: return Theme.orangeText
        }
    }

    private var title: String {
        switch snapshot.mode {
        case .upFirst(_, _, let title, _), .laterDue(_, let title, _, _): return title
        case .evening(let left, _, _): return left == 0 ? "Nothing left for today" : "\(left) left for today"
        case .clear: return "Today is clear"
        }
    }

    private var detail: String {
        switch snapshot.mode {
        case .upFirst(_, _, _, let reason): return reason
        case .laterDue(_, _, _, let detail): return detail
        case .evening(_, let done, _): return "\(done) done today"
        case .clear(let done): return done > 0 ? "\(done) done" : "Nothing waiting"
        }
    }
}

private struct SideList: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.ink2)
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Circle()
                        .strokeBorder(Theme.ink4, lineWidth: 1.5)
                        .frame(width: 12, height: 12)
                    Text(item)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// 11f: Up first under the clock.
struct LockScreenUpFirst: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("UP FIRST")
                .font(.caption2.weight(.bold))
                .widgetAccentable()
            Text(title)
                .font(.headline)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: String {
        switch snapshot.mode {
        case .upFirst(_, _, let title, _), .laterDue(_, let title, _, _): return title
        case .evening(let left, _, _): return "\(left) left for today"
        case .clear: return "Today is clear"
        }
    }
}

/// 11f: the Inbox count.
struct LockScreenInboxCount: View {
    let count: Int

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(count)")
                    .font(.title2.weight(.semibold))
                Text("Inbox")
                    .font(.system(size: 9, weight: .semibold))
            }
        }
        .accessibilityLabel("\(count) in Inbox")
    }
}

/// 11f: the mic button that opens Catch listening.
struct LockScreenMic: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "mic.fill")
                .font(.title2.weight(.semibold))
        }
        .accessibilityLabel("Catch a thought by voice")
    }
}

import Foundation

/// The four lists every item lives in.
enum ListKind: String, Codable, CaseIterable, Identifiable {
    case inbox, now, later, someday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .now: return "Now"
        case .later: return "Later"
        case .someday: return "Someday"
        }
    }
}

/// Whether a place reminder fires on leaving or arriving.
enum PlaceTrigger: String, Codable, CaseIterable {
    case leave, arrive
}

/// When a Later item comes back: at a time, or on leaving/arriving at a place.
enum ReminderTime: Equatable {
    case date(Date)
    case place(PlaceTrigger, Place)
}

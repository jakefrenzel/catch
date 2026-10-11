/// The "why" line shown under an Up first suggestion.
enum Reason {
    static let justAdded = "You just added it to Now"
    static let sortedFromInbox = "Sorted into Now from Inbox"
    static let movedUpFromLater = "Moved up from Later"
    static let pulledFromSomeday = "Pulled in from Someday"
    static let movedToNow = "Moved to Now"
    static let swappedIn = "Swapped into Now"
    static let carriedOver = "Carried over from last night"
    static let firstOpenInNow = "First open item in Now"

    static func nextStep(in project: String) -> String { "Next step in \(project)" }

    static func intoNow(from list: ListKind) -> String {
        switch list {
        case .inbox: return sortedFromInbox
        case .later: return movedUpFromLater
        case .someday: return pulledFromSomeday
        case .now: return movedToNow
        }
    }
}

#if DEBUG
import Foundation
import SwiftData

/// The prototype's demo content, for running the app in the simulator.
/// Loaded when the app is launched with `-seedSampleData` and the database is empty.
enum SampleData {
    @MainActor
    static func seedIfEmpty(_ store: CatchStore) {
        guard store.allItems().isEmpty, store.projects().isEmpty, store.places().isEmpty else { return }
        let context = store.context
        let calendar = store.calendar
        let now = Date.now

        @discardableResult
        func item(_ text: String, _ list: ListKind, reason: String? = nil, minutesAgo: Int) -> Item {
            let item = Item(text: text, list: list, capturedAt: now.addingTimeInterval(TimeInterval(-minutesAgo * 60)))
            item.reason = reason
            context.insert(item)
            return item
        }

        item("Send Q3 invoice to Halden", .now, reason: "In Now since Tuesday · about 10 min", minutesAgo: 600)
        item("Call Dana about the lease", .now, reason: "Added to Now this morning", minutesAgo: 590)

        let dryCleaning = item("Pick up dry cleaning", .later, minutesAgo: 580)
        dryCleaning.reminder = .date(TimeOfDay(hour: 17, minute: 30).next(after: now, calendar: calendar))
        let dentist = item("Book dentist for Mia", .later, minutesAgo: 570)
        let monday = calendar.nextDate(after: now, matching: DateComponents(hour: 9, minute: 0, weekday: 2),
                                       matchingPolicy: .nextTime) ?? now
        dentist.reminder = .date(monday)

        item("Renew passport before the Lisbon trip", .inbox, minutesAgo: 400)
        item("Cancel the unused gym plan", .inbox, minutesAgo: 300)
        item("Newsletter: write about pricing", .inbox, minutesAgo: 200)
        item("Gift idea for Sam: film camera", .inbox, minutesAgo: 100)

        item("Learn to make fresh pasta", .someday, minutesAgo: 9000)
        item("Repaint the hallway", .someday, minutesAgo: 8000)
        item("Start a herb garden", .someday, minutesAgo: 7000)

        context.insert(Place(name: "Home", address: "Rowan Ave", latitude: 51.5416, longitude: -0.1430,
                             radiusMeters: 100))
        context.insert(Place(name: "Office", address: "Halden Studio, 14 Mill St", latitude: 51.5246,
                             longitude: -0.0786, radiusMeters: 150))

        func project(_ name: String, order: Int, expanded: Bool, steps: [(String, String, Bool)]) {
            let project = Project(name: name, sortOrder: order, createdAt: now)
            project.isExpanded = expanded
            context.insert(project)
            let models = steps.enumerated().map { index, step in
                let model = Step(text: step.0, phase: step.1, sortOrder: index)
                if step.2 { model.completedAt = now }
                context.insert(model)
                return model
            }
            project.steps = models
        }

        project("Kitchen Reno", order: 0, expanded: true, steps: [
            ("Measure the wall", "Plan", true), ("Set a budget", "Plan", true),
            ("Order cabinet samples", "Choose", false), ("Pick countertop", "Choose", false),
            ("Get 3 contractor quotes", "Build", false), ("Book electrician", "Build", false),
        ])
        project("Lisbon Trip", order: 1, expanded: false, steps: [
            ("Book flights", "Book", true), ("Book hotel", "Book", true),
            ("Plan day trips", "Prepare", true), ("Renew passport", "Prepare", false),
        ])

        try? context.save()
    }
}
#endif

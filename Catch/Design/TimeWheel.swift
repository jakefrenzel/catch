import SwiftUI
import UIKit

/// Hour / minute / AM-PM wheels in 15-minute steps. SwiftUI's DatePicker can't
/// set a minute interval, so this wraps UIDatePicker.
struct TimeWheel: UIViewRepresentable {
    @Binding var time: Date

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = 15
        picker.date = time
        picker.setContentHuggingPriority(.defaultLow, for: .horizontal)
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.parent = self
        if picker.date != time {
            picker.setDate(time, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: TimeWheel

        init(parent: TimeWheel) {
            self.parent = parent
        }

        @objc func changed(_ picker: UIDatePicker) {
            parent.time = picker.date
        }
    }
}

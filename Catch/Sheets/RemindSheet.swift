import SwiftData
import SwiftUI

/// 6g: pick when a Later item comes back, from suggestions or a date and time.
struct RemindSheet: View {
    let item: Item

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Place.name) private var places: [Place]

    /// nil means the custom date and time from the picker.
    @State private var selection: RemindOption.Kind?
    @State private var isPicking = false
    @State private var pickedDay: Date
    @State private var pickedTime: Date
    @State private var hasPicked: Bool
    /// An earlier custom time, saved exactly as it was until the day or time is changed. The
    /// wheel only has quarter hours, so rounding it would move it, past midnight even a day.
    @State private var keptDate: Date?
    @State private var nudge: Bool

    private let formatter = ReminderFormatter()

    init(item: Item, settings: CatchSettings) {
        self.item = item
        let calendar = Calendar.current
        let now = Date.now
        let tomorrow = DayClock.tomorrow(after: now, calendar: calendar)
        let options = RemindOptions.options(now: now, calendar: calendar, afterWork: settings.afterWork, places: [])

        var selection: RemindOption.Kind? = .afterWork
        var day = tomorrow
        var time = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        var hasPicked = false
        var keptDate: Date?
        switch item.reminder {
        case .place(let trigger, let place):
            selection = trigger == .leave ? .leave(place.id) : .arrive(place.id)
        case .date(let date):
            if let match = options.first(where: { $0.date == date }) {
                selection = match.kind
            } else if date > now {
                // An earlier custom time: keep it selected so saving doesn't lose it.
                selection = nil
                hasPicked = true
                day = calendar.startOfDay(for: date)
                time = date
                keptDate = date
            }
        case nil:
            break
        }

        _selection = State(initialValue: selection)
        _pickedDay = State(initialValue: day)
        _pickedTime = State(initialValue: RemindOptions.roundedToQuarterHour(time, calendar: calendar))
        _hasPicked = State(initialValue: hasPicked)
        _keptDate = State(initialValue: keptDate)
        _nudge = State(initialValue: item.nudge ?? settings.nudgeDefault)
    }

    var body: some View {
        let now = Date.now
        let options = RemindOptions.options(now: now, calendar: .current,
                                            afterWork: model.settings.afterWork, places: places,
                                            offerLeave: model.settings.offerLeave,
                                            offerArrive: model.settings.offerArrive)

        VStack(spacing: 14) {
            header
            if isPicking {
                picker(now: now)
            } else {
                optionsCard(options, now: now)
                nudgeCard
            }
        }
        .padding(EdgeInsets(top: 22, leading: 16, bottom: 20, trailing: 16))
        .fittedSheet()
        .onChange(of: pickedDay) { keptDate = nil }
        .onChange(of: pickedTime) { keptDate = nil }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-remindPicking") { pickCustom() }
        }
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            SheetCloseButton { dismiss() }
            VStack(spacing: 1) {
                Text("Remind Me")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(item.text)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            SheetSaveButton(action: save)
        }
    }

    // MARK: - Suggestions

    private func optionsCard(_ options: [RemindOption], now: Date) -> some View {
        VStack(spacing: 0) {
            ForEach(options) { option in
                optionRow(title: option.title,
                          subtitle: subtitle(for: option, now: now),
                          icon: icon(for: option.kind),
                          tint: tint(for: option.kind),
                          isSelected: selection == option.kind,
                          showsSeparator: true) {
                    model.haptic(.selection)
                    selection = option.kind
                }
            }
            optionRow(title: "Pick date and time",
                      subtitle: hasPicked ? formatter.label(for: pickedDate, now: now) : nil,
                      icon: "calendar",
                      tint: Theme.red,
                      isSelected: selection == nil,
                      showsSeparator: false,
                      action: pickCustom)
        }
        .padding(.leading, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func optionRow(title: String, subtitle: String?, icon: String, tint: Color,
                           isSelected: Bool, showsSeparator: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Theme.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                }
            }
            .padding(.vertical, 10)
            .padding(.trailing, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                Theme.sep.frame(height: 1).padding(.leading, 40)
            }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var nudgeCard: some View {
        Toggle(isOn: $nudge) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Nudge again if I miss it")
                Text("Once, 30 min later")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Date and time

    private func picker(now: Date) -> some View {
        VStack(spacing: 12) {
            Button {
                isPicking = false
                // Back to the suggestions means choosing one of them again.
                if selection == nil { selection = .afterWork }
            } label: {
                Label("Suggestions", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.blue)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, -10)

            VStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(RemindOptions.pickerDays(now: now, calendar: .current), id: \.self) { day in
                            dayChip(day, now: now)
                        }
                    }
                }
                TimeWheel(time: $pickedTime)
                    .frame(height: 180)
                    .clipped()
                    .mask {
                        // Fade the wheels out at the edges, like the prototype.
                        LinearGradient(stops: [.init(color: .clear, location: 0),
                                               .init(color: .black, location: 0.3),
                                               .init(color: .black, location: 0.7),
                                               .init(color: .clear, location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(formatter.longLabel(for: pickedDate))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(pickedDate > now ? Theme.orangeText : Theme.red)
                .accessibilityLabel("Reminder: \(formatter.longLabel(for: pickedDate))")
        }
    }

    private func dayChip(_ day: Date, now: Date) -> some View {
        let isSelected = Calendar.current.isDate(day, inSameDayAs: pickedDay)
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        return Button {
            model.haptic(.selection)
            pickedDay = day
        } label: {
            VStack(spacing: 1) {
                Text(isToday ? "Today" : day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(day.formatted(.dateTime.day()))
                    .font(.title3.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : Color.primary)
            .frame(width: 48)
            .padding(.vertical, 7)
            .background(isSelected ? Theme.blue : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Helpers

    private var pickedDate: Date {
        keptDate ?? RemindOptions.combine(day: pickedDay, time: pickedTime, calendar: .current)
    }

    private func pickCustom() {
        model.haptic(.selection)
        selection = nil
        hasPicked = true
        isPicking = true
    }

    private func subtitle(for option: RemindOption, now: Date) -> String? {
        switch option.reminder {
        case .place(_, let place):
            return place.address
        case .date(let date):
            let label = formatter.label(for: date, now: now)
            return option.kind == .afterWork ? "\(label) · when you usually leave" : label
        }
    }

    private func icon(for kind: RemindOption.Kind) -> String {
        switch kind {
        case .afternoon, .tomorrowMorning: return "sun.max.fill"
        case .afterWork: return "clock.fill"
        case .tonight: return "moon.fill"
        case .leave: return "location.fill"
        case .arrive: return "mappin.and.ellipse"
        }
    }

    private func tint(for kind: RemindOption.Kind) -> Color {
        switch kind {
        case .afternoon, .afterWork, .tomorrowMorning: return Theme.orange
        case .tonight: return Theme.purple
        case .leave, .arrive: return Theme.green
        }
    }

    private func save() {
        let now = Date.now
        if selection == nil {
            let date = pickedDate
            guard date > now else {
                model.haptic(.warning)
                model.flash("Pick a time that hasn't passed yet", undo: false)
                return
            }
            model.setReminder(item, .date(date), nudge: nudge, label: formatter.label(for: date, now: now))
        } else {
            let options = RemindOptions.options(now: now, calendar: .current,
                                                afterWork: model.settings.afterWork, places: places,
                                                offerLeave: model.settings.offerLeave,
                                                offerArrive: model.settings.offerArrive)
            guard let option = options.first(where: { $0.kind == selection }) ?? options.first(where: { $0.kind == .afterWork }) else {
                return
            }
            model.setReminder(item, option.reminder, nudge: nudge, label: option.title)
        }
    }
}

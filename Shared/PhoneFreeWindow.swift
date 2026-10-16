//
//  PhoneFreeWindow.swift
//  Shared
//
//  A recurring phone-free window, e.g. "10pm - 7am". Compiled into both
//  targets so the model is available everywhere; scheduling happens in the
//  app.
//
import Foundation

nonisolated struct PhoneFreeWindow: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    /// Whether notifications for this window are enabled.
    var enabled: Bool = true
    /// Label shown in the UI (optional).
    var label: String = ""
    /// Hour and minute of the start (local time).
    var startHour: Int = 22
    var startMinute: Int = 0
    /// Hour and minute of the end (local time).
    var endHour: Int = 7
    var endMinute: Int = 0

    var isOvernight: Bool {
        startHour > endHour || (startHour == endHour && startMinute > endMinute)
    }

    /// Start time as DateComponents for a given day.
    func startComponents(for date: Date = Date()) -> DateComponents {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = startHour
        components.minute = startMinute
        components.second = 0
        return components
    }

    /// End time as DateComponents for a given day. For overnight windows, end
    /// is on the next calendar day.
    func endComponents(for date: Date = Date()) -> DateComponents {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        if isOvernight {
            // Get the next day
            if let next = Calendar.current.date(byAdding: .day, value: 1, to: date) {
                let nextComponents = Calendar.current.dateComponents([.year, .month, .day], from: next)
                components.year = nextComponents.year
                components.month = nextComponents.month
                components.day = nextComponents.day
            }
        }
        components.hour = endHour
        components.minute = endMinute
        components.second = 0
        return components
    }

    /// What to show where a name would be, so an unnamed window never reads
    /// as an empty row.
    var displayName: String {
        label.isEmpty ? "Phone-free window" : label
    }

    var summary: String {
        let start = String(format: "%02d:%02d", startHour, startMinute)
        let end = String(format: "%02d:%02d", endHour, endMinute)
        return "\(start) – \(end)"
    }

    /// The end of the occurrence `now` falls inside, or `nil` when the tap came
    /// outside the window — a stale reminder — so the caller can fall back to a
    /// normal goal rather than inventing a length.
    ///
    /// Anchored on today and yesterday, which is what handles an overnight
    /// window: at 03:00 the window started last night.
    func endIfInside(at now: Date) -> Date? {
        let calendar = Calendar.current

        for dayOffset in [0, -1] {
            guard let day = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: now
            ),
            let start = calendar.date(
                bySettingHour: startHour,
                minute: startMinute,
                second: 0,
                of: day
            ) else { continue }

            var end = calendar.date(
                bySettingHour: endHour,
                minute: endMinute,
                second: 0,
                of: start
            ) ?? start

            // Equal times would mean a zero-length window; treat it as
            // running into the next day.
            if end <= start {
                end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            }

            if now >= start, end > now {
                return end
            }
        }

        return nil
    }
}

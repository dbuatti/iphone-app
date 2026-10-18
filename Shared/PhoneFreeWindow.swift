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

    /// The defaults key these are persisted under — shared with
    /// PhoneFreeUsage.load(), which reads them for the record maths, and
    /// PhoneFreeStore, which owns the editing.
    static let defaultsKey = "phoneFreeWindows"

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

    // MARK: - Record maths

    /// How much of `[from, to]` falls inside any of these windows — every
    /// recurring occurrence of each, so an overnight window is found even
    /// when the span begins in the middle of last night's run.
    ///
    /// This is what records subtract: a stretch running through planned
    /// phone-free time (sleep above all) is not an achievement just because
    /// nobody touched the phone — the hours outside the windows are the ones
    /// that were actually chosen. Occurrences are merged before summing, so
    /// overlapping windows are never subtracted twice, and the result can
    /// never exceed the span itself.
    ///
    /// The day walk stops at a year. Spans that long are not gaps this app
    /// models; stopping early can only *under*-subtract, which keeps the
    /// mathematically absurd case boring rather than wrong in a way that
    /// invents time.
    static func overlap(
        from: Date,
        to: Date,
        in windows: [PhoneFreeWindow]
    ) -> TimeInterval {
        guard to > from, !windows.isEmpty else { return 0 }

        let calendar = Calendar.current
        var occurrences: [(start: Date, end: Date)] = []

        for window in windows {
            // One day early: at 03:00 the overnight window started yesterday.
            guard var day = calendar.date(
                byAdding: .day,
                value: -1,
                to: calendar.startOfDay(for: from)
            ) else { continue }

            var walked = 0

            while walked < 366 {
                defer {
                    day = calendar.date(
                        byAdding: .day, value: 1, to: day
                    ) ?? day
                    walked += 1
                }

                guard let start = calendar.date(
                    bySettingHour: window.startHour,
                    minute: window.startMinute,
                    second: 0,
                    of: day
                ) else { continue }

                // Occurrences only start later from here on.
                if start > to { break }

                var end = calendar.date(
                    bySettingHour: window.endHour,
                    minute: window.endMinute,
                    second: 0,
                    of: start
                ) ?? start

                // Equal times would mean a zero-length window; it runs into
                // the next day — the same reading `endIfInside` gives it.
                if end <= start {
                    end = calendar.date(byAdding: .day, value: 1, to: end)
                        ?? end
                }

                let lower = max(start, from)
                let upper = min(end, to)

                if upper > lower {
                    occurrences.append((lower, upper))
                }
            }
        }

        guard !occurrences.isEmpty else { return 0 }

        occurrences.sort { $0.start < $1.start }

        var total: TimeInterval = 0
        var currentStart = occurrences[0].start
        var currentEnd = occurrences[0].end

        for interval in occurrences.dropFirst() {
            if interval.start <= currentEnd {
                currentEnd = max(currentEnd, interval.end)
            } else {
                total += currentEnd.timeIntervalSince(currentStart)
                currentStart = interval.start
                currentEnd = interval.end
            }
        }

        total += currentEnd.timeIntervalSince(currentStart)
        return total
    }
}

import Foundation

// MARK: - §1.3 Rest Strategy → Study-Day Axis

/// Pure-function computations for the study-day axis.
/// All functions take explicit date parameters — no `Date()` or `Calendar.current` calls.
public enum RestSchedule {

    // MARK: - Calendar Helpers

    /// Kernel-canonical calendar: Gregorian pinned to UTC. Every y/m/d ↔ Date conversion
    /// inside the kernel goes through this, so the same `Date` value yields the same plan
    /// on every host time zone. The app layer converts the user's local "today" into a
    /// canonical Date via `canonicalDate(from:in:)` before calling the kernel.
    public static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// Map an arbitrary timestamp to the kernel-canonical Date (midnight UTC) of the
    /// calendar day it falls on in `timeZone`. This is the app-layer boundary: pass the
    /// user's time zone here, and the kernel stays time-zone-free beyond this point.
    public static func canonicalDate(from date: Date, in timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return dateFrom(c.year!, c.month!, c.day!)
    }

    /// Returns the number of days in a given month (1-indexed).
    public static func daysInMonth(year: Int, month: Int) -> Int {
        var dc = DateComponents()
        dc.year = year
        dc.month = month
        dc.day = 1
        guard let date = calendar.date(from: dc),
              let range = calendar.range(of: .day, in: .month, for: date)
        else { return 30 }
        return range.count
    }

    /// Extracts year, month, day from a Date using the kernel-canonical calendar.
    public static func dateComponents(_ date: Date) -> (year: Int, month: Int, day: Int) {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return (comps.year!, comps.month!, comps.day!)
    }

    /// Date from year/month/day.
    public static func dateFrom(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var dc = DateComponents()
        dc.year = year
        dc.month = month
        dc.day = day
        return calendar.date(from: dc)!
    }

    /// Format a Date as "yyyy-MM-dd".
    public static func dateString(_ date: Date) -> String {
        let (y, m, d) = dateComponents(date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// Parse "yyyy-MM-dd" to Date.
    public static func parseDate(_ str: String) -> Date? {
        let parts = str.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        return dateFrom(y, m, d)
    }

    // MARK: - Skeleton Study-Day Computation

    /// Computes the skeleton day types for a full month.
    /// Returns an array indexed by day-of-month (1-based) → DayType for the cycle.
    /// For example, study5/rest2 → [study, study, study, study, study, rhythmRest, rhythmRest, ...].
    public static func monthSkeleton(
        year: Int, month: Int, strategy: RestStrategy
    ) -> [DayType] {
        let n = daysInMonth(year: year, month: month)
        let cycleLen = strategy.cycleStudy + strategy.cycleRest
        var result: [DayType] = []
        for day in 1...n {
            // day 1-based; cycle index 0-based
            let idx = (day - 1) % cycleLen
            if idx < strategy.cycleStudy {
                result.append(.study)
            } else {
                result.append(.rhythmRest)
            }
        }
        return result
    }

    /// Count of backbone study days in the full month.
    public static func backboneStudyDays(
        year: Int, month: Int, strategy: RestStrategy
    ) -> Int {
        monthSkeleton(year: year, month: month, strategy: strategy)
            .filter { $0 == .study }.count
    }

    /// Guaranteed study days = backbone − flex pool.
    public static func studyDaysTotal(
        year: Int, month: Int, strategy: RestStrategy
    ) -> Int {
        backboneStudyDays(year: year, month: month, strategy: strategy) - strategy.flexRestTotal
    }

    /// Count of remaining backbone study days from `tomorrow` through end of month.
    public static func remainingBackboneStudyDays(
        year: Int, month: Int, strategy: RestStrategy, tomorrowDay: Int
    ) -> Int {
        let skeleton = monthSkeleton(year: year, month: month, strategy: strategy)
        let n = skeleton.count
        var count = 0
        for day in tomorrowDay...n {
            if skeleton[day - 1] == .study { count += 1 }
        }
        return count
    }

    /// Remaining flexible rest days.
    public static func remainingFlex(strategy: RestStrategy) -> Int {
        strategy.flexRestTotal - strategy.flexUsed
    }

    /// study_days_remaining = max(rem_backbone_study − rem_flex, 1)
    public static func studyDaysRemaining(
        year: Int, month: Int, strategy: RestStrategy, tomorrowDay: Int
    ) -> Int {
        let remBackbone = remainingBackboneStudyDays(
            year: year, month: month, strategy: strategy, tomorrowDay: tomorrowDay
        )
        let remFlex = remainingFlex(strategy: strategy)
        return max(remBackbone - remFlex, 1)
    }

    /// study_days_elapsed = study_days_total − study_days_remaining
    public static func studyDaysElapsed(
        year: Int, month: Int, strategy: RestStrategy, tomorrowDay: Int
    ) -> Int {
        let total = studyDaysTotal(year: year, month: month, strategy: strategy)
        let remaining = studyDaysRemaining(
            year: year, month: month, strategy: strategy, tomorrowDay: tomorrowDay
        )
        return total - remaining
    }

    // MARK: - Convenience: Fill Derived Fields on MonthState

    /// Mutates the given MonthState, filling in backboneStudyDays, studyDaysTotal,
    /// studyDaysRemaining, studyDaysElapsed based on the given `today`.
    public static func fillDerived(state: inout MonthState, today: Date) {
        let (y, m, d) = dateComponents(today)
        let tomorrowDay = d + 1   // "tomorrow" in the spec means next calendar day onwards
        let n = daysInMonth(year: y, month: m)
        let effectiveTomorrow = min(tomorrowDay, n + 1) // clamp: if today is last day, remaining=0 backbone

        state.backboneStudyDays = backboneStudyDays(year: y, month: m, strategy: state.restStrategy)
        state.studyDaysTotal = studyDaysTotal(year: y, month: m, strategy: state.restStrategy)
        state.studyDaysRemaining = studyDaysRemaining(
            year: y, month: m, strategy: state.restStrategy, tomorrowDay: effectiveTomorrow
        )
        state.studyDaysElapsed = studyDaysElapsed(
            year: y, month: m, strategy: state.restStrategy, tomorrowDay: effectiveTomorrow
        )
    }
}

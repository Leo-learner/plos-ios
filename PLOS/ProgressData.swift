import Foundation
import SwiftUI
import SwiftData
import PLOSKernel

// MARK: - Phase P §1: Progress Dashboard

/// Pure-computed progress data for display — no predictions, just arithmetic.
struct GoalProgressSummary: Identifiable {
    var id: String { goalId }
    let goalId: String
    let subject: String
    let unit: String
    let progress: Double        // 0…1
    let threshold: Double       // successThreshold
    let isPassed: Bool
    let baselineToday: Double   // units/day needed to hit 100% by deadline
    let projectedFinishPct: Double  // deterministic: progress now + baseline × remaining
    let total: Double
    let done: Double
}

struct LoadSummary: Identifiable {
    var id: String { dateStr }
    let dateStr: String
    let plannedMinutes: Int
    let actualPct: Double
    let isStudyDay: Bool
}

struct StreakDay: Identifiable {
    var id: String { dateStr }
    let dateStr: String
    let systemRan: Bool
    let isStudyDay: Bool
}

// MARK: - Computation Helpers

extension AppViewModel {
    /// Compute all goal progress summaries for the active month.
    func computeProgressSummaries() -> [GoalProgressSummary] {
        guard let month = activeMonth else { return [] }
        let state = month.toMonthState(today: today)
        let scored = Scoring.scoreAll(goals: state.goals,
                                       studyDaysElapsed: state.studyDaysElapsed,
                                       studyDaysTotal: state.studyDaysTotal,
                                       studyDaysRemaining: state.studyDaysRemaining)
        return scored.map { s in
            let rem = Double(state.studyDaysRemaining)
            let projected = s.progress + s.baselineToday * rem / max(s.goal.total, 1e-9)
            return GoalProgressSummary(
                goalId: s.goalId,
                subject: s.goal.subject,
                unit: s.goal.unit,
                progress: s.progress,
                threshold: s.goal.successThreshold,
                isPassed: s.progress >= s.goal.successThreshold,
                baselineToday: s.baselineToday,
                projectedFinishPct: min(projected, 1.0),
                total: s.goal.total,
                done: s.goal.done
            )
        }
    }

    /// Compute daily load summary for the month.
    func computeLoadHistory() -> [LoadSummary] {
        guard let month = activeMonth else { return [] }
        let cal = Calendar(identifier: .gregorian)
        let (y, m, _) = RestSchedule.dateComponents(today)
        let n = RestSchedule.daysInMonth(year: y, month: m)

        var result: [LoadSummary] = []
        for day in 1...n {
            let dateStr = RestSchedule.dateString(RestSchedule.dateFrom(y, m, day))
            guard let dayEntity = month.days.first(where: { $0.date == dateStr }) else { continue }
            let planned = dayEntity.plannedItems.reduce(0) { $0 + $1.minutes }
            let reports = dayEntity.reportItems
            let avgPct: Double = reports.isEmpty ? 0 : reports.reduce(0.0) { $0 + Double($1.completionPct) } / Double(reports.count)
            let isStudy = dayEntity.rawDayType == "study"
            result.append(LoadSummary(dateStr: dateStr, plannedMinutes: planned,
                                      actualPct: avgPct / 100.0, isStudyDay: isStudy))
        }
        return result
    }

    /// Streak calendar data for the current month.
    func computeStreakCalendar() -> [StreakDay] {
        guard let month = activeMonth else { return [] }
        let cal = Calendar(identifier: .gregorian)
        let (y, m, _) = RestSchedule.dateComponents(today)
        let n = RestSchedule.daysInMonth(year: y, month: m)

        return (1...n).map { day in
            let dateStr = RestSchedule.dateString(RestSchedule.dateFrom(y, m, day))
            let dayEntity = month.days.first(where: { $0.date == dateStr })
            return StreakDay(dateStr: dateStr,
                             systemRan: dayEntity?.systemRan ?? false,
                             isStudyDay: dayEntity?.rawDayType == "study")
        }
    }
}

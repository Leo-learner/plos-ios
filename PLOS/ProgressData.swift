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

/// P4: habit success = completed study days ÷ study days that have occurred (§1.4).
struct HabitProgressSummary: Identifiable {
    var id: String { goalId }
    let goalId: String
    let subject: String
    let completedDays: Int
    let studyDaysSoFar: Int
    let threshold: Double       // successThreshold
    var rate: Double { studyDaysSoFar > 0 ? Double(completedDays) / Double(studyDaysSoFar) : 0 }
    var isPassed: Bool { rate >= threshold }
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

    /// P4: habit goals measured as "completed study days ÷ study days so far".
    /// A day counts as completed when its report has completionPct > 0 for the habit (§1.9).
    func computeHabitSummaries() -> [HabitProgressSummary] {
        guard let month = activeMonth else { return [] }
        let habitGoals = month.goals
            .filter { $0.rawType == "habit" }
            .sorted { $0.subject < $1.subject }
        guard !habitGoals.isEmpty else { return [] }

        // "yyyy-MM-dd" strings compare correctly as text.
        let occurredStudyDays = month.days.filter { $0.rawDayType == "study" && $0.date <= todayStr }
        return habitGoals.map { goal in
            let completed = occurredStudyDays.filter { day in
                day.reportItems.contains { $0.goalId == goal.uid && $0.completionPct > 0 }
            }.count
            return HabitProgressSummary(
                goalId: goal.uid,
                subject: goal.subject,
                completedDays: completed,
                studyDaysSoFar: occurredStudyDays.count,
                threshold: goal.successThreshold
            )
        }
    }

    /// Compute daily load summary for the month.
    func computeLoadHistory() -> [LoadSummary] {
        guard let month = activeMonth else { return [] }
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

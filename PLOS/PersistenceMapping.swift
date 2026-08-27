import Foundation
import SwiftUI
import SwiftData
import PLOSKernel

// MARK: - Mapping: Entity → Kernel Types

extension GoalEntity {
    var kernelGoalType: PLOSKernel.GoalType {
        switch rawType {
        case "habit":     return PLOSKernel.GoalType.habit
        case "milestone": return PLOSKernel.GoalType.milestone
        default:          return PLOSKernel.GoalType.deadline
        }
    }

    func toKernelGoal() -> Goal {
        Goal(
            id: uid,
            subject: subject,
            type: kernelGoalType,
            target: targetDesc,
            unit: unit,
            total: total,
            done: done,
            start: startDate,
            deadline: deadlineDate,
            importance: importance,
            successThreshold: successThreshold,
            historyDelay: historyDelay
        )
    }
}

extension DayEntity {
    var kernelDayType: PLOSKernel.DayType {
        switch rawDayType {
        case "rhythmRest": return PLOSKernel.DayType.rhythmRest
        case "flexRest":   return PLOSKernel.DayType.flexRest
        default:           return PLOSKernel.DayType.study
        }
    }
    var kernelEnergy: PLOSKernel.Energy? {
        guard let e = rawEnergy else { return nil }
        switch e {
        case "high": return PLOSKernel.Energy.high
        case "low":  return PLOSKernel.Energy.low
        default:     return PLOSKernel.Energy.normal
        }
    }

    func toKernelDay() -> Day {
        Day(
            date: date,
            dayType: kernelDayType,
            energy: kernelEnergy,
            planned: plannedItems.map { $0.toKernelPlannedItem() },
            reported: reportItems.map { $0.toKernelReportItem() },
            systemRan: systemRan,
            note: note
        )
    }
}

extension PlannedItemEntity {
    func toKernelPlannedItem() -> PlannedItem {
        PlannedItem(goalId: goalId, minutes: minutes, label: label,
                    plannedUnits: plannedUnits, order: order)
    }
}

extension ReportItemEntity {
    func toKernelReportItem() -> ReportItem {
        ReportItem(goalId: goalId, completionPct: completionPct)
    }
}

extension EventEntity {
    func toKernelEvent() -> Event {
        Event(type: eventType, subject: subject, date: date)
    }
}

extension MonthEntity {
    func toRestStrategy() -> RestStrategy {
        RestStrategy(cycleStudy: cycleStudy, cycleRest: cycleRest,
                     flexRestTotal: flexRestTotal, flexUsed: flexUsed)
    }

    /// Assemble a kernel MonthState from the persisted month.
    func toMonthState(today: Date) -> MonthState {
        let daysDict = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0.toKernelDay()) })
        var state = MonthState(
            goals: goals.map { $0.toKernelGoal() },
            days: daysDict,
            restStrategy: toRestStrategy(),
            events: events.map { $0.toKernelEvent() },
            health: Health(),       // health data not persisted yet
            streak: 0               // filled below
        )
        RestSchedule.fillDerived(state: &state, today: today)
        // streak computed separately by scanning systemRan
        state.streak = computeStreak(today: today)
        return state
    }

    /// Compute consecutive systemRan days ending at (or before) `today`.
    func computeStreak(today: Date) -> Int {
        let cal = RestSchedule.calendar
        let todayStr = RestSchedule.dateString(today)
        // Build a lookup of systemRan = true
        let ranSet = Set(days.filter { $0.systemRan }.map { $0.date })
        var count = 0
        var cursor = todayStr
        while ranSet.contains(cursor) {
            count += 1
            guard let d = RestSchedule.parseDate(cursor),
                  let prev = cal.date(byAdding: .day, value: -1, to: d) else { break }
            cursor = RestSchedule.dateString(prev)
        }
        return count
    }
}

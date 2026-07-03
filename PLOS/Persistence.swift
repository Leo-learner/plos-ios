import Foundation
import SwiftData

// MARK: - SwiftData @Model: Persistence Layer for PLOS

/// Top-level month container. One per calendar month per user.


@Model
final class MonthEntity {
    var year: Int
    var month: Int    // 1–12
    var cycleStudy: Int
    var cycleRest: Int
    var flexRestTotal: Int
    var flexUsed: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade) var goals: [GoalEntity] = []
    @Relationship(deleteRule: .cascade) var days: [DayEntity] = []
    @Relationship(deleteRule: .cascade) var events: [EventEntity] = []

    init(year: Int, month: Int, cycleStudy: Int, cycleRest: Int, flexRestTotal: Int) {
        self.year = year
        self.month = month
        self.cycleStudy = cycleStudy
        self.cycleRest = cycleRest
        self.flexRestTotal = flexRestTotal
        self.flexUsed = 0
        self.createdAt = Date()
    }
}

// MARK: - Goal

@Model
final class GoalEntity {
    var uid: String                // stable id like "math"
    var subject: String
    var rawType: String            // "deadline" | "habit" | "milestone"
    var targetDesc: String         // e.g. "完成6章"
    var unit: String               // e.g. "章"
    var total: Double
    var done: Double
    var startDate: Date
    var deadlineDate: Date
    var importance: Double
    var successThreshold: Double   // e.g. 0.8
    var historyDelay: Int

    var month: MonthEntity?

    init(uid: String, subject: String, rawType: String,
         targetDesc: String, unit: String,
         total: Double, done: Double = 0,
         startDate: Date, deadlineDate: Date,
         importance: Double = 1.0, successThreshold: Double = 0.8,
         historyDelay: Int = 0) {
        self.uid = uid
        self.subject = subject
        self.rawType = rawType
        self.targetDesc = targetDesc
        self.unit = unit
        self.total = total
        self.done = done
        self.startDate = startDate
        self.deadlineDate = deadlineDate
        self.importance = importance
        self.successThreshold = successThreshold
        self.historyDelay = historyDelay
    }

    var goalType: String { rawType }
}

// MARK: - Day

@Model
final class DayEntity {
    var date: String               // "yyyy-MM-dd"
    var rawDayType: String         // "study" | "rhythmRest" | "flexRest"
    var rawEnergy: String?         // "high" | "normal" | "low"
    var systemRan: Bool
    var note: String?

    @Relationship(deleteRule: .nullify) var plannedItems: [PlannedItemEntity] = []
    @Relationship(deleteRule: .nullify) var reportItems: [ReportItemEntity] = []

    var month: MonthEntity?

    init(date: String, rawDayType: String, rawEnergy: String? = nil,
         systemRan: Bool = false, note: String? = nil) {
        self.date = date
        self.rawDayType = rawDayType
        self.rawEnergy = rawEnergy
        self.systemRan = systemRan
        self.note = note
    }

    var dayType: String { rawDayType }
    var energy: String? { rawEnergy }
}

// MARK: - PlannedItem

@Model
final class PlannedItemEntity {
    var goalId: String
    var minutes: Int
    var label: String
    var plannedUnits: Double
    var order: Int

    var day: DayEntity?

    init(goalId: String, minutes: Int, label: String, plannedUnits: Double, order: Int) {
        self.goalId = goalId
        self.minutes = minutes
        self.label = label
        self.plannedUnits = plannedUnits
        self.order = order
    }
}

// MARK: - ReportItem

@Model
final class ReportItemEntity {
    var goalId: String
    var completionPct: Int          // 0–100

    var day: DayEntity?

    init(goalId: String, completionPct: Int) {
        self.goalId = goalId
        self.completionPct = completionPct
    }
}

// MARK: - Event

@Model
final class EventEntity {
    var eventType: String           // "exam"
    var subject: String
    var date: String                // "yyyy-MM-dd"

    var month: MonthEntity?

    init(eventType: String, subject: String, date: String) {
        self.eventType = eventType
        self.subject = subject
        self.date = date
    }
}

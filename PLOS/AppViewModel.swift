import Foundation
import SwiftUI
import SwiftData
import PLOSKernel

// MARK: - AppViewModel

/// Central orchestrator for the PLOS app.
///
/// ## Date Discipline
/// The "today" Date is captured once at launch and injected into every kernel call.
/// The kernel never calls Date() — all dates are parameters.
///
/// ## Pure-function pipeline (study day)
/// 1. Collect goals, past days, restStrategy, events → MonthState
/// 2. Fill derived study-axis fields
/// 3. Score goals → allocate budget → apply rules → generate reasoning
/// 4. Return DayPlan + persist PlannedItems to DayEntity
@MainActor
@Observable
final class AppViewModel {

    // MARK: - Today

    /// The single source of truth for "today". Captured at launch, never mutated.
    /// Call `advanceToToday()` to refresh across midnight.
    let today: Date
    var todayStr: String { RestSchedule.dateString(today) }

    // MARK: - Injected

    private var modelContext: ModelContext?

    // MARK: - UI State

    var activeMonth: MonthEntity?

    /// Day type for today as determined by the skeleton + any user override.
    var todayDayType: DayType = .study
    var todayEnergy: Energy = .normal
    var todayPlannedItems: [PlannedItem] = []
    var todayReasoning: String = ""
    var todayHealthNotes: [String] = []
    var todayRestMessage: String = ""

    /// Evening report
    var reportCompletions: [String: Int] = [:]   // goalId → 0…100
    var reportNotes: [String: String] = [:]       // goalId → note string

    // MARK: - Init

    init(today: Date = Date()) {
        self.today = today
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Month Operations

    /// Get or create the month entity for today's year/month.
    func fetchOrCreateMonth(year: Int, month: Int,
                            cycleStudy: Int, cycleRest: Int, flexRestTotal: Int) -> MonthEntity {
        guard let ctx = modelContext else { fatalError("modelContext not set") }

        let yPred = #Predicate<MonthEntity> { $0.year == year && $0.month == month }
        let descriptor = FetchDescriptor(predicate: yPred)
        if let existing = try? ctx.fetch(descriptor).first {
            activeMonth = existing
            return existing
        }

        let month = MonthEntity(year: year, month: month,
                                cycleStudy: cycleStudy, cycleRest: cycleRest,
                                flexRestTotal: flexRestTotal)
        ctx.insert(month)
        try? ctx.save()
        activeMonth = month
        return month
    }

    /// Add a goal to the active month.
    func addGoal(_ entity: GoalEntity) {
        guard let month = activeMonth, let ctx = modelContext else { return }
        entity.month = month
        ctx.insert(entity)
        month.goals.append(entity)
        try? ctx.save()
    }

    /// Delete a goal.
    func deleteGoal(_ entity: GoalEntity) {
        guard let ctx = modelContext else { return }
        ctx.delete(entity)
        try? ctx.save()
    }

    /// Build the month skeleton (day types for the whole month) and persist DayEntity rows.
    func buildSkeleton() {
        guard let month = activeMonth, let ctx = modelContext else { return }

        let (y, m, _) = RestSchedule.dateComponents(today)
        let strategy = RestStrategy(cycleStudy: month.cycleStudy,
                                     cycleRest: month.cycleRest,
                                     flexRestTotal: month.flexRestTotal,
                                     flexUsed: month.flexUsed)
        let skeleton = RestSchedule.monthSkeleton(year: y, month: m, strategy: strategy)
        let n = RestSchedule.daysInMonth(year: y, month: m)

        // Remove old skeleton days that haven't been reported on
        let existingDates = Set(month.days.map { $0.date })
        for dayIdx in 1...n {
            let dateStr = RestSchedule.dateString(RestSchedule.dateFrom(y, m, dayIdx))
            if existingDates.contains(dateStr) { continue }
            let dayType = skeleton[dayIdx - 1]
            let rawDayType: String = {
                switch dayType {
                case .study:      return "study"
                case .rhythmRest: return "rhythmRest"
                case .flexRest:   return "flexRest"
                }
            }()
            let day = DayEntity(date: dateStr, rawDayType: rawDayType)
            day.month = month
            ctx.insert(day)
            month.days.append(day)
        }
        try? ctx.save()
    }

    // MARK: - Daily Operations

    /// Look up today's DayEntity.
    func todayDayEntity() -> DayEntity? {
        guard let month = activeMonth else { return nil }
        return month.days.first { $0.date == todayStr }
    }

    /// Morning: load today's state — day type, energy, planned items.
    func loadTodayState() {
        guard let day = todayDayEntity() else {
            todayDayType = .study
            todayEnergy = .normal
            return
        }
        todayDayType = day.kernelDayType
        todayEnergy = day.kernelEnergy ?? .normal

        if let firstPlanned = day.plannedItems.first {
            todayPlannedItems = day.plannedItems
                .sorted { $0.order < $1.order }
                .map { $0.toKernelPlannedItem() }
        } else {
            todayPlannedItems = []
        }
        todayRestMessage = ""
        todayReasoning = ""
        todayHealthNotes = []
    }

    /// Morning: generate the day plan (study day only).
    /// Pure-function call into PLOSKernel.
    func generatePlan(energy: Energy) {
        guard let month = activeMonth else { return }

        var state = month.toMonthState(today: today)
        // Apply today's energy
        let day = todayDayEntity()
        day?.rawEnergy = energy.rawValue
        todayEnergy = energy

        let plan = Scheduler.plan(state: state, today: today)

        switch plan {
        case .rest(let card):
            todayRestMessage = card.message
            todayDayType = .rhythmRest
            todayPlannedItems = []

        case .study(let items, let reasoning, let healthNotes):
            todayDayType = .study
            todayPlannedItems = items
            todayReasoning = reasoning
            todayHealthNotes = healthNotes
            persistPlannedItems(items)
        }

        // Mark systemRan on first open
        if let day = day {
            day.systemRan = true
            try? modelContext?.save()
        }
    }

    /// DayType → rest message without re-calling kernel.
    func loadRestDay() {
        guard let month = activeMonth else { return }
        let day = todayDayEntity()
        day?.systemRan = true
        try? modelContext?.save()

        let state = month.toMonthState(today: today)
        let flexRem = month.flexRestTotal - month.flexUsed
        let message = Reasoning.restCard(dayType: todayDayType,
                                         streak: state.streak,
                                         flexRemaining: todayDayType == .flexRest ? flexRem : nil)
        todayRestMessage = message
        todayPlannedItems = []
    }

    /// Flex rest: convert today from study → flexRest, decrement quota.
    func useFlexRest() {
        guard let month = activeMonth, let day = todayDayEntity() else { return }
        guard month.flexUsed < month.flexRestTotal else { return }

        month.flexUsed += 1
        day.rawDayType = "flexRest"
        day.rawEnergy = nil
        day.plannedItems.forEach { modelContext?.delete($0) }
        day.plannedItems = []
        day.systemRan = true
        try? modelContext?.save()

        todayDayType = .flexRest
        loadRestDay()
    }

    /// Undo flex rest (go back to study day).
    func undoFlexRest() {
        guard let month = activeMonth, let day = todayDayEntity() else { return }
        guard month.flexUsed > 0 else { return }

        month.flexUsed -= 1
        day.rawDayType = "study"
        day.systemRan = true
        try? modelContext?.save()

        todayDayType = .study
        todayPlannedItems = []
    }

    // MARK: - Evening Report

    /// Save evening report: update goal progress + systemRan.
    func saveEveningReport() {
        guard let month = activeMonth, let ctx = modelContext, let day = todayDayEntity() else { return }

        // Clear old reports
        day.reportItems.forEach { ctx.delete($0) }
        day.reportItems = []

        for (goalId, pct) in reportCompletions {
            // Save report item
            let report = ReportItemEntity(goalId: goalId, completionPct: pct)
            report.day = day
            ctx.insert(report)
            day.reportItems.append(report)

            // Update goal.done per §1.9
            guard let goal = month.goals.first(where: { $0.uid == goalId }) else { continue }
            let plannedUnits = day.plannedItems.first(where: { $0.goalId == goalId })?.plannedUnits ?? 0
            let increment = Double(pct) / 100.0 * plannedUnits
            goal.done = min(goal.total, goal.done + increment)

            // Habit: any completion > 0 counts as "done for the day"
            // (habit tracking is implicit via goal.done being a running count)
        }

        day.systemRan = true
        day.note = reportNotes.values.joined(separator: "; ")
        try? ctx.save()
    }

    // MARK: - Streak

    var todayStreak: Int {
        guard let month = activeMonth else { return 0 }
        return month.computeStreak(today: today)
    }

    // MARK: - Health Reminder

    /// Health status based on stored data (stub: to be wired to real health data in Phase P).
    func currentHealthReminders() -> [String] {
        // Stub — no health tracking yet
        []
    }

    // MARK: - Convenience

    /// Backbone study days for the active month.
    var backboneStudyDays: Int {
        guard let month = activeMonth else { return 0 }
        let (y, m, _) = RestSchedule.dateComponents(today)
        let strategy = RestStrategy(cycleStudy: month.cycleStudy,
                                     cycleRest: month.cycleRest,
                                     flexRestTotal: month.flexRestTotal,
                                     flexUsed: month.flexUsed)
        return RestSchedule.backboneStudyDays(year: y, month: m, strategy: strategy)
    }

    /// Guaranteed study days.
    var studyDaysTotal: Int {
        guard let month = activeMonth else { return 0 }
        let (y, m, _) = RestSchedule.dateComponents(today)
        let strategy = RestStrategy(cycleStudy: month.cycleStudy,
                                     cycleRest: month.cycleRest,
                                     flexRestTotal: month.flexRestTotal,
                                     flexUsed: month.flexUsed)
        return RestSchedule.studyDaysTotal(year: y, month: m, strategy: strategy)
    }

    // MARK: - Persist PlannedItems

    private func persistPlannedItems(_ items: [PlannedItem]) {
        guard let ctx = modelContext, let day = todayDayEntity() else { return }
        // Clear old plan
        day.plannedItems.forEach { ctx.delete($0) }
        day.plannedItems = []
        for item in items {
            let entity = PlannedItemEntity(goalId: item.goalId, minutes: item.minutes,
                                           label: item.label, plannedUnits: item.plannedUnits,
                                           order: item.order)
            entity.day = day
            ctx.insert(entity)
            day.plannedItems.append(entity)
        }
        try? ctx.save()
    }
}

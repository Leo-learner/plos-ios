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

    /// The single source of truth for "today", kernel-canonical (midnight UTC of the user's
    /// local calendar day). Refreshed by `advanceToTodayIfNeeded()` when the app returns to
    /// the foreground across midnight.
    private(set) var today: Date
    var todayStr: String { RestSchedule.dateString(today) }

    /// When set (tests, `-plosToday`), "today" never advances off this date —
    /// otherwise the foreground refresh would silently overwrite the pinned day.
    private let pinnedToday: Date?

    /// The user's local calendar day, mapped to the kernel-canonical Date.
    /// nonisolated: pure computation, usable from init default arguments.
    nonisolated static func canonicalNow() -> Date {
        RestSchedule.canonicalDate(from: Date(), in: .current)
    }

    /// The day the app should be showing right now.
    private func currentDay() -> Date { pinnedToday ?? Self.canonicalNow() }

    // MARK: - Injected

    var modelContext: ModelContext?

    // MARK: - UI State

    var activeMonth: MonthEntity?

    /// Selected TabView index — owned here so notification deep-links and
    /// empty-state shortcuts can switch tabs.
    var selectedTab = 0

    /// Drives navigation into the evening report screen (button + EVENING deep-link).
    var showEveningReport = false

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

    /// `today: nil` follows the real clock; a value pins the day for tests.
    init(today: Date? = nil) {
        self.pinnedToday = today
        self.today = today ?? AppViewModel.canonicalNow()
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Load (or create) the month for `today`, build its skeleton, and load today's state.
    /// Safe to call repeatedly; used at launch and after day/month rollover.
    /// A brand-new month inherits the most recent month's rest strategy (fresh launch in a
    /// new month has no activeMonth yet, so the lookup goes through the store).
    func bootstrapMonth() {
        let (y, m, _) = RestSchedule.dateComponents(today)
        let previous = activeMonth ?? latestMonthEntity()
        _ = fetchOrCreateMonth(year: y, month: m,
                               cycleStudy: previous?.cycleStudy ?? 5,
                               cycleRest: previous?.cycleRest ?? 2,
                               flexRestTotal: previous?.flexRestTotal ?? 2)
        buildSkeleton()
        loadTodayState()
    }

    /// Delete every persisted month (cascading to goals/days/items). Used by the
    /// `-plosResetStore` launch argument so UI tests start from a known-empty state.
    func wipeAllData() {
        guard let ctx = modelContext else { return }
        let months = (try? ctx.fetch(FetchDescriptor<MonthEntity>())) ?? []
        months.forEach { ctx.delete($0) }
        try? ctx.save()
        activeMonth = nil
        todayPlannedItems = []
        todayReasoning = ""
        todayHealthNotes = []
    }

    /// The most recent month entity in the store, by (year, month).
    private func latestMonthEntity() -> MonthEntity? {
        guard let ctx = modelContext else { return nil }
        let descriptor = FetchDescriptor<MonthEntity>(
            sortBy: [SortDescriptor(\MonthEntity.year, order: .reverse),
                     SortDescriptor(\MonthEntity.month, order: .reverse)]
        )
        return try? ctx.fetch(descriptor).first
    }

    /// Re-capture "today" when the local calendar day has changed (foregrounded across
    /// midnight, possibly across a month boundary), then reload state for the new day.
    func advanceToTodayIfNeeded() {
        let now = currentDay()
        guard now != today else { return }
        today = now
        todayPlannedItems = []
        todayReasoning = ""
        todayHealthNotes = []
        reportCompletions = [:]
        reportNotes = [:]
        bootstrapMonth()
        updateWidgetData()
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

    /// Update the active month's rest strategy and re-lay the skeleton.
    /// Days that already carry history (reported, systemRan, or spent flex rest) keep their type.
    func applyRestStrategy(cycleStudy: Int, cycleRest: Int, flexRestTotal: Int) {
        guard let month = activeMonth else { return }
        month.cycleStudy = cycleStudy
        month.cycleRest = cycleRest
        month.flexRestTotal = flexRestTotal
        buildSkeleton()
        try? modelContext?.save()
        loadTodayState()
    }

    /// Build the month skeleton (day types for the whole month) and persist DayEntity rows.
    /// Existing rows without history are re-typed to the current skeleton, so changing the
    /// rest strategy mid-month takes effect for the untouched future days.
    func buildSkeleton() {
        guard let month = activeMonth, let ctx = modelContext else { return }

        let (y, m, _) = RestSchedule.dateComponents(today)
        let strategy = RestStrategy(cycleStudy: month.cycleStudy,
                                     cycleRest: month.cycleRest,
                                     flexRestTotal: month.flexRestTotal,
                                     flexUsed: month.flexUsed)
        let skeleton = RestSchedule.monthSkeleton(year: y, month: m, strategy: strategy)
        let n = RestSchedule.daysInMonth(year: y, month: m)

        for dayIdx in 1...n {
            let dateStr = RestSchedule.dateString(RestSchedule.dateFrom(y, m, dayIdx))
            let rawDayType: String = {
                switch skeleton[dayIdx - 1] {
                case .study:      return "study"
                case .rhythmRest: return "rhythmRest"
                case .flexRest:   return "flexRest"
                }
            }()
            if let existing = month.days.first(where: { $0.date == dateStr }) {
                let hasHistory = existing.systemRan || !existing.reportItems.isEmpty
                    || !existing.plannedItems.isEmpty || existing.rawDayType == "flexRest"
                if !hasHistory {
                    existing.rawDayType = rawDayType
                }
                continue
            }
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

        if day.plannedItems.isEmpty {
            todayPlannedItems = []
            todayReasoning = ""
        } else {
            todayPlannedItems = day.plannedItems
                .sorted { $0.order < $1.order }
                .map { $0.toKernelPlannedItem() }
            // Reasoning survives relaunch — it is the user's trust anchor (§1.7).
            todayReasoning = day.reasoning ?? ""
        }
        todayRestMessage = ""
        todayHealthNotes = []
    }

    /// Morning: generate the day plan (study day only).
    /// Pure-function call into PLOSKernel.
    func generatePlan(energy: Energy) {
        guard let month = activeMonth else { return }

        let day = todayDayEntity()
        day?.rawEnergy = energy.rawValue
        todayEnergy = energy

        var state = month.toMonthState(today: today)
        state.health = currentHealth()
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
            day?.reasoning = reasoning
            persistPlannedItems(items)
        }

        // Mark systemRan on first open
        if let day = day {
            day.systemRan = true
            try? modelContext?.save()
        }
        updateWidgetData()
    }

    /// Clear today's generated plan so the user can re-pick energy and regenerate.
    /// Keeps systemRan (the system still ran today) and any saved report untouched.
    func resetTodayPlan() {
        guard let ctx = modelContext, let day = todayDayEntity() else { return }
        day.plannedItems.forEach { ctx.delete($0) }
        day.plannedItems = []
        day.rawEnergy = nil
        day.reasoning = nil
        try? ctx.save()
        todayPlannedItems = []
        todayReasoning = ""
        todayHealthNotes = []
        updateWidgetData()
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
        updateWidgetData()
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
        updateWidgetData()
    }

    // MARK: - Evening Report

    /// Save evening report: replace today's report records, then recompute goal progress.
    /// Idempotent — re-saving (after moving a slider) replaces today's contribution instead
    /// of stacking a second increment on top of the first.
    func saveEveningReport() {
        guard let ctx = modelContext, let day = todayDayEntity() else { return }

        day.reportItems.forEach { ctx.delete($0) }
        day.reportItems = []
        for (goalId, pct) in reportCompletions.sorted(by: { $0.key < $1.key }) {
            let report = ReportItemEntity(goalId: goalId, completionPct: pct)
            report.day = day
            ctx.insert(report)
            day.reportItems.append(report)
        }

        recomputeGoalProgress()

        day.systemRan = true
        day.note = reportNotes.sorted(by: { $0.key < $1.key }).map(\.value).joined(separator: "; ")
        try? ctx.save()
        updateWidgetData()
    }

    /// §1.9 as a fold over the month: done = min(total, Σ days completionPct/100 × that day's
    /// plannedUnits). Habits are excluded — their metric is "completed study days"
    /// (see `computeHabitSummaries`), and their plannedUnits is 0 by design.
    private func recomputeGoalProgress() {
        guard let month = activeMonth else { return }
        for goal in month.goals where goal.rawType != "habit" {
            var sum = 0.0
            for day in month.days {
                guard let report = day.reportItems.first(where: { $0.goalId == goal.uid }) else { continue }
                let units = day.plannedItems.first(where: { $0.goalId == goal.uid })?.plannedUnits ?? 0
                sum += Double(report.completionPct) / 100.0 * units
            }
            goal.done = min(goal.total, sum)
        }
    }

    // MARK: - Streak

    var todayStreak: Int {
        guard let month = activeMonth else { return 0 }
        return month.computeStreak(today: today)
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

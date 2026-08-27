import XCTest
import SwiftData
@testable import PLOSAppCheck
@testable import PLOSKernel

/// Headless integration tests for the app layer — the L1 walkthrough's data loop,
/// runnable via plain `swift test` (in-memory SwiftData, injected `today`).
/// Covers: month bootstrap → plan generation (3 energies) → evening report →
/// idempotent progress fold → habit day-count → continuity across days → streak →
/// flex rest → strategy change → month rollover.
@MainActor
final class AppIntegrationTests: XCTestCase {

    // MARK: - Harness

    private var container: ModelContainer!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: MonthEntity.self, GoalEntity.self, DayEntity.self,
                 PlannedItemEntity.self, ReportItemEntity.self, EventEntity.self,
            configurations: config
        )
    }

    /// A fresh view model bound to the shared in-memory store — "relaunching the app on day X".
    private func makeVM(day: Int, month: Int = 8) -> AppViewModel {
        let vm = AppViewModel(today: RestSchedule.dateFrom(2026, month, day))
        vm.configure(modelContext: container.mainContext)
        vm.bootstrapMonth()
        return vm
    }

    private func addSampleGoals(_ vm: AppViewModel) {
        vm.addGoal(GoalEntity(uid: "math", subject: "高数", rawType: "deadline",
                              targetDesc: "完成6章", unit: "章", total: 6,
                              startDate: RestSchedule.dateFrom(2026, 8, 1),
                              deadlineDate: RestSchedule.dateFrom(2026, 8, 30),
                              importance: 1.2, successThreshold: 0.8))
        vm.addGoal(GoalEntity(uid: "linalg", subject: "线代", rawType: "deadline",
                              targetDesc: "100题", unit: "题", total: 100,
                              startDate: RestSchedule.dateFrom(2026, 8, 1),
                              deadlineDate: RestSchedule.dateFrom(2026, 8, 28),
                              successThreshold: 0.8))
        vm.addGoal(GoalEntity(uid: "eng", subject: "英语", rawType: "habit",
                              targetDesc: "每天阅读", unit: "天", total: 31,
                              startDate: RestSchedule.dateFrom(2026, 8, 1),
                              deadlineDate: RestSchedule.dateFrom(2026, 8, 31),
                              successThreshold: 0.7))
    }

    // MARK: - Month bootstrap

    func testBootstrapBuildsFullSkeleton() throws {
        let vm = makeVM(day: 3)   // 2026-08-03 is a study day (学5休2, day 3)
        XCTAssertNotNil(vm.activeMonth)
        XCTAssertEqual(vm.activeMonth?.days.count, 31, "August skeleton covers all 31 days")
        XCTAssertEqual(vm.todayDayType, .study)
        // 学5休2 × 31 days → backbone 23, guaranteed 23 − 2 = 21
        XCTAssertEqual(vm.backboneStudyDays, 23)
        XCTAssertEqual(vm.studyDaysTotal, 21)
    }

    // MARK: - Plan generation (three energies, budget caps)

    func testGeneratePlanBudgetsPerEnergy() throws {
        let vm = makeVM(day: 3)
        addSampleGoals(vm)

        for (energy, cap) in [(Energy.high, 150), (.normal, 100), (.low, 45)] {
            vm.resetTodayPlan()
            vm.generatePlan(energy: energy)
            XCTAssertFalse(vm.todayPlannedItems.isEmpty, "\(energy): plan must have items")
            XCTAssertFalse(vm.todayReasoning.isEmpty, "\(energy): reasoning must exist")
            let total = vm.todayPlannedItems.reduce(0) { $0 + $1.minutes }
            XCTAssertLessThanOrEqual(total, cap, "\(energy): sum ≤ budget")
        }

        // systemRan marked, plan + reasoning persisted for relaunch
        let day = vm.todayDayEntity()
        XCTAssertEqual(day?.systemRan, true)
        XCTAssertFalse(day?.plannedItems.isEmpty ?? true)
        XCTAssertEqual(day?.reasoning, vm.todayReasoning)

        // "Relaunch": a fresh VM on the same store restores the plan and reasoning
        let vm2 = makeVM(day: 3)
        XCTAssertEqual(vm2.todayPlannedItems.count, vm.todayPlannedItems.count)
        XCTAssertEqual(vm2.todayReasoning, vm.todayReasoning)
    }

    // MARK: - Evening report: §1.9 fold, idempotency, habit day-count

    func testEveningReportFoldAndIdempotency() throws {
        let vm = makeVM(day: 3)
        addSampleGoals(vm)
        vm.generatePlan(energy: .normal)

        let mathUnits = vm.todayPlannedItems.first { $0.goalId == "math" }?.plannedUnits ?? 0
        XCTAssertGreaterThan(mathUnits, 0, "deadline item carries plannedUnits")

        vm.reportCompletions = ["math": 50, "eng": 100]
        vm.saveEveningReport()

        let math = vm.activeMonth!.goals.first { $0.uid == "math" }!
        XCTAssertEqual(math.done, 0.5 * mathUnits, accuracy: 1e-9, "done = pct × plannedUnits")

        // Re-save with a different slider — the fold REPLACES today's contribution
        vm.reportCompletions = ["math": 80, "eng": 100]
        vm.saveEveningReport()
        XCTAssertEqual(math.done, 0.8 * mathUnits, accuracy: 1e-9,
                       "re-saving must not stack increments")

        // Habit: done untouched; metric is completed study days
        let eng = vm.activeMonth!.goals.first { $0.uid == "eng" }!
        XCTAssertEqual(eng.done, 0, "habit done is not driven by §1.9 units")
        let habits = vm.computeHabitSummaries()
        XCTAssertEqual(habits.count, 1)
        XCTAssertEqual(habits[0].completedDays, 1)
        XCTAssertEqual(habits[0].studyDaysSoFar, 3, "Aug 1–3 are study days")

        // All-zero report still counts as the system running (no punishment)
        vm.reportCompletions = ["math": 0, "eng": 0]
        vm.saveEveningReport()
        XCTAssertEqual(vm.todayDayEntity()?.systemRan, true)
        XCTAssertEqual(math.done, 0, accuracy: 1e-9)
    }

    // MARK: - Cross-day: continuity label + streak

    func testNextDayContinuityAndStreak() throws {
        let day3 = makeVM(day: 3)
        addSampleGoals(day3)
        day3.generatePlan(energy: .normal)
        day3.reportCompletions = ["math": 50, "eng": 100]
        day3.saveEveningReport()
        XCTAssertEqual(day3.todayStreak, 1)

        // Next morning: new VM, same store
        let day4 = makeVM(day: 4)
        XCTAssertEqual(day4.todayDayType, .study)
        day4.generatePlan(energy: .normal)

        let mathItem = try XCTUnwrap(day4.todayPlannedItems.first { $0.goalId == "math" },
                                     "yesterday's 50% subject re-planned today")
        XCTAssertTrue(mathItem.label.contains("接昨天"),
                      "0<pct<100 yesterday → continuity label")
        XCTAssertEqual(day4.todayStreak, 2, "consecutive systemRan days")
    }

    // MARK: - Flex rest: spend, undo, quota

    func testFlexRestSpendAndUndo() throws {
        let vm = makeVM(day: 3)
        addSampleGoals(vm)
        vm.generatePlan(energy: .normal)

        vm.useFlexRest()
        XCTAssertEqual(vm.todayDayType, .flexRest)
        XCTAssertEqual(vm.activeMonth?.flexUsed, 1)
        XCTAssertTrue(vm.todayPlannedItems.isEmpty, "flex rest clears the plan")
        XCTAssertFalse(vm.todayRestMessage.isEmpty)

        vm.undoFlexRest()
        XCTAssertEqual(vm.todayDayType, .study)
        XCTAssertEqual(vm.activeMonth?.flexUsed, 0)
    }

    // MARK: - Rest day short-circuit

    func testRhythmRestDay() throws {
        // 2026-08-06 is day 6 → rhythmRest in the 学5休2 skeleton
        let vm = makeVM(day: 6)
        addSampleGoals(vm)
        XCTAssertEqual(vm.todayDayType, .rhythmRest)
        vm.loadRestDay()
        XCTAssertTrue(vm.todayRestMessage.contains("休息"))
        XCTAssertEqual(vm.todayDayEntity()?.systemRan, true, "opening on a rest day counts as running")
    }

    // MARK: - Strategy change mid-month re-lays history-free days only

    func testApplyRestStrategyPreservesHistory() throws {
        let vm = makeVM(day: 3)
        addSampleGoals(vm)
        vm.generatePlan(energy: .normal)   // Aug 3 now has history

        vm.applyRestStrategy(cycleStudy: 6, cycleRest: 1, flexRestTotal: 1)
        let month = vm.activeMonth!
        XCTAssertEqual(month.cycleStudy, 6)
        // Day 6 was rhythmRest under 学5休2; under 学6休1 it is study — and has no history
        let day6 = month.days.first { $0.date == "2026-08-06" }
        XCTAssertEqual(day6?.rawDayType, "study")
        // Aug 3 keeps its planned history
        let day3 = month.days.first { $0.date == "2026-08-03" }
        XCTAssertFalse(day3?.plannedItems.isEmpty ?? true)
    }

    // MARK: - Month rollover carries the strategy forward

    func testMonthRolloverCreatesNextMonth() throws {
        let aug = makeVM(day: 3)
        addSampleGoals(aug)
        aug.applyRestStrategy(cycleStudy: 4, cycleRest: 3, flexRestTotal: 1)

        let sep = makeVM(day: 1, month: 9)
        XCTAssertEqual(sep.activeMonth?.month, 9, "new month entity created")
        XCTAssertEqual(sep.activeMonth?.cycleStudy, 4, "strategy carried over from August")
        XCTAssertEqual(sep.activeMonth?.days.count, 30, "September skeleton complete")
    }

    // MARK: - Reset today's plan (re-pick energy)

    func testResetTodayPlan() throws {
        let vm = makeVM(day: 3)
        addSampleGoals(vm)
        vm.generatePlan(energy: .low)
        XCTAssertFalse(vm.todayPlannedItems.isEmpty)

        vm.resetTodayPlan()
        XCTAssertTrue(vm.todayPlannedItems.isEmpty)
        XCTAssertTrue(vm.todayReasoning.isEmpty)
        XCTAssertNil(vm.todayDayEntity()?.rawEnergy)
        XCTAssertEqual(vm.todayDayEntity()?.systemRan, true, "reset does not un-run the system")
    }
}

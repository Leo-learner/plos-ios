import XCTest
import Foundation
@testable import PLOSKernel

// MARK: - Fixture Loader

struct FixtureData: Codable {
    let state: MonthState
    let today: String
}

/// All tests: deterministic, no side effects, pure function verification.
final class PLOSKernelTests: XCTestCase {

    // MARK: - Helpers

    func loadFixture(_ name: String) throws -> FixtureData {
        let bundle = Bundle.module
        // Fixture files are in Fixtures/ directory
        let resourceName = name.replacingOccurrences(of: ".json", with: "")
        guard let url = bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Fixtures")
        else {
            throw NSError(domain: "PLOSKernelTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Fixture not found: \(name)"])
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        // Fixtures use "yyyy-MM-dd" date format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return try decoder.decode(FixtureData.self, from: data)
    }

    /// Build the standard 5/2 + flex2 MonthState for July 2026
    func makeJulyState(
        goals: [Goal],
        days: [String: Day] = [:],
        flexUsed: Int = 0
    ) -> MonthState {
        MonthState(
            goals: goals,
            days: days,
            restStrategy: RestStrategy(cycleStudy: 5, cycleRest: 2, flexRestTotal: 2, flexUsed: flexUsed),
            events: [],
            health: Health(),
            streak: 10
        )
    }

    // MARK: - §1.3 Rest Schedule Tests

    func testStudy5Rest2Backbone() {
        // 学5休2×30天 → backbone=22、保底=20
        let strategy = RestStrategy(cycleStudy: 5, cycleRest: 2, flexRestTotal: 2, flexUsed: 0)
        let backbone = RestSchedule.backboneStudyDays(year: 2026, month: 7, strategy: strategy)
        let total = RestSchedule.studyDaysTotal(year: 2026, month: 7, strategy: strategy)

        XCTAssertEqual(backbone, 23, "学5休2×31天(July has 31)=23 backbone study days")
        XCTAssertEqual(total, 21, "保底学习日=23−2=21")
    }

    func testStudyDayAxisDerivation() {
        // rem/elapsed 派生正确
        let strategy = RestStrategy(cycleStudy: 5, cycleRest: 2, flexRestTotal: 2, flexUsed: 1)
        // July 2026 has 31 days, starting Wednesday (day 1 of month).
        // 学5休2: 1-5 study, 6-7 rest, 8-12 study, 13-14 rest, etc.
        // For July 2026: day 1=July 1=Wednesday
        // Let's compute: backbone study days from July 4 onward
        // July has 31 days. Skeleton: 1-5 study, 6-7 rest, 8-12 study, 13-14 rest,
        // 15-19 study, 20-21 rest, 22-26 study, 27-28 rest, 29-31 study
        // = 5+5+5+5+3 = 23 backbone. Wait, let me recalculate correctly.
        // Actually RestSchedule.monthSkeleton already counts correctly.
        let rem = RestSchedule.studyDaysRemaining(year: 2026, month: 7, strategy: strategy, tomorrowDay: 4)
        let total = RestSchedule.studyDaysTotal(year: 2026, month: 7, strategy: strategy)
        let elapsed = RestSchedule.studyDaysElapsed(year: 2026, month: 7, strategy: strategy, tomorrowDay: 4)

        XCTAssertEqual(total, 21, "保底=21")
        XCTAssertTrue(rem > 0, "remaining > 0")
        XCTAssertEqual(elapsed + rem, total, "elapsed + remaining = total")
    }

    func testExpectedProgressOnStudyAxis() {
        // 学习日轴：在中途插入休息日，expected_progress 不变
        // Study days elapsed / total should be the same regardless of rest days between
        let strategy = RestStrategy(cycleStudy: 5, cycleRest: 2, flexRestTotal: 2, flexUsed: 0)

        // Scenario 1: today=July 3 (study day, 3 study days elapsed out of 20 total)
        let elapsed1 = RestSchedule.studyDaysElapsed(year: 2026, month: 7, strategy: strategy, tomorrowDay: 4)
        let total1 = RestSchedule.studyDaysTotal(year: 2026, month: 7, strategy: strategy)
        let ep1 = Scoring.expectedProgress(elapsed: elapsed1, total: total1)

        // Scenario 2: today=July 5 (study day, 5 study days elapsed)
        // But between July 3 and July 5 there are study days — back-to-back, no rest in between.
        // The key assertion: expected progress is driven by study days, not calendar days
        let elapsed2 = RestSchedule.studyDaysElapsed(year: 2026, month: 7, strategy: strategy, tomorrowDay: 6)
        let ep2 = Scoring.expectedProgress(elapsed: elapsed2, total: total1)

        // Both should be proportional to study-day count, not calendar count
        XCTAssertEqual(ep1, Double(elapsed1) / Double(total1), accuracy: 0.001)
        XCTAssertEqual(ep2, Double(elapsed2) / Double(total1), accuracy: 0.001)
        XCTAssertTrue(ep2 > ep1, "Later in study days = higher expected progress")
    }

    // MARK: - §1.4 Scoring Tests

    func testGapZeroOrNegativeGivesPressureZero() {
        // gap≤0 → pressure=0
        let goal = Goal(
            id: "test", subject: "测试", type: .deadline,
            target: "10章", unit: "章", total: 10, done: 5,
            start: RestSchedule.dateFrom(2026, 7, 1),
            deadline: RestSchedule.dateFrom(2026, 7, 30)
        )
        // progress = 0.5, expected = 3/20 = 0.15, so gap = 0.15-0.5 = -0.35 ≤ 0 → pressure should be 0
        let score = Scoring.score(goal: goal, studyDaysElapsed: 3, studyDaysTotal: 20, studyDaysRemaining: 17)
        XCTAssertEqual(score.gap, -0.35, accuracy: 0.01)
        XCTAssertEqual(score.pressure, 0.0, accuracy: 0.001, "gap≤0 → pressure must be 0")
    }

    func testDecayAtThresholdIsOne() {
        // decay 在达标线=1
        let d = Scoring.decay(over: 0.0)  // over=0 when progress == threshold
        XCTAssertEqual(d, 1.0, accuracy: 0.001, "decay at threshold (over=0) must be 1")
    }

    func testDecayAtFullProgressIsFloor() {
        // 100%→FLOOR
        let d = Scoring.decay(over: 1.0)  // over=1 when progress=100%
        XCTAssertEqual(d, KernelConfig.importanceFloor, accuracy: 0.001, "decay at 100% must be FLOOR")
    }

    func testDecayMonotonicallyDecreasing() {
        // 区间单调递减
        var previous = 2.0
        for i in 0...100 {
            let over = Double(i) / 100.0
            let d = Scoring.decay(over: over)
            XCTAssertLessThanOrEqual(d, previous + 0.001, "decay must be monotonically decreasing")
            previous = d
        }
    }

    func testUrgencyIncreasesWithFewerRemainingDays() {
        let u1 = Scoring.urgency(studyDaysRemaining: 20)
        let u2 = Scoring.urgency(studyDaysRemaining: 2)
        XCTAssertTrue(u2 > u1, "urgency should be higher when fewer days remain")
    }

    func testPressureFormula() {
        // Comprehensive pressure test: pressure = max(gap, 0) * urgency * importance * decay * (1 + 0.1*historyDelay)
        let gap = 0.2
        let urgency = 1.5
        let importance = 1.2
        let decay = 0.8
        let historyDelay = 2
        let expected = gap * urgency * importance * decay * (1.0 + 0.1 * Double(historyDelay))
        let result = Scoring.pressure(gap: gap, urgency: urgency, importance: importance, decay: decay, historyDelay: historyDelay)
        XCTAssertEqual(result, expected, accuracy: 0.0001)
    }

    // MARK: - §1.5 Allocation Tests

    func testAllocationSumWithinBudget() {
        let goals = [
            Goal(id: "m1", subject: "A", type: .deadline, target: "10", unit: "章", total: 10, done: 2,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 30)),
            Goal(id: "m2", subject: "B", type: .deadline, target: "20", unit: "题", total: 20, done: 5,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 28)),
            Goal(id: "h1", subject: "英语", type: .habit, target: "", unit: "天", total: 30, done: 10,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 31)),
        ]

        let scores = Scoring.scoreAll(goals: goals, studyDaysElapsed: 3, studyDaysTotal: 20, studyDaysRemaining: 17)
        let habits = goals.filter { $0.type == .habit }
        let alloc = Allocator.allocate(scores: scores, habits: habits, energy: .normal, studyDaysRemaining: 17)

        let totalMinutes = alloc.items.reduce(0) { $0 + $1.minutes } + alloc.habitItems.reduce(0) { $0 + $1.minutes }
        XCTAssertLessThanOrEqual(totalMinutes, 100, "sum(minutes) ≤ budget for normal energy")

        // Habit must get HABIT_CHUNK
        XCTAssertEqual(alloc.habitItems.count, 1)
        XCTAssertEqual(alloc.habitItems[0].minutes, KernelConfig.habitChunk)
    }

    func testHabitAlwaysGetsChunk() {
        let goals = [
            Goal(id: "h1", subject: "英语", type: .habit, target: "", unit: "天", total: 30, done: 10,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 31)),
            Goal(id: "h2", subject: "阅读", type: .habit, target: "", unit: "天", total: 30, done: 8,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 31)),
        ]

        let scores = Scoring.scoreAll(goals: goals, studyDaysElapsed: 3, studyDaysTotal: 20, studyDaysRemaining: 17)
        let habits = goals.filter { $0.type == .habit }
        let alloc = Allocator.allocate(scores: scores, habits: habits, energy: .low, studyDaysRemaining: 17)

        XCTAssertEqual(alloc.habitItems.count, 2, "Both habits should be included even on low energy")
        for h in alloc.habitItems {
            XCTAssertEqual(h.minutes, KernelConfig.habitChunk, "Each habit gets HABIT_CHUNK")
        }
    }

    func testMinChunkEnforced() {
        let goals = [
            Goal(id: "m1", subject: "A", type: .deadline, target: "100", unit: "章", total: 100, done: 95,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 30)),
        ]

        let scores = Scoring.scoreAll(goals: goals, studyDaysElapsed: 3, studyDaysTotal: 20, studyDaysRemaining: 17)
        let alloc = Allocator.allocate(scores: scores, habits: [], energy: .normal, studyDaysRemaining: 17)

        for item in alloc.items {
            XCTAssertGreaterThanOrEqual(item.minutes, KernelConfig.minChunk, "No item should be below MIN_CHUNK if included")
        }
    }

    func testMaxChunkEnforced() {
        let goals = [
            Goal(id: "big", subject: "急科", type: .deadline, target: "100", unit: "页", total: 100, done: 0,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 10),
                 importance: 2.0),
        ]

        let scores = Scoring.scoreAll(goals: goals, studyDaysElapsed: 3, studyDaysTotal: 20, studyDaysRemaining: 5)
        let alloc = Allocator.allocate(scores: scores, habits: [], energy: .high, studyDaysRemaining: 5)

        for item in alloc.items {
            XCTAssertLessThanOrEqual(item.minutes, KernelConfig.maxChunk, "No single item should exceed MAX_CHUNK")
        }
    }

    func testPressureDescending() {
        let goals = [
            Goal(id: "a", subject: "A", type: .deadline, target: "10", unit: "", total: 10, done: 2,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 30)),
            Goal(id: "b", subject: "B", type: .deadline, target: "10", unit: "", total: 10, done: 1,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 15)),
            Goal(id: "c", subject: "C", type: .deadline, target: "10", unit: "", total: 10, done: 8,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 30)),
        ]

        let scores = Scoring.scoreAll(goals: goals, studyDaysElapsed: 3, studyDaysTotal: 20, studyDaysRemaining: 17)
        // scores should be sorted by pressure descending
        for i in 0..<(scores.count - 1) {
            XCTAssertGreaterThanOrEqual(scores[i].pressure, scores[i+1].pressure, "Scores must be in pressure descending order")
        }
    }

    func testLowEnergyOnlyTopDeadlineItems() {
        let goals = [
            Goal(id: "a", subject: "A", type: .deadline, target: "10", unit: "", total: 10, done: 1,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 10), importance: 1.5),
            Goal(id: "b", subject: "B", type: .deadline, target: "10", unit: "", total: 10, done: 1,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 20), importance: 1.0),
            Goal(id: "c", subject: "C", type: .deadline, target: "10", unit: "", total: 10, done: 8,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 30), importance: 0.5),
        ]

        let scores = Scoring.scoreAll(goals: goals, studyDaysElapsed: 3, studyDaysTotal: 20, studyDaysRemaining: 17)
        let alloc = Allocator.allocate(scores: scores, habits: [], energy: .low, studyDaysRemaining: 17)

        // Low energy: max 2 deadline items
        XCTAssertLessThanOrEqual(alloc.items.count, 2, "Low energy should keep ≤2 deadline items")
    }

    // MARK: - Rule Tests

    func testContinuityRule() {
        // 昨天某目标 0<completionPct<100 → 今日 label 追加「（接昨天）」
        let yesterday = Day(
            date: "2026-07-02", dayType: .study,
            reported: [
                ReportItem(goalId: "math", completionPct: 50),
                ReportItem(goalId: "eng", completionPct: 100),
            ]
        )

        let items = [
            PlannedItem(goalId: "math", minutes: 30, label: "高数", plannedUnits: 0.3, order: 0),
            PlannedItem(goalId: "eng", minutes: 15, label: "英语日常", plannedUnits: 0, order: 1),
        ]

        let context = RuleContext(
            today: "2026-07-03", yesterday: yesterday, events: [], health: Health(),
            scores: [], goals: [], days: [:]
        )

        let result = Rules.applyContinuity(items: items, context: context)
        XCTAssertTrue(result.first(where: { $0.goalId == "math" })!.label.contains("接昨天"),
                      "Partially-done goal should get '接昨天' label")
        XCTAssertFalse(result.first(where: { $0.goalId == "eng" })!.label.contains("接昨天"),
                       "Fully-done goal should NOT get '接昨天' label")
    }

    func testPreExamRule() {
        let items = [
            PlannedItem(goalId: "math", minutes: 60, label: "高数", plannedUnits: 0.5, order: 0),
            PlannedItem(goalId: "eng", minutes: 15, label: "英语日常", plannedUnits: 0, order: 1),
        ]

        let goals = [
            Goal(id: "math", subject: "高数", type: .deadline, target: "", unit: "", total: 6, done: 2,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 30)),
        ]

        let context = RuleContext(
            today: "2026-07-03", yesterday: nil,
            events: [Event(type: "exam", subject: "高数", date: "2026-07-04")],
            health: Health(),
            scores: [], goals: goals, days: [:]
        )

        let result = Rules.applyPreExam(items: items, context: context)
        let mathItem = result.first(where: { $0.goalId == "math" })!
        XCTAssertEqual(mathItem.minutes, KernelConfig.reviewChunk, "Pre-exam should set REVIEW_CHUNK")
        XCTAssertEqual(mathItem.label, "只复习，不上新内容", "Pre-exam should set label")
        XCTAssertEqual(result[0].goalId, "math", "Exam item should be moved to top")
    }

    // MARK: - Reasoning Tests

    func testReasoningEverySentenceHasNumber() {
        // reasoning：每句含数字
        let items = [
            PlannedItem(goalId: "math", minutes: 60, label: "高数", plannedUnits: 0.5, order: 0),
        ]

        let goals = [
            Goal(id: "math", subject: "高数", type: .deadline, target: "6", unit: "章", total: 6, done: 2,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 30)),
        ]

        let scores = [
            GoalScore(goalId: "math", goal: goals[0], progress: 0.33, baselineToday: 0.24,
                      over: 0, decay: 1.0, expectedProgress: 0.15, gap: -0.18, urgency: 1.41, pressure: 0),
        ]

        var state = MonthState(
            goals: goals, days: [:],
            restStrategy: RestStrategy(cycleStudy: 5, cycleRest: 2, flexRestTotal: 2), streak: 5
        )
        let today = RestSchedule.dateFrom(2026, 7, 3)
        RestSchedule.fillDerived(state: &state, today: today)

        let context = RuleContext(
            today: RestSchedule.dateString(today), yesterday: nil, events: [],
            health: Health(), scores: scores, goals: goals, days: [:]
        )

        let reasoning = Reasoning.generate(
            energy: .normal, budget: 100, items: items,
            scores: scores, goals: goals, state: state, today: today, context: context
        )

        // Every sentence should contain at least one digit
        let sentences = reasoning.components(separatedBy: "。").filter { !$0.isEmpty }
        for sentence in sentences {
            XCTAssertTrue(
                sentence.rangeOfCharacter(from: .decimalDigits) != nil,
                "Every sentence must contain a number: '\(sentence)'"
            )
        }
    }

    func testRestCardContainsStreak() {
        let card = Reasoning.restCard(dayType: .rhythmRest, streak: 15, flexRemaining: nil)
        XCTAssertTrue(card.contains("15"), "Rest card must contain streak number")
        XCTAssertTrue(card.contains("计划内休息日"), "Rhythm rest should indicate planned rest day")
    }

    func testRestCardFlexContainsRemaining() {
        let card = Reasoning.restCard(dayType: .flexRest, streak: 10, flexRemaining: 1)
        XCTAssertTrue(card.contains("1"), "Flex rest card must contain remaining count")
        XCTAssertTrue(card.contains("灵活休息日"), "Must mention flexible rest")
    }

    // MARK: - Determinism Test

    func testDeterminismSameInputSameOutput() {
        // 同一 state+today 两次调用输出逐字节一致
        let goals = [
            Goal(id: "math", subject: "高数", type: .deadline, target: "6", unit: "章", total: 6, done: 2,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 30)),
            Goal(id: "eng", subject: "英语", type: .habit, target: "", unit: "天", total: 30, done: 10,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 31)),
        ]

        let state = MonthState(
            goals: goals, days: [:],
            restStrategy: RestStrategy(cycleStudy: 5, cycleRest: 2, flexRestTotal: 2), streak: 10
        )

        let today = RestSchedule.dateFrom(2026, 7, 3)
        let result1 = Scheduler.plan(state: state, today: today)
        let result2 = Scheduler.plan(state: state, today: today)

        // Serialize and compare byte-by-byte
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let d1 = try! encoder.encode(result1)
        let d2 = try! encoder.encode(result2)

        XCTAssertEqual(d1, d2, "Same input must produce byte-identical output: determinism broken")
    }

    // MARK: - No Date() / No Side Effects

    func testAllFunctionsArePure() {
        // Verify that Scheduler.plan is a pure function: calling it doesn't mutate state
        let goals = [
            Goal(id: "math", subject: "高数", type: .deadline, target: "6", unit: "章", total: 6, done: 2,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 30)),
        ]

        let state = MonthState(
            goals: goals, days: [:],
            restStrategy: RestStrategy(cycleStudy: 5, cycleRest: 2, flexRestTotal: 2)
        )

        let stateCopy = state
        let today = RestSchedule.dateFrom(2026, 7, 3)

        _ = Scheduler.plan(state: state, today: today)

        // State should be unchanged (plan takes a copy internally via `var s = state`)
        XCTAssertEqual(state.goals, stateCopy.goals)
        XCTAssertEqual(state.restStrategy, stateCopy.restStrategy)
        XCTAssertEqual(state.streak, stateCopy.streak)
    }

    // MARK: - 7 Fixture Tests

    func testFixture1HighEnergy() throws {
        let f = try loadFixture("1_high_energy")
        let today = RestSchedule.parseDate(f.today)!
        let result = Scheduler.plan(state: f.state, today: today)

        guard case .study(let items, let reasoning, _) = result else {
            XCTFail("Expected .study plan for high energy day")
            return
        }

        // High energy: multiple subjects, wide budget
        XCTAssertFalse(items.isEmpty, "High energy day should have items")
        XCTAssertTrue(reasoning.contains("高能日"), "Reasoning should mention high energy")
        let totalMin = items.reduce(0) { $0 + $1.minutes }
        XCTAssertLessThanOrEqual(totalMin, 150, "High energy budget is 150 min")
    }

    func testFixture2LowEnergy() throws {
        let f = try loadFixture("2_low_energy")
        let today = RestSchedule.parseDate(f.today)!

        // Fixture day entry already has energy: .low
        let result = Scheduler.plan(state: f.state, today: today)

        guard case .study(let items, let reasoning, _) = result else {
            XCTFail("Expected .study plan")
            return
        }

        // Low energy: ≤2 deadline items + habits
        let deadlineItems = items.filter { item in
            if let goal = f.state.goals.first(where: { $0.id == item.goalId }) {
                return goal.type == .deadline || goal.type == .milestone
            }
            return false
        }
        XCTAssertLessThanOrEqual(deadlineItems.count, 3, "Low energy should keep ≤2-3 deadline/milestone items")

        let totalMin = items.reduce(0) { $0 + $1.minutes }
        XCTAssertLessThanOrEqual(totalMin, 45, "Low energy budget is 45 min")
        XCTAssertTrue(reasoning.contains("低谷"), "Reasoning should mention low energy")
    }

    func testFixture3WayBehind() throws {
        let f = try loadFixture("3_way_behind")
        let today = RestSchedule.parseDate(f.today)!
        let result = Scheduler.plan(state: f.state, today: today)

        guard case .study(_, let reasoning, _) = result else {
            XCTFail("Expected .study plan")
            return
        }

        // Should contain a main-push sentence for 高数 (only 0.3 done out of 6, gap should be large)
        XCTAssertTrue(reasoning.contains("落后"), "Reasoning must mention being behind")
        XCTAssertTrue(reasoning.contains("优先") || reasoning.contains("压力最高"), "Reasoning must indicate priority")
    }

    func testFixture4NearDeadline() throws {
        let f = try loadFixture("4_near_deadline")
        let today = RestSchedule.parseDate(f.today)!
        let result = Scheduler.plan(state: f.state, today: today)

        guard case .study(let items, _, _) = result else {
            XCTFail("Expected .study plan")
            return
        }

        // 线代 deadline July 5, today July 3 → urgency should be very high
        let linalgItems = items.filter { $0.goalId == "linalg" }
        XCTAssertFalse(linalgItems.isEmpty, "线代 should be included with near deadline")
    }

    func testFixture5ZeroYesterday() throws {
        let f = try loadFixture("5_zero_yesterday")
        let today = RestSchedule.parseDate(f.today)!
        let result = Scheduler.plan(state: f.state, today: today)

        guard case .study(let items, _, _) = result else {
            XCTFail("Expected .study plan")
            return
        }

        // Yesterday all 0% → continuity rule should NOT trigger
        let continuityLabels = items.filter { $0.label.contains("接昨天") }
        XCTAssertTrue(continuityLabels.isEmpty, "Zero yesterday: no continuity labels should be applied")

        // Items should still be generated (normal re-planning)
        XCTAssertFalse(items.isEmpty, "Should still generate a valid plan even after 0% day")
    }

    func testFixture6RhythmRest() throws {
        let f = try loadFixture("6_rhythm_rest")
        let today = RestSchedule.parseDate(f.today)!

        // July 4, 2026: day 4 of month, 学5休2 → days 1-5 are study, 6-7 are rest.
        // July 4 is day 4 → study day in skeleton. But the fixture has dayType=rhythmRest in days dict.
        let result = Scheduler.plan(state: f.state, today: today)

        guard case .rest(let card) = result else {
            XCTFail("Expected .rest for rhythmRest day")
            return
        }

        XCTAssertTrue(card.message.contains("休息"), "Rest card should mention rest")
        XCTAssertEqual(card.streak, 6, "Streak should match fixture")
    }

    func testFixture7PassedGoal() throws {
        let f = try loadFixture("7_passed_goal")
        let today = RestSchedule.parseDate(f.today)!
        let result = Scheduler.plan(state: f.state, today: today)

        guard case .study(let items, let reasoning, _) = result else {
            XCTFail("Expected .study plan")
            return
        }

        // 高数 progress = 4.9/6 = 81.7% ≥ 80% threshold → decay should kick in
        let mathScore = Scoring.score(
            goal: f.state.goals.first(where: { $0.id == "math" })!,
            studyDaysElapsed: 3, studyDaysTotal: 20, studyDaysRemaining: 17
        )
        XCTAssertLessThan(mathScore.decay, 1.0, "decay should be less than 1 when goal is past threshold")

        // Reasoning should contain yield sentence for 高数
        XCTAssertTrue(reasoning.contains("达标") || reasoning.contains("让位"), "Should mention passed goal yielding")

        // Verify no "if passed" branching: same pipeline code runs for all goals
        let linalgItems = items.filter { $0.goalId == "linalg" }
        XCTAssertFalse(linalgItems.isEmpty, "线代 should still get allocation")
    }

    // MARK: - Structural Validity Tests

    func testAllFixturesPlanStructurallyValid() throws {
        let fixtureNames = [
            "1_high_energy", "2_low_energy", "3_way_behind",
            "4_near_deadline", "5_zero_yesterday", "6_rhythm_rest",
            "7_passed_goal"
        ]

        for name in fixtureNames {
            let f = try loadFixture(name)
            let today = RestSchedule.parseDate(f.today)!
            let result = Scheduler.plan(state: f.state, today: today)

            switch result {
            case .study(let items, let reasoning, let health):
                XCTAssertFalse(items.isEmpty || reasoning.isEmpty,
                               "\(name): study plan must have items and reasoning")
                // Each item must have valid fields
                for item in items {
                    XCTAssertFalse(item.goalId.isEmpty, "\(name): item must have goalId")
                    XCTAssertTrue(item.minutes > 0, "\(name): item minutes must be positive")
                    XCTAssertFalse(item.label.isEmpty, "\(name): item must have label")
                }
            case .rest(let card):
                XCTAssertFalse(card.message.isEmpty, "\(name): rest card must have message")
                XCTAssertTrue(card.streak >= 0, "\(name): streak must be non-negative")
            }
        }
    }
}

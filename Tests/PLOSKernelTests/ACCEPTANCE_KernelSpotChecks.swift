import XCTest
import Foundation
@testable import PLOSKernel

/// ACCEPTANCE-only spot checks (Step 2 of the acceptance brief).
/// These verify §1 formulas against hand-derived expected values.
/// They are NOT part of the shipped kernel; delete or keep per reviewer decision.
final class ACCEPTANCE_KernelSpotChecks: XCTestCase {

    // MARK: - Shared sample data (PLAN §1 example, retargeted to July 2026)

    /// 高数 deadline · 线代 deadline · 项目 milestone · 英语 habit
    private func sampleGoals() -> [Goal] {
        [
            Goal(id: "math", subject: "高数", type: .deadline, target: "6章", unit: "章",
                 total: 6, done: 2,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 30),
                 importance: 1.2, successThreshold: 0.8),
            Goal(id: "linalg", subject: "线代", type: .deadline, target: "100题", unit: "题",
                 total: 100, done: 20,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 28),
                 importance: 1.0, successThreshold: 0.8),
            Goal(id: "proj", subject: "项目", type: .milestone, target: "课程作业", unit: "项",
                 total: 4, done: 1,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 25),
                 importance: 1.0, successThreshold: 0.8),
            Goal(id: "eng", subject: "英语", type: .habit, target: "每天阅读", unit: "天",
                 total: 30, done: 10,
                 start: RestSchedule.dateFrom(2026, 7, 1), deadline: RestSchedule.dateFrom(2026, 7, 31),
                 importance: 1.0, successThreshold: 0.7),
        ]
    }

    private func julyStrategy(flexUsed: Int = 0) -> RestStrategy {
        RestStrategy(cycleStudy: 5, cycleRest: 2, flexRestTotal: 2, flexUsed: flexUsed)
    }

    /// Build a study-day state for a given date + energy.
    private func studyState(day: Int, energy: Energy,
                            goals: [Goal]? = nil,
                            extraDays: [String: Day] = [:],
                            events: [Event] = [],
                            health: Health = Health()) -> (MonthState, Date) {
        let dateStr = String(format: "2026-07-%02d", day)
        var days = extraDays
        days[dateStr] = Day(date: dateStr, dayType: .study, energy: energy)
        let state = MonthState(
            goals: goals ?? sampleGoals(),
            days: days,
            restStrategy: julyStrategy(),
            events: events,
            health: health,
            streak: 5
        )
        return (state, RestSchedule.dateFrom(2026, 7, day))
    }

    // MARK: - (a) Rest schedule: backbone & floor for July 2026 (31 days)

    func test_ACCEPTANCE_a_july2026_backbone_and_floor() {
        // Derivation: cycle=7, study when (day-1)%7 < 5.
        // 31 = 4*7 + 3 → 4 full cycles (20 study) + days 29/30/31 (idx 0/1/2 = study) → backbone = 23.
        // floor(保底) = backbone - flexRestTotal = 23 - 2 = 21.
        let s = julyStrategy()
        XCTAssertEqual(RestSchedule.backboneStudyDays(year: 2026, month: 7, strategy: s), 23,
                       "学5休2 铺 July(31天) backbone = 23 (30天=22, per §1.3 example)")
        XCTAssertEqual(RestSchedule.studyDaysTotal(year: 2026, month: 7, strategy: s), 21,
                       "保底学习日 = 23 - 2 flex = 21")

        // Derived rem/elapsed for today = July 1 (flexUsed 0):
        // tomorrowDay=2 → remBackbone(2..31)=23-1=22; remFlex=2; rem=max(22-2,1)=20; elapsed=21-20=1.
        var st1 = MonthState(goals: sampleGoals(), restStrategy: julyStrategy())
        RestSchedule.fillDerived(state: &st1, today: RestSchedule.dateFrom(2026, 7, 1))
        XCTAssertEqual(st1.studyDaysRemaining, 20, "July 1: study_days_remaining = 20")
        XCTAssertEqual(st1.studyDaysElapsed, 1, "July 1: study_days_elapsed = 21-20 = 1")

        // today = July 15 (mid-month): tomorrowDay=16 → remBackbone(16..31)=12; rem=max(12-2,1)=10; elapsed=21-10=11.
        var st15 = MonthState(goals: sampleGoals(), restStrategy: julyStrategy())
        RestSchedule.fillDerived(state: &st15, today: RestSchedule.dateFrom(2026, 7, 15))
        XCTAssertEqual(st15.studyDaysRemaining, 10, "July 15: study_days_remaining = 10")
        XCTAssertEqual(st15.studyDaysElapsed, 11, "July 15: study_days_elapsed = 21-10 = 11")

        // Invariant: elapsed + remaining == total on every study day.
        XCTAssertEqual(st15.studyDaysElapsed + st15.studyDaysRemaining, st15.studyDaysTotal)
    }

    // MARK: - (b) Study-day axis iron rule: inserting a rest day must not move expected_progress

    func test_ACCEPTANCE_b_insertRestDay_expectedProgressUnchanged() {
        // Baseline plan for July 10 (a study day).
        let (stateA, today) = studyState(day: 10, energy: .normal)
        let planA = Scheduler.plan(state: stateA, today: today)

        // Insert an EXTRA rest day "midway" (July 6 is a rhythm-rest in the skeleton) as a Day record,
        // plus a spurious flexRest on July 8. These are calendar events between start and today.
        var extra = stateA.days
        extra["2026-07-06"] = Day(date: "2026-07-06", dayType: .rhythmRest, systemRan: true)
        extra["2026-07-08"] = Day(date: "2026-07-08", dayType: .flexRest, systemRan: true)
        var stateB = stateA
        stateB.days = extra
        let planB = Scheduler.plan(state: stateB, today: today)

        // Iron rule 1: expected_progress (and therefore the whole plan) is derived from the
        // skeleton + today only — inserting rest-day records cannot move it.
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try! enc.encode(planA), try! enc.encode(planB),
                       "Inserting rest-day records must not change the study plan")

        // Direct check: expected_progress identical.
        var d = stateA
        RestSchedule.fillDerived(state: &d, today: today)
        let ep = Scoring.expectedProgress(elapsed: d.studyDaysElapsed, total: d.studyDaysTotal)
        // July 10: elapsed = 8, total = 21 → ep = 8/21.
        XCTAssertEqual(ep, 8.0 / 21.0, accuracy: 1e-9,
                       "study-axis expected_progress = 8/21; a calendar axis would give ~9/31 — provably different")
        XCTAssertNotEqual(ep, 9.0 / 31.0, accuracy: 1e-6)
    }

    // MARK: - (c) Decay: monotone, endpoints 1 and FLOOR, and no if-passed branch

    func test_ACCEPTANCE_c_decay_monotone_and_endpoints() {
        let t = 0.8
        let atThreshold = Scoring.decay(over: Scoring.over(progress: t,        threshold: t)) // 1.0
        let atMid       = Scoring.decay(over: Scoring.over(progress: (t+1)/2,  threshold: t)) // 0.55
        let at99        = Scoring.decay(over: Scoring.over(progress: 0.99,      threshold: t)) // 0.145
        let atFull      = Scoring.decay(over: Scoring.over(progress: 1.0,       threshold: t)) // FLOOR

        XCTAssertEqual(atThreshold, 1.0, accuracy: 1e-9, "at threshold decay = 1")
        XCTAssertEqual(atMid, 0.55, accuracy: 1e-9, "at (t+1)/2 decay = 1 - 0.9*0.5 = 0.55")
        XCTAssertEqual(at99, 0.145, accuracy: 1e-9, "at 0.99 decay = 1 - 0.9*0.95 = 0.145")
        XCTAssertEqual(atFull, KernelConfig.importanceFloor, accuracy: 1e-9, "at 100% decay = FLOOR")

        // Strictly decreasing across [threshold, 1].
        XCTAssertGreaterThan(atThreshold, atMid)
        XCTAssertGreaterThan(atMid, at99)
        XCTAssertGreaterThan(at99, atFull)

        // Fine-grained monotonicity + endpoints.
        var prev = Double.infinity
        for i in 0...200 {
            let p = t + (1.0 - t) * Double(i) / 200.0
            let dec = Scoring.decay(over: Scoring.over(progress: p, threshold: t))
            XCTAssertLessThanOrEqual(dec, prev + 1e-12, "decay must be non-increasing")
            prev = dec
        }

        // Iron rule 2: passed vs. not-passed differ ONLY through the continuous decay factor.
        let passed = Goal(id: "p", subject: "P", type: .deadline, target: "", unit: "",
                          total: 10, done: 9, start: RestSchedule.dateFrom(2026, 7, 1),
                          deadline: RestSchedule.dateFrom(2026, 7, 30), successThreshold: 0.8)
        let notYet = Goal(id: "n", subject: "N", type: .deadline, target: "", unit: "",
                          total: 10, done: 5, start: RestSchedule.dateFrom(2026, 7, 1),
                          deadline: RestSchedule.dateFrom(2026, 7, 30), successThreshold: 0.8)
        let sp = Scoring.score(goal: passed, studyDaysElapsed: 10, studyDaysTotal: 20, studyDaysRemaining: 10)
        let sn = Scoring.score(goal: notYet, studyDaysElapsed: 10, studyDaysTotal: 20, studyDaysRemaining: 10)
        XCTAssertLessThan(sp.decay, 1.0, "passed goal: decay < 1")
        XCTAssertEqual(sn.decay, 1.0, accuracy: 1e-9, "not-yet goal: decay == 1 (no discrete jump)")
    }

    // MARK: - (d) Budget constraint per energy + low-energy deadline count ≤ 2

    func test_ACCEPTANCE_d_budget_and_lowEnergyCount() {
        let budgets: [Energy: Int] = [.high: 150, .normal: 100, .low: 45]
        for (energy, cap) in budgets {
            let (state, today) = studyState(day: 3, energy: energy)
            guard case let .study(items, _, _) = Scheduler.plan(state: state, today: today) else {
                XCTFail("\(energy): expected study plan"); continue
            }
            let total = items.reduce(0) { $0 + $1.minutes }
            XCTAssertLessThanOrEqual(total, cap, "\(energy): sum(minutes)=\(total) must be ≤ BUDGET \(cap)")

            if energy == .low {
                let deadlineItems = items.filter { it in
                    guard let g = state.goals.first(where: { $0.id == it.goalId }) else { return false }
                    return g.type == .deadline || g.type == .milestone
                }
                XCTAssertLessThanOrEqual(deadlineItems.count, 2,
                                         "低谷日 deadline/milestone 项 must be ≤ 2 (got \(deadlineItems.count))")
            }
        }
    }

    /// Documents a latent defect: when habit_count * HABIT_CHUNK > budget, sum(minutes) exceeds BUDGET,
    /// because habits are always emitted at HABIT_CHUNK and Scheduler's one-item clamp cannot recover it.
    func test_ACCEPTANCE_d2_budgetExceeded_whenManyHabits_DOCUMENTS_BUG() {
        let habits = (1...4).map { i in
            Goal(id: "h\(i)", subject: "习惯\(i)", type: .habit, target: "", unit: "天",
                 total: 30, done: 0, start: RestSchedule.dateFrom(2026, 7, 1),
                 deadline: RestSchedule.dateFrom(2026, 7, 31))
        }
        let (state, today) = studyState(day: 3, energy: .low, goals: habits)
        guard case let .study(items, _, _) = Scheduler.plan(state: state, today: today) else {
            XCTFail("expected study plan"); return
        }
        let total = items.reduce(0) { $0 + $1.minutes }
        // 4 habits * 15 = 60 > 45. This assertion PASSING confirms the budget invariant is violated.
        XCTAssertGreaterThan(total, KernelConfig.budget[.low]!,
                             "KNOWN DEFECT: sum(minutes)=\(total) exceeds low BUDGET 45 with 4 habits")
    }

    // MARK: - (e) Determinism: same (state, today) → byte-identical output, repeated

    func test_ACCEPTANCE_e_determinism_richState() {
        let health = Health(lastExercise: RestSchedule.dateFrom(2026, 6, 25),
                            lateNights7d: 4, highPressureStreak: 6)
        let events = [Event(type: "exam", subject: "线代", date: "2026-07-04")]
        let yesterday = Day(date: "2026-07-02", dayType: .study,
                            reported: [ReportItem(goalId: "math", completionPct: 50)])
        let (state, today) = studyState(day: 3, energy: .high,
                                        extraDays: ["2026-07-02": yesterday],
                                        events: events, health: health)
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let first = try! enc.encode(Scheduler.plan(state: state, today: today))
        for _ in 0..<5 {
            let again = try! enc.encode(Scheduler.plan(state: state, today: today))
            XCTAssertEqual(first, again, "determinism broken: repeated plan() differs")
        }
    }

    // MARK: - (f) §1.9 evening conversion formula (mirrors AppViewModel.saveEveningReport:262-263)

    /// done = min(total, done + completionPct/100 * plannedUnits)
    private func applyEvening(done: Double, total: Double, completionPct: Int, plannedUnits: Double) -> Double {
        min(total, done + Double(completionPct) / 100.0 * plannedUnits)
    }

    func test_ACCEPTANCE_f_eveningConversion() {
        // completionPct = 80, plannedUnits known → increment = 0.8 * plannedUnits.
        let d1 = applyEvening(done: 2.0, total: 6.0, completionPct: 80, plannedUnits: 0.5)
        XCTAssertEqual(d1, 2.4, accuracy: 1e-9, "2 + 0.8*0.5 = 2.4")
        XCTAssertLessThanOrEqual(d1, 6.0, "done must not exceed total")

        // Cap: increment would overshoot → clamped to total.
        let d2 = applyEvening(done: 5.8, total: 6.0, completionPct: 80, plannedUnits: 1.0)
        XCTAssertEqual(d2, 6.0, accuracy: 1e-9, "5.8 + 0.8 = 6.6 → capped at total 6.0")

        // 0% report → no progress, no penalty.
        let d3 = applyEvening(done: 3.0, total: 6.0, completionPct: 0, plannedUnits: 0.9)
        XCTAssertEqual(d3, 3.0, accuracy: 1e-9, "0% keeps done unchanged")
    }

    /// Documents that a habit item carries plannedUnits == 0, so the §1.9 increment is always 0 —
    /// a habit's `done` can never advance through the evening report.
    func test_ACCEPTANCE_f2_habitPlannedUnitsZero_DOCUMENTS_GAP() {
        let habit = Goal(id: "eng", subject: "英语", type: .habit, target: "", unit: "天",
                         total: 30, done: 10, start: RestSchedule.dateFrom(2026, 7, 1),
                         deadline: RestSchedule.dateFrom(2026, 7, 31))
        let alloc = Allocator.allocate(scores: [], habits: [habit], energy: .normal, studyDaysRemaining: 17)
        XCTAssertEqual(alloc.habitItems.count, 1)
        XCTAssertEqual(alloc.habitItems[0].plannedUnits, 0, "habit plannedUnits is 0")
        let after = applyEvening(done: habit.done, total: habit.total,
                                 completionPct: 100, plannedUnits: alloc.habitItems[0].plannedUnits)
        XCTAssertEqual(after, habit.done, accuracy: 1e-9,
                       "KNOWN GAP: habit done never advances via §1.9 (increment always 0)")
    }
}

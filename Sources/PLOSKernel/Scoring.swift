import Foundation

// MARK: - §1.4 Scoring (deadline / milestone goals)

/// A single score result for a specific goal.
public struct GoalScore: Equatable, Sendable {
    public let goalId: String
    public let goal: Goal
    public let progress: Double
    public let baselineToday: Double
    public let over: Double
    public let decay: Double
    public let expectedProgress: Double
    public let gap: Double
    public let urgency: Double
    public let pressure: Double

    public init(
        goalId: String,
        goal: Goal,
        progress: Double,
        baselineToday: Double,
        over: Double,
        decay: Double,
        expectedProgress: Double,
        gap: Double,
        urgency: Double,
        pressure: Double
    ) {
        self.goalId = goalId
        self.goal = goal
        self.progress = progress
        self.baselineToday = baselineToday
        self.over = over
        self.decay = decay
        self.expectedProgress = expectedProgress
        self.gap = gap
        self.urgency = urgency
        self.pressure = pressure
    }
}

/// §1.4 Scoring — pure functions, no side effects.
public enum Scoring {

    /// Compute progress for a goal: done / total.
    public static func progress(_ goal: Goal) -> Double {
        guard goal.total > 0 else { return 1.0 }
        return goal.done / goal.total
    }

    /// baseline_today = (total − done) / study_days_remaining
    public static func baselineToday(goal: Goal, studyDaysRemaining: Int) -> Double {
        guard studyDaysRemaining > 0 else { return 0 }
        return (goal.total - goal.done) / Double(studyDaysRemaining)
    }

    /// over = max(progress − successThreshold, 0) / max(1 − successThreshold, 1e-6)
    public static func over(progress: Double, threshold: Double) -> Double {
        let denom = max(1.0 - threshold, 1e-6)
        return max(progress - threshold, 0) / denom
    }

    /// decay = 1 − (1 − IMPORTANCE_FLOOR) * over
    /// At threshold → over=0 → decay=1
    /// At 100% → over=1 → decay=FLOOR
    /// Monotonically decreasing in between.
    public static func decay(over: Double) -> Double {
        1.0 - (1.0 - KernelConfig.importanceFloor) * over
    }

    /// expected_progress = study_days_elapsed / study_days_total
    public static func expectedProgress(elapsed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(elapsed) / Double(total)
    }

    /// gap = expected_progress − progress (>0 means behind)
    public static func gap(expectedProgress: Double, progress: Double) -> Double {
        expectedProgress - progress
    }

    /// urgency = 1 + URGENCY_K / study_days_remaining
    public static func urgency(studyDaysRemaining: Int) -> Double {
        guard studyDaysRemaining > 0 else { return 1.0 + KernelConfig.urgencyK }
        return 1.0 + KernelConfig.urgencyK / Double(studyDaysRemaining)
    }

    /// pressure = max(gap, 0) * urgency * importance * decay * (1 + 0.1 * historyDelay)
    /// gap ≤ 0 → pressure = 0 (don't penalize being ahead)
    public static func pressure(
        gap: Double,
        urgency: Double,
        importance: Double,
        decay: Double,
        historyDelay: Int
    ) -> Double {
        max(gap, 0) * urgency * importance * decay * (1.0 + 0.1 * Double(historyDelay))
    }

    /// Score a single goal against the given study-axis state.
    public static func score(
        goal: Goal,
        studyDaysElapsed: Int,
        studyDaysTotal: Int,
        studyDaysRemaining: Int
    ) -> GoalScore {
        let p = progress(goal)
        let bt = baselineToday(goal: goal, studyDaysRemaining: studyDaysRemaining)
        let ov = over(progress: p, threshold: goal.successThreshold)
        let d = decay(over: ov)
        let ep = expectedProgress(elapsed: studyDaysElapsed, total: studyDaysTotal)
        let g = gap(expectedProgress: ep, progress: p)
        let u = urgency(studyDaysRemaining: studyDaysRemaining)
        let pr = pressure(gap: g, urgency: u, importance: goal.importance, decay: d, historyDelay: goal.historyDelay)

        return GoalScore(
            goalId: goal.id,
            goal: goal,
            progress: p,
            baselineToday: bt,
            over: ov,
            decay: d,
            expectedProgress: ep,
            gap: g,
            urgency: u,
            pressure: pr
        )
    }

    /// Score all deadline and milestone goals (habits are handled separately).
    /// Returns scores sorted by pressure descending.
    public static func scoreAll(
        goals: [Goal],
        studyDaysElapsed: Int,
        studyDaysTotal: Int,
        studyDaysRemaining: Int
    ) -> [GoalScore] {
        let active = goals.filter { $0.type == .deadline || $0.type == .milestone }
        let scored = active.map { goal in
            score(
                goal: goal,
                studyDaysElapsed: studyDaysElapsed,
                studyDaysTotal: studyDaysTotal,
                studyDaysRemaining: studyDaysRemaining
            )
        }
        return scored.sorted { $0.pressure > $1.pressure }
    }
}

import Foundation

// MARK: - §1.6 Rule Layer (deterministic, applied in order)

/// Context that rules can read from.
public struct RuleContext {
    public let today: String           // "yyyy-MM-dd"
    public let yesterday: Day?         // Previous day's Day record
    public let events: [Event]         // Upcoming events
    public let health: Health          // Health snapshot
    public let scores: [GoalScore]     // Scored goals (for diversity)
    public let goals: [Goal]           // All goals (for lookups)
    public let days: [String: Day]     // All days in the month (for streak scanning)
}

/// Rule application order:
/// 1. Continuity (label append for partially-done yesterday)
/// 2. Pre-exam light mode (REVIEW_CHUNK + label)
/// 3. Diversity guard (swap MAX_CHUNK subjects if one dominates)
/// 4. Health reminders (text only, no budget changes)
public enum Rules {

    /// Continuity: if yesterday's goal had 0 < completionPct < 100 → append "（接昨天）" to label.
    public static func applyContinuity(
        items: [PlannedItem],
        context: RuleContext
    ) -> [PlannedItem] {
        guard let yesterday = context.yesterday else { return items }

        let partialGoalIds = Set(
            yesterday.reported
                .filter { $0.completionPct > 0 && $0.completionPct < 100 }
                .map { $0.goalId }
        )

        guard !partialGoalIds.isEmpty else { return items }

        return items.map { item in
            if partialGoalIds.contains(item.goalId) {
                var copy = item
                copy.label = "\(item.label)（接昨天）"
                return copy
            }
            return item
        }
    }

    /// Pre-exam light: if tomorrow has an exam for a subject → force REVIEW_CHUNK minutes,
    /// label "只复习，不上新内容", and move to top. "强制" (§1.6) also means the review item
    /// must exist: if the subject got no allocation today (on-track goals carry zero pressure),
    /// a review item is inserted rather than silently skipped.
    public static func applyPreExam(
        items: [PlannedItem],
        context: RuleContext
    ) -> [PlannedItem] {
        let todayDate = RestSchedule.parseDate(context.today)
        guard let todayDate else { return items }

        let tomorrow = RestSchedule.calendar.date(byAdding: .day, value: 1, to: todayDate)!
        let tomorrowStr = RestSchedule.dateString(tomorrow)

        let examSubjects = Set(
            context.events
                .filter { $0.type == "exam" && $0.date == tomorrowStr }
                .map { $0.subject }
        )

        guard !examSubjects.isEmpty else { return items }

        // Find which goal IDs map to exam subjects (kept in goal order for determinism)
        let examGoals = context.goals.filter { examSubjects.contains($0.subject) }
        let examGoalIds = Set(examGoals.map { $0.id })

        var result = items.map { item -> PlannedItem in
            if examGoalIds.contains(item.goalId) {
                var copy = item
                copy.minutes = KernelConfig.reviewChunk
                copy.label = "只复习，不上新内容"
                return copy
            }
            return item
        }

        // Insert review items for exam subjects that got no allocation today.
        // plannedUnits = 0: reviewing does not advance the goal's unit count (§1.9).
        let presentIds = Set(result.map { $0.goalId })
        for goal in examGoals where !presentIds.contains(goal.id) {
            result.append(PlannedItem(
                goalId: goal.id,
                minutes: KernelConfig.reviewChunk,
                label: "只复习，不上新内容",
                plannedUnits: 0,
                order: result.count
            ))
        }

        // Move exam items to top
        let examItems = result.filter { examGoalIds.contains($0.goalId) }
        let otherItems = result.filter { !examGoalIds.contains($0.goalId) }
        result = examItems + otherItems

        // Re-number order
        for (i, _) in result.enumerated() {
            result[i].order = i
        }

        return result
    }

    /// Diversity guard: if a subject has gotten MAX_CHUNK for ≥3 consecutive study days
    /// AND there's another subject with pressure within DIVERSITY_PRESSURE_RATIO → both step back.
    public static func applyDiversity(
        items: [PlannedItem],
        context: RuleContext
    ) -> [PlannedItem] {
        guard items.count >= 2 else { return items }

        // Build streak by scanning backward through days
        let sortedDates = context.days.keys.sorted()
        var streak = 0
        for dateStr in sortedDates.reversed() {
            guard let day = context.days[dateStr], day.dayType == .study else { break }
            let hasMax = day.planned.contains { $0.minutes >= KernelConfig.maxChunk }
            if hasMax {
                streak += 1
            } else {
                break
            }
        }

        // Identify which goals in today's plan had MAX_CHUNK in recent plan
        // (simplified: check if today's plan has MAX_CHUNK items)
        let maxItems = items.filter { $0.minutes >= KernelConfig.maxChunk }
        guard !maxItems.isEmpty else { return items }

        // Check if diversity threshold met
        if streak < KernelConfig.diversityThreshold { return items }

        // Find "close enough" subjects (pressure within DIVERSITY_PRESSURE_RATIO)
        let scoredGoalIds = Set(items.map { $0.goalId })
        let scored = context.scores.filter { scoredGoalIds.contains($0.goalId) }

        var result = items
        for maxItem in maxItems {
            guard let maxScore = scored.first(where: { $0.goalId == maxItem.goalId }) else { continue }

            let closeEnough = scored.filter { score in
                score.goalId != maxItem.goalId
                    && abs(score.pressure - maxScore.pressure) / max(maxScore.pressure, 1e-9) < KernelConfig.diversityPressureRatio
            }

            if let alt = closeEnough.first,
               let maxIdx = result.firstIndex(where: { $0.goalId == maxItem.goalId }),
               let altIdx = result.firstIndex(where: { $0.goalId == alt.goalId }) {
                // Both step back: reduce MAX_CHUNK items by ~15 min each
                let reduction = 15
                result[maxIdx].minutes = max(result[maxIdx].minutes - reduction, KernelConfig.minChunk)
                result[altIdx].minutes = max(result[altIdx].minutes - reduction, KernelConfig.minChunk)
            }
        }

        return result
    }

    /// Health reminders: check thresholds, return warning strings.
    /// Does NOT modify the plan — only returns text.
    public static func healthReminders(
        context: RuleContext
    ) -> [String] {
        var notes: [String] = []

        if let lastExercise = context.health.lastExercise,
           let todayDate = RestSchedule.parseDate(context.today) {
            let daysSince = RestSchedule.calendar
                .dateComponents([.day], from: lastExercise, to: todayDate).day ?? 0
            if daysSince >= 4 {
                notes.append("已连续\(daysSince)天未运动，建议今晚早点休息。")
            }
        }

        if context.health.lateNights7d >= 3 {
            notes.append("近一周熬夜\(context.health.lateNights7d)次，注意休息。")
        }

        if context.health.highPressureStreak >= 5 {
            notes.append("已连续\(context.health.highPressureStreak)天高压力学习，建议适当放松。")
        }

        return notes
    }

    /// Look up yesterday's Day from the days dictionary given today's date string.
    public static func yesterday(from days: [String: Day], today: String) -> Day? {
        guard let todayDate = RestSchedule.parseDate(today) else { return nil }
        let yesterdayDate = RestSchedule.calendar
            .date(byAdding: .day, value: -1, to: todayDate)!
        let yesterdayStr = RestSchedule.dateString(yesterdayDate)
        return days[yesterdayStr]
    }

    /// Build the full rule context from available state.
    public static func buildContext(
        state: MonthState,
        today: String,
        scores: [GoalScore]
    ) -> RuleContext {
        let yday = yesterday(from: state.days, today: today)
        return RuleContext(
            today: today,
            yesterday: yday,
            events: state.events,
            health: state.health,
            scores: scores,
            goals: state.goals,
            days: state.days
        )
    }
}

import Foundation

// MARK: - §1.5 Allocation

/// Result of budget allocation ready for rule application.
public struct AllocationResult: Equatable, Sendable {
    public var items: [PlannedItem]
    /// Habit items that always get their chunk.
    public var habitItems: [PlannedItem]
}

public enum Allocator {

    /// Full allocation pipeline:
    /// 1. Budget from energy level
    /// 2. All habits get HABIT_CHUNK each
    /// 3. Remaining distributed by pressure share, capped at baseline_today-equivalent minutes and MAX_CHUNK
    /// 4. Low-energy: keep only top 1–2 deadline items + habits
    /// 5. Output sorted by pressure descending
    public static func allocate(
        scores: [GoalScore],
        habits: [Goal],
        energy: Energy,
        studyDaysRemaining: Int
    ) -> AllocationResult {
        let budget = KernelConfig.budget[energy] ?? 100

        // Step 1: Habits get fixed chunks — but never past the budget.
        // Deterministic truncation: habits are admitted in goal order until the next
        // chunk would overflow (e.g. low day 45 min ÷ 15 min chunks → at most 3 habits).
        var habitItems: [PlannedItem] = []
        var habitCost = 0
        for (idx, habit) in habits.enumerated() {
            if habitCost + KernelConfig.habitChunk > budget { break }
            let item = PlannedItem(
                goalId: habit.id,
                minutes: KernelConfig.habitChunk,
                label: "\(habit.subject)日常",
                plannedUnits: 0,
                order: idx
            )
            habitItems.append(item)
            habitCost += KernelConfig.habitChunk
        }

        var remainingBudget = max(budget - habitCost, 0)

        var eligibleScores = scores

        // Low-energy: keep only top 1–2 pressure items + habits
        if energy == .low {
            let topCount = min(2, eligibleScores.count)
            eligibleScores = Array(eligibleScores.prefix(topCount))
        }

        // Step 3: Distribute remaining budget by pressure share
        let totalPressure = eligibleScores.reduce(0.0) { $0 + $1.pressure }
        var allocatedItems: [PlannedItem] = []

        // Baseline alignment (§1.5 "向 baseline_today 看齐"): each goal's cap is its
        // share of the post-habit budget by NORMALIZED remaining need — baselineToday/total,
        // a unitless per-day fraction — so subjects with different units (章 vs 题) compare
        // fairly, and passed-threshold goals (small remaining fraction) naturally yield.
        // (The old formula compared units against minutes and collapsed every cap below
        // MIN_CHUNK early in the month, leaving habit-only plans.)
        let shareBudget = remainingBudget
        let totalNormBaseline = eligibleScores.reduce(0.0) {
            $0 + max($1.baselineToday, 0) / max($1.goal.total, 1e-9)
        }

        for (order, score) in eligibleScores.enumerated() {
            if remainingBudget < KernelConfig.minChunk { break }

            // Minutes proportional to pressure share
            let pressureShare: Double
            if totalPressure > 1e-9 {
                pressureShare = score.pressure / totalPressure
            } else {
                pressureShare = 1.0 / Double(max(eligibleScores.count, 1))
            }

            var rawMinutes = Int((Double(remainingBudget) * pressureShare).rounded())

            let baselineAlignedMinutes: Int
            let normBaseline = max(score.baselineToday, 0) / max(score.goal.total, 1e-9)
            if normBaseline > 0, totalNormBaseline > 1e-9 {
                let fairShare = Double(shareBudget) * normBaseline / totalNormBaseline
                baselineAlignedMinutes = min(Int(fairShare.rounded()), KernelConfig.maxChunk)
            } else {
                baselineAlignedMinutes = KernelConfig.maxChunk
            }

            rawMinutes = min(rawMinutes, baselineAlignedMinutes)
            rawMinutes = min(rawMinutes, KernelConfig.maxChunk)
            rawMinutes = max(rawMinutes, 0)

            // Min chunk check
            if rawMinutes < KernelConfig.minChunk { continue }

            rawMinutes = min(rawMinutes, remainingBudget)
            remainingBudget -= rawMinutes

            // Compute plannedUnits from baseline_today
            let units = score.baselineToday > 0
                ? Double(rawMinutes) / Double(budget) * score.baselineToday
                : 0

            let item = PlannedItem(
                goalId: score.goalId,
                minutes: rawMinutes,
                label: score.goal.subject,
                plannedUnits: max(units, 0),
                order: order
            )
            allocatedItems.append(item)
        }

        // Redistribute any leftover budget to the first item (up to MAX_CHUNK)
        if remainingBudget >= KernelConfig.minChunk, let firstIdx = allocatedItems.indices.first {
            let add = remainingBudget
            let newMin = min(allocatedItems[firstIdx].minutes + add, KernelConfig.maxChunk)
            let actualAdd = newMin - allocatedItems[firstIdx].minutes
            allocatedItems[firstIdx].minutes = newMin
            remainingBudget -= actualAdd
        }

        return AllocationResult(items: allocatedItems, habitItems: habitItems)
    }
}

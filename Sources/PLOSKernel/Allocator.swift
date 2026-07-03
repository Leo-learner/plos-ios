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

        // Step 1: Habits get fixed chunks
        var habitItems: [PlannedItem] = []
        var habitCost = 0
        for (idx, habit) in habits.enumerated() {
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

        // Step 2: Filter out scores that would get less than MIN_CHUNK
        var eligibleScores = scores.filter { _ in true }

        // Low-energy: keep only top 1–2 pressure items + habits
        if energy == .low {
            let topCount = min(2, eligibleScores.count)
            eligibleScores = Array(eligibleScores.prefix(topCount))
        }

        // Step 3: Distribute remaining budget by pressure share
        let totalPressure = eligibleScores.reduce(0.0) { $0 + $1.pressure }
        var allocatedItems: [PlannedItem] = []

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

            // Cap 1: align to baseline_today equivalent
            // baselineToday is in goal-units/day, convert to minutes by ratio:
            // If a subject needs baselineToday units today, cap at MAX_CHUNK or
            // the equivalent of baselineToday (whichever is smaller)
            let baselineAlignedMinutes: Int
            if score.baselineToday > 0 {
                // baselineToday as a proportion of total → scale to budget
                let proportion = score.baselineToday / max(score.goal.total, 1e-9)
                baselineAlignedMinutes = min(Int(proportion * Double(budget)), KernelConfig.maxChunk)
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

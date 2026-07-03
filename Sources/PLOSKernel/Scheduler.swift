import Foundation

// MARK: - §1.8 Scheduler (Orchestrator + public API)

/// The kernel's sole public entry point: given a MonthState and a `today` date,
/// produce a deterministic DayPlan.
public enum Scheduler {

    /// Main entry point — pure function, `today` injected as parameter.
    /// No `Date()` or `Calendar.current` calls anywhere in the pipeline.
    public static func plan(state: MonthState, today: Date) -> DayPlan {
        // Fill derived study-axis values
        var s = state
        RestSchedule.fillDerived(state: &s, today: today)
        let todayStr = RestSchedule.dateString(today)

        // Look up today's Day record (if it exists)
        let todayDay = s.days[todayStr]

        // Short-circuit: if today is not a study day, return rest card
        if let day = todayDay, day.dayType != .study {
            return restPlan(dayType: day.dayType, state: s)
        }

        // If no Day record but the skeleton says it's a rest day, also short-circuit
        let (y, m, d) = RestSchedule.dateComponents(today)
        let skeleton = RestSchedule.monthSkeleton(year: y, month: m, strategy: s.restStrategy)
        if d >= 1 && d <= skeleton.count {
            let skeletonType = skeleton[d - 1]
            if skeletonType != .study && todayDay == nil {
                // Skeleton says rest, no explicit Day → treat as rhythm rest
                return restPlan(dayType: skeletonType, state: s)
            }
        }

        // Study-day pipeline
        return studyPlan(state: s, today: today, todayStr: todayStr, energy: todayDay?.energy ?? .normal)
    }

    // MARK: - Rest Plan

    private static func restPlan(dayType: DayType, state: MonthState) -> DayPlan {
        let flexRem = state.restStrategy.flexRestTotal - state.restStrategy.flexUsed
        let message = Reasoning.restCard(
            dayType: dayType,
            streak: state.streak,
            flexRemaining: dayType == .flexRest ? flexRem : nil
        )
        return .rest(card: RestCard(message: message, streak: state.streak))
    }

    // MARK: - Study Plan Pipeline

    private static func studyPlan(
        state: MonthState,
        today: Date,
        todayStr: String,
        energy: Energy
    ) -> DayPlan {
        let budget = KernelConfig.budget[energy] ?? 100

        // Step 1: Score all deadline/milestone goals
        let scores = Scoring.scoreAll(
            goals: state.goals,
            studyDaysElapsed: state.studyDaysElapsed,
            studyDaysTotal: state.studyDaysTotal,
            studyDaysRemaining: state.studyDaysRemaining
        )

        // Step 2: Separate habits
        let habitGoals = state.goals.filter { $0.type == .habit }

        // Step 3: Allocate budget
        let allocation = Allocator.allocate(
            scores: scores,
            habits: habitGoals,
            energy: energy,
            studyDaysRemaining: state.studyDaysRemaining
        )

        // Combine habit + deadline items
        var allItems = allocation.habitItems + allocation.items

        // Re-number order
        for i in allItems.indices {
            allItems[i].order = i
        }

        // Step 4: Apply rules in order
        let ruleContext = Rules.buildContext(state: state, today: todayStr, scores: scores)
        allItems = Rules.applyContinuity(items: allItems, context: ruleContext)
        allItems = Rules.applyPreExam(items: allItems, context: ruleContext)
        allItems = Rules.applyDiversity(items: allItems, context: ruleContext)

        // Step 5: Health reminders (text only)
        let healthNotes = Rules.healthReminders(context: ruleContext)

        // Step 6: Generate reasoning
        let reasoning = Reasoning.generate(
            energy: energy,
            budget: budget,
            items: allItems,
            scores: scores,
            goals: state.goals,
            state: state,
            today: today,
            context: ruleContext
        )

        // Step 7: Verify budget constraint
        let totalMinutes = allItems.reduce(0) { $0 + $1.minutes }
        if totalMinutes > budget {
            // Clamp: reduce the largest item
            var clamped = allItems
            if let maxIdx = clamped.indices.max(by: { clamped[$0].minutes < clamped[$1].minutes }) {
                let excess = totalMinutes - budget
                clamped[maxIdx].minutes = max(clamped[maxIdx].minutes - excess, KernelConfig.minChunk)
            }
            allItems = clamped
        }

        return .study(items: allItems, reasoning: reasoning, healthNotes: healthNotes)
    }
}

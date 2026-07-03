import Foundation

// MARK: - §1.7 Template Reasoning

/// Assembles the natural-language reasoning paragraph from triggered templates.
/// Every sentence must contain at least one number or verifiable fact — no empty filler.
public enum Reasoning {

    /// Generate the full reasoning string for a study-day plan.
    public static func generate(
        energy: Energy,
        budget: Int,
        items: [PlannedItem],
        scores: [GoalScore],
        goals: [Goal],
        state: MonthState,
        today: Date,
        context: RuleContext
    ) -> String {
        var parts: [String] = []

        // 1. Status sentence (always present)
        parts.append(statusSentence(energy: energy, budget: budget, itemCount: items.count))

        // 2. For each item, build a main-push or benchmark sentence
        let goalMap = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0) })
        let scoreMap = Dictionary(uniqueKeysWithValues: scores.map { ($0.goalId, $0) })
        var usedSubjects = Set<String>()

        for item in items {
            if let score = scoreMap[item.goalId] {
                if score.gap > 0.05 {
                    // Main push: subject is behind
                    parts.append(mainPushSentence(
                        subject: item.label,
                        subjectName: goalMap[item.goalId]?.subject ?? item.label,
                        gap: score.gap,
                        progress: score.progress,
                        remainingDays: state.studyDaysRemaining
                    ))
                    usedSubjects.insert(goalMap[item.goalId]?.subject ?? item.label)
                }
            }
        }

        for item in items {
            if let score = scoreMap[item.goalId] {
                let subjectName = goalMap[item.goalId]?.subject ?? item.label
                if score.gap <= 0.05, !usedSubjects.contains(subjectName) {
                    // Benchmark: on track or ahead
                    parts.append(benchmarkSentence(
                        subject: subjectName,
                        units: item.plannedUnits,
                        unit: goalMap[item.goalId]?.unit ?? "",
                        remainingUnits: score.goal.total - score.goal.done,
                        days: state.studyDaysRemaining
                    ))
                }
            }
        }

        // 3. Yield sentence: for goals at or past threshold (decay in effect)
        let passedGoals = scores.filter { $0.progress >= $0.goal.successThreshold }
        for pg in passedGoals {
            parts.append(yieldSentence(
                subject: pg.goal.subject,
                progress: pg.progress,
                threshold: pg.goal.successThreshold
            ))
        }

        // 4. Pre-exam sentence (if triggered)
        if let exam = preExamSentence(context: context) {
            parts.append(exam)
        }

        // 5. Health sentence (if triggered)
        let healthNotes = Rules.healthReminders(context: context)
        for note in healthNotes {
            parts.append(note)
        }

        // 6. Streak / continuity note
        if state.streak > 0 {
            parts.append("系统连续运行第\(state.streak)天。")
        }

        return parts.joined(separator: "\n")
    }

    /// Generate a rest-card reasoning paragraph.
    public static func restCard(
        dayType: DayType,
        streak: Int,
        flexRemaining: Int?
    ) -> String {
        switch dayType {
        case .rhythmRest:
            return "今天是计划内休息日，好好休息。系统仍在运行——连续第\(streak)天。"
        case .flexRest:
            let r = flexRemaining ?? 0
            return "已使用1个灵活休息日（剩余\(r)个），不影响整体节奏与基准。系统仍在运行——连续第\(streak)天。"
        case .study:
            return ""  // Should never be called for study days
        }
    }

    // MARK: - Sentence Templates

    /// [状态句] Energy-based budget description.
    private static func statusSentence(energy: Energy, budget: Int, itemCount: Int) -> String {
        switch energy {
        case .high:
            return "高能日，预算\(budget)分钟，安排\(itemCount)项。"
        case .normal:
            return "普通日，预算\(budget)分钟，安排\(itemCount)项。"
        case .low:
            return "低谷日，预算压到\(budget)分钟，只保最关键项，其余明天再追。"
        }
    }

    /// [主推句] Subject is behind schedule.
    private static func mainPushSentence(
        subject: String,
        subjectName: String,
        gap: Double,
        progress: Double,
        remainingDays: Int
    ) -> String {
        let gapPct = Int(gap * 100)
        return "\(subjectName)落后节奏\(gapPct)%、保底剩余学习日\(remainingDays)天、压力最高，今日优先。"
    }

    /// [让位句] Subject passed threshold, yielding to others.
    private static func yieldSentence(
        subject: String,
        progress: Double,
        threshold: Double
    ) -> String {
        let progressPct = Int(progress * 100)
        let thresholdPct = Int(threshold * 100)
        return "\(subject)已过达标线（\(progressPct)%≥\(thresholdPct)%），优先级让给未达标科目。"
    }

    /// [基准句] Subject on track.
    private static func benchmarkSentence(
        subject: String,
        units: Double,
        unit: String,
        remainingUnits: Double,
        days: Int
    ) -> String {
        let uStr = String(format: "%.1f", units)
        let rStr = String(format: "%.1f", remainingUnits)
        let u = unit.isEmpty ? "单位" : unit
        return "\(subject)按基准推进：今日\(uStr)\(u)（剩余\(rStr)\(u)÷\(days)天）。"
    }

    /// [考前句] Tomorrow has an exam — only review.
    private static func preExamSentence(context: RuleContext) -> String? {
        guard let todayDate = RestSchedule.parseDate(context.today) else { return nil }
        let tomorrow = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: todayDate)!
        let tomorrowStr = RestSchedule.dateString(tomorrow)

        let exams = context.events.filter { $0.type == "exam" && $0.date == tomorrowStr }
        guard let exam = exams.first else { return nil }
        return "明天\(exam.subject)考试，今日只安排复习，不上新内容。"
    }
}

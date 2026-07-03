import Foundation

// MARK: - Mock Data for static UI preview

/// All screens use these mock models; no kernel, no persistence, no networking.

// ── Goal

struct MockGoal: Identifiable {
    let id: String
    var subject: String
    var type: GoalType
    var target: String
    var unit: String
    var total: Double
    var done: Double
    var deadline: String
    var importance: Importance
    var successThreshold: Double
}

enum GoalType: String, CaseIterable {
    case deadline  = "按期完成"
    case habit     = "每天做"
    case milestone = "节点完成"
}

enum Importance: String, CaseIterable {
    case low  = "低"
    case mid  = "中"
    case high = "高"
}

// ── Planned Item

struct MockPlannedItem: Identifiable {
    let id = UUID()
    var goalId: String
    var subject: String
    var minutes: Int
    var label: String
    var tag: String?        // "落后节奏", "每日", "考前·只复习", "已达标"
    var isDone: Bool
    var order: Int
}

// ── Month State (static mock)

enum MockDayType {
    case study(energy: EnergyLevel)
    case rhythmRest
    case flexRest
}

enum EnergyLevel: String, CaseIterable {
    case high   = "高能"
    case normal = "普通"
    case low    = "低谷"
}

// ── Full Mock State

struct MockMonthState {
    var goals: [MockGoal]
    var restStrategy: (study: Int, rest: Int, flexTotal: Int, flexUsed: Int)
    var todayType: MockDayType
    var streak: Int
    var plannedItems: [MockPlannedItem]
    var reasoning: String
    var healthReminder: String?
    var examWarning: String?
    var dateString: String

    var budgetMinutes: Int {
        switch todayType {
        case .study(let energy):
            switch energy {
            case .high:   return 150
            case .normal: return 100
            case .low:    return 45
            }
        default: return 0
        }
    }

    var studyDaysTotal: Int {
        // 学5休2 × 31天 ≈ 23 backbone − flexTotal
        let backbone = 23
        return backbone - restStrategy.flexTotal
    }

    var studyDaysRemaining: Int {
        // roughly mid-month
        max(studyDaysTotal - 10, 1)
    }
}

// MARK: - Sample Data

enum MockData {

    static let defaultGoals: [MockGoal] = [
        MockGoal(
            id: "math", subject: "高数", type: .deadline,
            target: "6 章", unit: "章", total: 6, done: 2.0,
            deadline: "6/30", importance: .high, successThreshold: 0.8
        ),
        MockGoal(
            id: "eng", subject: "英语", type: .habit,
            target: "每天阅读", unit: "天", total: 30, done: 15,
            deadline: "6/30", importance: .mid, successThreshold: 0.7
        ),
        MockGoal(
            id: "linalg", subject: "线代", type: .deadline,
            target: "100 题", unit: "题", total: 100, done: 28,
            deadline: "6/28", importance: .mid, successThreshold: 0.8
        ),
        MockGoal(
            id: "project", subject: "项目", type: .milestone,
            target: "课程作业", unit: "项", total: 1, done: 0.4,
            deadline: "6/25", importance: .low, successThreshold: 1.0
        ),
    ]

    // ── High energy day

    static func highEnergy() -> MockMonthState {
        MockMonthState(
            goals: defaultGoals,
            restStrategy: (5, 2, 2, 0),
            todayType: .study(energy: .high),
            streak: 16,
            plannedItems: [
                MockPlannedItem(goalId: "linalg", subject: "线代", minutes: 55,
                                label: "刷题 15 题（接昨天）", tag: "落后节奏", isDone: false, order: 1),
                MockPlannedItem(goalId: "math", subject: "高数", minutes: 50,
                                label: "第 4 章 · 推进 0.5 章", tag: nil, isDone: false, order: 2),
                MockPlannedItem(goalId: "project", subject: "项目", minutes: 30,
                                label: "课程作业推进", tag: "截止 6/25", isDone: false, order: 3),
                MockPlannedItem(goalId: "eng", subject: "英语", minutes: 15,
                                label: "英语阅读", tag: "每日", isDone: false, order: 4),
            ],
            reasoning: "高能日，预算 150 分钟，安排 4 项。线代落后节奏 27%、压力最高，多分到 55 分钟；高数推进 0.5 章（基准 0.23 章 = 剩 2.5 章 ÷ 11 天，高能日加倍）；项目 6/25 截止，保持推进；英语照常。单科上限 90 分钟，不透支。",
            healthReminder: nil,
            examWarning: nil,
            dateString: "6 月 16 日 · 周二"
        )
    }

    // ── Low energy day

    static func lowEnergy() -> MockMonthState {
        MockMonthState(
            goals: defaultGoals,
            restStrategy: (5, 2, 2, 0),
            todayType: .study(energy: .low),
            streak: 12,
            plannedItems: [
                MockPlannedItem(goalId: "linalg", subject: "线代", minutes: 30,
                                label: "线代刷题（接昨天）", tag: "落后节奏", isDone: false, order: 1),
                MockPlannedItem(goalId: "eng", subject: "英语", minutes: 15,
                                label: "英语阅读", tag: "每日", isDone: false, order: 2),
            ],
            reasoning: "今天是低谷日，把预算压到 45 分钟。线代落后节奏 27%、保底剩余学习日只剩 13 天、压力最高，所以今天只保它和英语日常；其余明天再追。",
            healthReminder: "已连续 4 天没有运动，今晚早点睡、动一动。不改今天的计划。",
            examWarning: nil,
            dateString: "6 月 12 日 · 周五"
        )
    }

    // ── Normal day with exam warning + passed goal

    static func normalWithExam() -> MockMonthState {
        MockMonthState(
            goals: defaultGoals,
            restStrategy: (5, 2, 2, 0),
            todayType: .study(energy: .normal),
            streak: 18,
            plannedItems: [
                MockPlannedItem(goalId: "math", subject: "高数", minutes: 20,
                                label: "错题复习 1–3 章", tag: "考前·只复习", isDone: false, order: 1),
                MockPlannedItem(goalId: "eng", subject: "英语", minutes: 15,
                                label: "英语阅读", tag: "每日", isDone: false, order: 2),
                MockPlannedItem(goalId: "linalg", subject: "线代", minutes: 0,
                                label: "今天让位给未达标科目", tag: "已达标 80%", isDone: true, order: 3),
            ],
            reasoning: "明天高数考试，今日只安排复习（20 分钟），不上新内容。线代已过 80% 达标线，优先级让给未达标科目；英语保持每日节奏。",
            healthReminder: nil,
            examWarning: "明天高数考试：今天只复习，不上新内容。",
            dateString: "6 月 18 日 · 周四"
        )
    }

    // ── Rhythm rest

    static func rhythmRest() -> MockMonthState {
        MockMonthState(
            goals: defaultGoals,
            restStrategy: (5, 2, 2, 0),
            todayType: .rhythmRest,
            streak: 14,
            plannedItems: [],
            reasoning: "",
            healthReminder: nil,
            examWarning: nil,
            dateString: "6 月 14 日 · 周日"
        )
    }

    // ── Flex rest

    static func flexRest() -> MockMonthState {
        MockMonthState(
            goals: defaultGoals,
            restStrategy: (5, 2, 2, 1),
            todayType: .flexRest,
            streak: 15,
            plannedItems: [],
            reasoning: "",
            healthReminder: nil,
            examWarning: nil,
            dateString: "6 月 15 日 · 周一"
        )
    }

    // ── Evening report

    static func evening() -> MockMonthState {
        MockMonthState(
            goals: defaultGoals,
            restStrategy: (5, 2, 2, 0),
            todayType: .study(energy: .low),
            streak: 12,
            plannedItems: [
                MockPlannedItem(goalId: "linalg", subject: "线代", minutes: 30,
                                label: "线代刷题（接昨天）", tag: nil, isDone: false, order: 1),
                MockPlannedItem(goalId: "eng", subject: "英语", minutes: 15,
                                label: "英语阅读", tag: nil, isDone: true, order: 2),
            ],
            reasoning: "",
            healthReminder: nil,
            examWarning: nil,
            dateString: "6 月 12 日 · 睡前"
        )
    }
}

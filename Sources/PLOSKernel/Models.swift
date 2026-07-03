import Foundation

// MARK: - §1.2 Data Models (Codable for fixture JSON decoding)

/// Type of a learning goal.
public enum GoalType: String, Codable, Equatable, Sendable {
    case deadline   // Must be completed by a fixed date
    case habit      // Daily practice, every study day
    case milestone  // One-time project/milestone
}

/// A single learning goal for the month.
public struct Goal: Codable, Equatable, Sendable {
    public var id: String
    public var subject: String
    public var type: GoalType
    public var target: String       // Human-readable target description
    public var unit: String         // e.g. "章", "题", "页"
    public var total: Double        // Total units to complete
    public var done: Double         // Units completed so far
    public var start: Date          // Goal start date
    public var deadline: Date       // Goal deadline
    public var importance: Double   // Default 1.0, higher = more important
    public var successThreshold: Double  // e.g. 0.8 = 80% is "done enough"
    public var historyDelay: Int    // Days this goal was delayed in the past

    public init(
        id: String,
        subject: String,
        type: GoalType,
        target: String,
        unit: String,
        total: Double,
        done: Double = 0,
        start: Date,
        deadline: Date,
        importance: Double = 1.0,
        successThreshold: Double = 0.8,
        historyDelay: Int = 0
    ) {
        self.id = id
        self.subject = subject
        self.type = type
        self.target = target
        self.unit = unit
        self.total = total
        self.done = done
        self.start = start
        self.deadline = deadline
        self.importance = importance
        self.successThreshold = successThreshold
        self.historyDelay = historyDelay
    }
}

// MARK: - Rest Strategy

/// Monthly rest strategy: study N days, rest M days, plus flexible rest pool.
public struct RestStrategy: Codable, Equatable, Sendable {
    public var cycleStudy: Int      // e.g. 5
    public var cycleRest: Int       // e.g. 2
    public var flexRestTotal: Int   // e.g. 2
    public var flexUsed: Int        // currently used flexible rest days

    public init(cycleStudy: Int, cycleRest: Int, flexRestTotal: Int, flexUsed: Int = 0) {
        self.cycleStudy = cycleStudy
        self.cycleRest = cycleRest
        self.flexRestTotal = flexRestTotal
        self.flexUsed = flexUsed
    }
}

// MARK: - Day

public enum DayType: String, Codable, Equatable, Sendable {
    case study
    case rhythmRest     // Skeleton rhythm rest day
    case flexRest       // User spent a flexible rest day
}

public enum Energy: String, Codable, Equatable, Sendable {
    case high
    case normal
    case low
}

public struct Day: Codable, Equatable, Sendable {
    public var date: String             // "yyyy-MM-dd"
    public var dayType: DayType
    public var energy: Energy?
    public var planned: [PlannedItem]
    public var reported: [ReportItem]
    public var systemRan: Bool
    public var note: String?

    public init(
        date: String,
        dayType: DayType,
        energy: Energy? = nil,
        planned: [PlannedItem] = [],
        reported: [ReportItem] = [],
        systemRan: Bool = false,
        note: String? = nil
    ) {
        self.date = date
        self.dayType = dayType
        self.energy = energy
        self.planned = planned
        self.reported = reported
        self.systemRan = systemRan
        self.note = note
    }
}

// MARK: - Planned Item

public struct PlannedItem: Codable, Equatable, Sendable {
    public var goalId: String
    public var minutes: Int
    public var label: String
    public var plannedUnits: Double
    public var order: Int

    public init(
        goalId: String,
        minutes: Int,
        label: String,
        plannedUnits: Double,
        order: Int
    ) {
        self.goalId = goalId
        self.minutes = minutes
        self.label = label
        self.plannedUnits = plannedUnits
        self.order = order
    }
}

// MARK: - Report Item

public struct ReportItem: Codable, Equatable, Sendable {
    public var goalId: String
    public var completionPct: Int       // 0–100

    public init(goalId: String, completionPct: Int) {
        self.goalId = goalId
        self.completionPct = completionPct
    }
}

// MARK: - Health

public struct Health: Codable, Equatable, Sendable {
    public var lastExercise: Date?
    public var lateNights7d: Int
    public var highPressureStreak: Int

    public init(
        lastExercise: Date? = nil,
        lateNights7d: Int = 0,
        highPressureStreak: Int = 0
    ) {
        self.lastExercise = lastExercise
        self.lateNights7d = lateNights7d
        self.highPressureStreak = highPressureStreak
    }
}

// MARK: - Event

public struct Event: Codable, Equatable, Sendable {
    public var type: String             // "exam"
    public var subject: String
    public var date: String             // "yyyy-MM-dd"

    public init(type: String, subject: String, date: String) {
        self.type = type
        self.subject = subject
        self.date = date
    }
}

// MARK: - Month (MonthState for kernel input)

/// The complete state passed to `plan(state:today:)`.
public struct MonthState: Codable, Equatable, Sendable {
    public var goals: [Goal]
    public var days: [String: Day]          // "yyyy-MM-dd" → Day
    public var restStrategy: RestStrategy
    public var events: [Event]
    public var health: Health
    public var streak: Int                  // Current consecutive systemRan days

    // Derived: study-days-axis values (computed once, cached here for determinism)
    // These are NOT set by callers — set to 0; the kernel fills them in.
    public var backboneStudyDays: Int
    public var studyDaysTotal: Int
    public var studyDaysRemaining: Int
    public var studyDaysElapsed: Int

    public init(
        goals: [Goal],
        days: [String: Day] = [:],
        restStrategy: RestStrategy,
        events: [Event] = [],
        health: Health = Health(),
        streak: Int = 0
    ) {
        self.goals = goals
        self.days = days
        self.restStrategy = restStrategy
        self.events = events
        self.health = health
        self.streak = streak
        self.backboneStudyDays = 0
        self.studyDaysTotal = 0
        self.studyDaysRemaining = 0
        self.studyDaysElapsed = 0
    }
}

// MARK: - DayPlan (output)

public struct RestCard: Codable, Equatable, Sendable {
    public var message: String
    public var streak: Int

    public init(message: String, streak: Int) {
        self.message = message
        self.streak = streak
    }
}

public enum DayPlan: Equatable, Sendable {
    case rest(card: RestCard)
    case study(items: [PlannedItem], reasoning: String, healthNotes: [String])
}

// MARK: - Codable helpers for DayPlan (so it can be serialized for tests)

extension DayPlan: Codable {
    enum CodingKeys: String, CodingKey {
        case type, card, items, reasoning, healthNotes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "rest":
            let card = try container.decode(RestCard.self, forKey: .card)
            self = .rest(card: card)
        case "study":
            let items = try container.decode([PlannedItem].self, forKey: .items)
            let reasoning = try container.decode(String.self, forKey: .reasoning)
            let healthNotes = try container.decodeIfPresent([String].self, forKey: .healthNotes) ?? []
            self = .study(items: items, reasoning: reasoning, healthNotes: healthNotes)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown DayPlan type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .rest(let card):
            try container.encode("rest", forKey: .type)
            try container.encode(card, forKey: .card)
        case .study(let items, let reasoning, let healthNotes):
            try container.encode("study", forKey: .type)
            try container.encode(items, forKey: .items)
            try container.encode(reasoning, forKey: .reasoning)
            try container.encode(healthNotes, forKey: .healthNotes)
        }
    }
}

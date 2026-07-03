import Foundation

/// §1.5 Centralized constants — the only place where tuning parameters live.
public enum KernelConfig {
    /// Urgency multiplier constant: higher = more pressure on near-deadline goals.
    public static let urgencyK: Double = 7

    /// Importance floor: when progress passes the threshold, importance decays
    /// smoothly from 1.0 → IMPORTANCE_FLOOR (never to zero).
    public static let importanceFloor: Double = 0.1

    /// Budget per energy level (minutes).
    public static let budget: [Energy: Int] = [
        .high: 150,
        .normal: 100,
        .low: 45,
    ]

    /// Minimum chunk size in minutes — smaller items are omitted.
    public static let minChunk: Int = 15

    /// Maximum chunk size in minutes — no single goal gets more than this per day.
    public static let maxChunk: Int = 90

    /// Fixed minutes allocated to each habit goal every study day.
    public static let habitChunk: Int = 15

    /// Minutes for exam review the day before an exam.
    public static let reviewChunk: Int = 20

    /// Number of consecutive study days with MAX_CHUNK to trigger diversity guard.
    public static let diversityThreshold: Int = 3

    /// Pressure ratio under which two subjects are considered "close enough" for diversity.
    public static let diversityPressureRatio: Double = 0.20
}

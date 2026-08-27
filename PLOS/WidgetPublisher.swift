import Foundation
import WidgetKit

// MARK: - §P.5: App-side widget data publishing
//
// Counterpart of PLOSWidget/PLOSWidget.swift — the app writes a small summary
// into the shared App Group defaults and asks WidgetKit to refresh. Called from
// AppViewModel wherever today's plan or streak changes.

extension AppViewModel {
    /// Write today's plan summary to shared UserDefaults for widget consumption.
    func updateWidgetData() {
        guard let defaults = UserDefaults(suiteName: "group.com.plos.app") else { return }
        defaults.set(todayStreak, forKey: "widget_streak")
        defaults.set(!todayPlannedItems.isEmpty, forKey: "widget_has_plan")
        if todayPlannedItems.count >= 1 {
            let i1 = todayPlannedItems[0]
            defaults.set("\(i1.label) · \(i1.minutes) min", forKey: "widget_item1")
        } else {
            defaults.removeObject(forKey: "widget_item1")
        }
        if todayPlannedItems.count >= 2 {
            let i2 = todayPlannedItems[1]
            defaults.set("\(i2.label) · \(i2.minutes) min", forKey: "widget_item2")
        } else {
            defaults.removeObject(forKey: "widget_item2")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

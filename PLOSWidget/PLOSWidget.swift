import SwiftUI
import WidgetKit

// MARK: - §P.5: Lock/Home Screen Widget (today's first 2 items + streak)
//
// Data flows one way: the app writes a tiny summary into the shared App Group
// UserDefaults (see PLOS/WidgetPublisher.swift) and reloads the timeline; the
// widget only reads. Colors come from the shared DesignSystem.swift tokens —
// this file is compiled together with it in the widget target.

struct PLOSWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let item1: String?
    let item2: String?
    let hasPlan: Bool
}

struct PLOSWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PLOSWidgetEntry {
        PLOSWidgetEntry(date: Date(), streak: 12, item1: "线代 · 30 min", item2: "英语 · 15 min", hasPlan: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (PLOSWidgetEntry) -> Void) {
        let entry = PLOSWidgetEntry(date: Date(), streak: 12,
                                     item1: "线代 · 30 min", item2: "英语 · 15 min", hasPlan: true)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PLOSWidgetEntry>) -> Void) {
        // Read from shared UserDefaults (app writes there)
        let defaults = UserDefaults(suiteName: "group.com.plos.app")
        let streak = defaults?.integer(forKey: "widget_streak") ?? 0
        let item1 = defaults?.string(forKey: "widget_item1")
        let item2 = defaults?.string(forKey: "widget_item2")
        let hasPlan = defaults?.bool(forKey: "widget_has_plan") ?? false

        let entry = PLOSWidgetEntry(date: Date(), streak: streak,
                                     item1: item1, item2: item2, hasPlan: hasPlan)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

struct PLOSWidgetEntryView: View {
    var entry: PLOSWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 13))
                    .foregroundColor(PLOS.Palette.g500)
                Text("PLOS")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(PLOS.Palette.g700)
                Spacer()
                if entry.streak > 0 {
                    Text("\(entry.streak)天")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(PLOS.Palette.g500)
                }
            }

            if entry.hasPlan {
                VStack(alignment: .leading, spacing: 4) {
                    if let i1 = entry.item1 {
                        Text(i1)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(PLOS.Palette.ink)
                            .lineLimit(1)
                    }
                    if let i2 = entry.item2 {
                        Text(i2)
                            .font(.system(size: 11))
                            .foregroundColor(PLOS.Palette.ink2)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("打开生成今日计划")
                    .font(.system(size: 12))
                    .foregroundColor(PLOS.Palette.ink3)
            }
        }
        .padding(14)
        .containerBackground(PLOS.Palette.paper, for: .widget)
    }
}

struct PLOSWidget: Widget {
    let kind: String = "PLOSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PLOSWidgetProvider()) { entry in
            PLOSWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("PLOS 今日计划")
        .description("显示今日前2项任务和连续运行天数")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget bundle entry point

@main
struct PLOSWidgetBundle: WidgetBundle {
    var body: some Widget {
        PLOSWidget()
    }
}

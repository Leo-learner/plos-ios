import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PLOSKernel

// MARK: - §P.3: JSON Export / Import

struct DataSafetyView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportData: Data?
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section("导出") {
                Button(action: prepareExport) {
                    Label("导出全部数据为 JSON", systemImage: "square.and.arrow.up")
                }
            }
            Section("导入") {
                Button(action: { showImporter = true }) {
                    Label("从 JSON 导入数据", systemImage: "square.and.arrow.down")
                }
            }
            if let msg = statusMessage {
                Section("状态") {
                    Text(msg).font(.system(size: 13)).foregroundColor(PLOS.Palette.ink2)
                }
            }
            Section("iCloud 同步") {
                HStack {
                    Text("iCloud 同步")
                    Spacer()
                    Text("SwiftData + CloudKit 需 Apple Developer 账户配置，当前版本可延后。数据已在本地持久化。")
                        .font(.system(size: 12))
                        .foregroundColor(PLOS.Palette.ink3)
                }
            }
        }
        .navigationTitle("数据安全")
        .fileExporter(isPresented: $showExporter, document: JSONDataDocument(data: exportData ?? Data()),
                      contentType: .json, defaultFilename: "plos-backup.json") { result in
            if case .success = result { statusMessage = "导出成功" }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                importFrom(url: url)
            }
        }
    }

    private func prepareExport() {
        guard let month = vm.activeMonth else { return }
        let payload: [String: Any] = [
            "version": 1,
            "year": month.year,
            "month": month.month,
            "cycleStudy": month.cycleStudy,
            "cycleRest": month.cycleRest,
            "flexRestTotal": month.flexRestTotal,
            "flexUsed": month.flexUsed,
            "goals": month.goals.map { goal in
                [
                    "uid": goal.uid, "subject": goal.subject, "type": goal.rawType,
                    "target": goal.targetDesc, "unit": goal.unit,
                    "total": goal.total, "done": goal.done,
                    "start": RestSchedule.dateString(goal.startDate),
                    "deadline": RestSchedule.dateString(goal.deadlineDate),
                    "importance": goal.importance,
                    "successThreshold": goal.successThreshold,
                    "historyDelay": goal.historyDelay,
                ] as [String: Any]
            },
            "days": month.days.map { day in
                [
                    "date": day.date, "dayType": day.rawDayType,
                    "energy": day.rawEnergy ?? "",
                    "systemRan": day.systemRan,
                    "planned": day.plannedItems.map { p in
                        ["goalId": p.goalId, "minutes": p.minutes, "label": p.label,
                         "plannedUnits": p.plannedUnits, "order": p.order] as [String: Any]
                    },
                    "reported": day.reportItems.map { r in
                        ["goalId": r.goalId, "completionPct": r.completionPct] as [String: Any]
                    },
                    "note": day.note ?? "",
                    "reasoning": day.reasoning ?? "",
                ] as [String: Any]
            },
            "events": month.events.map { ["type": $0.eventType, "subject": $0.subject, "date": $0.date] },
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            exportData = data
            showExporter = true
        }
    }

    private func importFrom(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let year = json["year"] as? Int,
              let monthIdx = json["month"] as? Int,
              let goalsArr = json["goals"] as? [[String: Any]]
        else {
            statusMessage = "导入失败：JSON 格式不正确"
            return
        }

        // Overwrite current month
        let month = vm.fetchOrCreateMonth(
            year: year, month: monthIdx,
            cycleStudy: json["cycleStudy"] as? Int ?? 5,
            cycleRest: json["cycleRest"] as? Int ?? 2,
            flexRestTotal: json["flexRestTotal"] as? Int ?? 2
        )
        month.flexUsed = json["flexUsed"] as? Int ?? 0

        // Clear existing goals/days/events
        month.goals.forEach { vm.modelContext?.delete($0) }
        month.days.forEach { vm.modelContext?.delete($0) }
        month.events.forEach { vm.modelContext?.delete($0) }
        month.goals = []; month.days = []; month.events = []

        for g in goalsArr {
            let goal = GoalEntity(
                uid: g["uid"] as? String ?? UUID().uuidString,
                subject: g["subject"] as? String ?? "",
                rawType: g["type"] as? String ?? "deadline",
                targetDesc: g["target"] as? String ?? "",
                unit: g["unit"] as? String ?? "",
                total: g["total"] as? Double ?? 1,
                done: g["done"] as? Double ?? 0,
                startDate: RestSchedule.parseDate(g["start"] as? String ?? "2026-01-01") ?? Date(),
                deadlineDate: RestSchedule.parseDate(g["deadline"] as? String ?? "2026-01-31") ?? Date(),
                importance: g["importance"] as? Double ?? 1.0,
                successThreshold: g["successThreshold"] as? Double ?? 0.8,
                historyDelay: g["historyDelay"] as? Int ?? 0
            )
            goal.month = month
            vm.modelContext?.insert(goal)
            month.goals.append(goal)
        }

        if let daysArr = json["days"] as? [[String: Any]] {
            for d in daysArr {
                let day = DayEntity(date: d["date"] as? String ?? "",
                                    rawDayType: d["dayType"] as? String ?? "study",
                                    rawEnergy: d["energy"] as? String,
                                    systemRan: d["systemRan"] as? Bool ?? false,
                                    note: d["note"] as? String,
                                    reasoning: (d["reasoning"] as? String).flatMap { $0.isEmpty ? nil : $0 })
                day.month = month
                vm.modelContext?.insert(day)
                if let plannedArr = d["planned"] as? [[String: Any]] {
                    for p in plannedArr {
                        let pi = PlannedItemEntity(goalId: p["goalId"] as? String ?? "",
                                                   minutes: p["minutes"] as? Int ?? 0,
                                                   label: p["label"] as? String ?? "",
                                                   plannedUnits: p["plannedUnits"] as? Double ?? 0,
                                                   order: p["order"] as? Int ?? 0)
                        pi.day = day; vm.modelContext?.insert(pi); day.plannedItems.append(pi)
                    }
                }
                if let repArr = d["reported"] as? [[String: Any]] {
                    for r in repArr {
                        let ri = ReportItemEntity(goalId: r["goalId"] as? String ?? "",
                                                  completionPct: r["completionPct"] as? Int ?? 0)
                        ri.day = day; vm.modelContext?.insert(ri); day.reportItems.append(ri)
                    }
                }
                month.days.append(day)
            }
        }

        if let eventsArr = json["events"] as? [[String: Any]] {
            for e in eventsArr {
                let ev = EventEntity(eventType: e["type"] as? String ?? "exam",
                                     subject: e["subject"] as? String ?? "",
                                     date: e["date"] as? String ?? "")
                ev.month = month; vm.modelContext?.insert(ev); month.events.append(ev)
            }
        }

        try? vm.modelContext?.save()
        vm.activeMonth = month
        statusMessage = "导入成功：\(goalsArr.count) 个目标"
    }
}

// MARK: - FileDocument for export

struct JSONDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: data)
    }
}

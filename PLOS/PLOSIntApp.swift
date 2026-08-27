import SwiftUI
import SwiftData
import PLOSKernel

// MARK: - App Entry Point (Phase INT — SwiftData + Kernel)

// @main is dropped under SwiftPM (PLOSAppCheck test/typecheck builds) so the synthesized
// main symbol cannot collide with the XCTest runner; the real Xcode app target keeps it.
#if !SWIFT_PACKAGE
@main
#endif
struct PLOSIntApp: App {
    @State private var vm = AppViewModel(today: LaunchOptions.today)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vm)
                .onAppear {
                    // UI tests drive their own notification assertions; the permission
                    // prompt would otherwise block every automated run.
                    if !LaunchOptions.skipNotificationPrompt {
                        NotificationManager.shared.requestPermission()
                    }
                }
        }
        .modelContainer(for: [MonthEntity.self, GoalEntity.self, DayEntity.self,
                              PlannedItemEntity.self, ReportItemEntity.self, EventEntity.self])
    }
}

// MARK: - Launch Options (UI-test hooks)

/// Launch arguments that make automated runs deterministic. Absent in normal use,
/// where `today` is the real calendar day and the store persists across launches.
enum LaunchOptions {
    /// `-plosToday 2026-08-26` pins "today" so tests can target a study day
    /// regardless of when they run. nil means "follow the real clock".
    static var today: Date? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-plosToday"), i + 1 < args.count else { return nil }
        return RestSchedule.parseDate(args[i + 1])
    }

    /// `-plosResetStore` wipes persisted data at launch so each test starts clean.
    static var resetStore: Bool {
        ProcessInfo.processInfo.arguments.contains("-plosResetStore")
    }

    static var skipNotificationPrompt: Bool {
        ProcessInfo.processInfo.arguments.contains("-plosSkipNotificationPrompt")
    }
}

// MARK: - Root Content View

struct ContentView: View {
    @Environment(AppViewModel.self) private var vm
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var vm = vm
        TabView(selection: $vm.selectedTab) {
            NavigationStack {
                PlanIntView()
            }
            .tabItem { Label("今天", systemImage: "sun.max") }
            .tag(0)

            NavigationStack {
                MonthSetupIntView()
            }
            .tabItem { Label("月计划", systemImage: "calendar") }
            .tag(1)

            NavigationStack {
                ProgressDashboardView()
            }
            .tabItem { Label("进度", systemImage: "chart.bar") }
            .tag(2)
        }
        .onAppear {
            vm.configure(modelContext: ctx)
            if LaunchOptions.resetStore { vm.wipeAllData() }
            vm.bootstrapMonth()
            consumePendingNotification()
        }
        .onChange(of: scenePhase) { _, phase in
            // Crossing midnight in the background: re-capture "today" on return.
            if phase == .active { vm.advanceToTodayIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .plosNotificationTap)) { note in
            guard let category = note.userInfo?["category"] as? String else { return }
            route(category: category)
        }
    }

    /// Cold start from a notification tap: the delegate fires before this view subscribes,
    /// so the category is parked on NotificationManager and consumed here.
    private func consumePendingNotification() {
        if let category = NotificationManager.shared.pendingCategory {
            NotificationManager.shared.pendingCategory = nil
            route(category: category)
        }
    }

    private func route(category: String) {
        vm.selectedTab = 0
        if category == "EVENING" {
            vm.showEveningReport = true
        }
    }
}

// MARK: - Plan Int View (today's main screen)

struct PlanIntView: View {
    @Environment(AppViewModel.self) private var vm

    private var hasGoals: Bool { !(vm.activeMonth?.goals.isEmpty ?? true) }

    var body: some View {
        @Bindable var vm = vm
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    DayTypeChip(dayType: vm.todayDayType == .study
                                ? .study(energy: vm.todayEnergy == .high ? .high : vm.todayEnergy == .low ? .low : .normal)
                                : vm.todayDayType == .rhythmRest ? .rhythmRest : .flexRest)
                    Spacer()
                    StreakBadge(streak: vm.todayStreak)
                }

                if !hasGoals {
                    emptyStateBody
                } else if case .rhythmRest = vm.todayDayType {
                    restDayBody
                } else if case .flexRest = vm.todayDayType {
                    flexRestDayBody
                } else {
                    studyDayBody
                }

            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            // Clears the floating tab bar so the bottom CTA is never hidden under it.
            .padding(.bottom, 40)
        }
        .background(PLOS.Palette.paper)
        .navigationTitle("今天")
        .navigationDestination(isPresented: $vm.showEveningReport) {
            EveningReportIntView()
        }
        .onAppear { vm.loadTodayState() }
    }

    // MARK: - Empty State (first run: no goals yet)

    var emptyStateBody: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 24)
            Image(systemName: "leaf.fill").font(.system(size: 46)).foregroundColor(PLOS.Palette.g400)
            Text("先建一个月目标")
                .font(.system(size: PLOS.FontScale.title, weight: .bold)).foregroundColor(PLOS.Palette.ink)
            Text("在「月计划」里添加目标、定好休息节奏，\n系统每天早上就能为你排出当天的计划。")
                .font(.system(size: PLOS.FontScale.body)).foregroundColor(PLOS.Palette.ink2)
                .multilineTextAlignment(.center)
            Button(action: { vm.selectedTab = 1 }) {
                Text("去建月目标").font(.system(size: PLOS.FontScale.button, weight: .bold))
                    .foregroundColor(.white).frame(maxWidth: .infinity)
                    .frame(height: PLOS.Size.primaryButtonHeight)
                    .background(RoundedRectangle(cornerRadius: PLOS.Radius.pill).fill(PLOS.Palette.g500))
            }
            Spacer()
        }
    }

    // MARK: - Study Day

    @State private var selectedEnergy: Energy = .normal

    var studyDayBody: some View {
        VStack(spacing: 16) {
            // Energy selector if no plan yet
            if vm.todayPlannedItems.isEmpty {
                VStack(spacing: 11) {
                let energies: [PLOSKernel.Energy] = [.high, .normal, .low]
                ForEach(energies, id: \.self) { e in
                        Button(action: {
                            selectedEnergy = e
                            vm.generatePlan(energy: e)
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 13)
                                        .fill(e == .high ? PLOS.Palette.amberBg :
                                                e == .low ? PLOS.Palette.periBg : PLOS.Palette.g50)
                                        .frame(width: 42, height: 42)
                                    Image(systemName: e == .high ? "bolt.fill" :
                                            e == .low ? "moon.zzz.fill" : "sun.max.fill")
                                        .font(.system(size: 17))
                                        .foregroundColor(e == .high ? PLOS.Palette.amber :
                                                            e == .low ? PLOS.Palette.peri : PLOS.Palette.g400)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e == .high ? "高能" : e == .low ? "低谷" : "普通")
                                        .font(.system(size: 15.5, weight: .bold))
                                        .foregroundColor(PLOS.Palette.ink)
                                    Text(e == .high ? "状态很好，可以多推进一点" :
                                            e == .low ? "先别为难自己，做最要紧的" : "按基准来，稳稳当当")
                                        .font(.system(size: 12))
                                        .foregroundColor(PLOS.Palette.ink3)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                                .fill(PLOS.Palette.surface)
                                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                                    .stroke(PLOS.Palette.hairline, lineWidth: 1.5)))
                        }
                    }
                }
            } else {
                // Plan display
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(RestSchedule.dateString(vm.today)) · 今日计划")
                        .font(.system(size: PLOS.FontScale.footnote)).foregroundColor(PLOS.Palette.ink3)
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("\(vm.todayPlannedItems.reduce(0) { $0 + $1.minutes })")
                            .font(.system(size: PLOS.FontScale.statLarge, weight: .bold, design: .rounded))
                            .foregroundColor(PLOS.Palette.ink)
                        Text("分钟 · \(vm.todayPlannedItems.count) 件事")
                            .font(.system(size: 14)).foregroundColor(PLOS.Palette.ink2)
                    }
                }

                ForEach(Array(vm.todayPlannedItems.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 13) {
                        Text("\(idx + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(PLOS.Palette.ink3)
                            .frame(width: 27, height: 27)
                            .background(RoundedRectangle(cornerRadius: 9).fill(PLOS.Palette.surface2))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.label)
                                .font(.system(size: PLOS.FontScale.subject, weight: .bold))
                                .foregroundColor(PLOS.Palette.ink)
                            Text("\(item.minutes) min")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(PLOS.Palette.g700)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1)))
                }

                if !vm.todayReasoning.isEmpty {
                    ReasoningCard(text: vm.todayReasoning)
                }

                ForEach(vm.todayHealthNotes, id: \.self) { note in
                    Text(note).font(.system(size: 12)).foregroundColor(PLOS.Palette.amberInk)
                        .padding(10).background(RoundedRectangle(cornerRadius: 8).fill(PLOS.Palette.warnBg))
                }

                // Evening report entry — the plan screen's bottom CTA (§2.3 设计稿：底部去汇报)
                Button(action: { vm.showEveningReport = true }) {
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 16))
                        Text("去汇报今天").font(.system(size: PLOS.FontScale.button, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: PLOS.Size.primaryButtonHeight)
                    .background(RoundedRectangle(cornerRadius: PLOS.Radius.pill).fill(PLOS.Palette.g500))
                }

                // Flex rest button
                Button(action: { vm.useFlexRest() }) {
                    HStack(spacing: 9) {
                        Image(systemName: "moon.zzz.fill").font(.system(size: 15))
                        Text("用一个灵活休息日").font(.system(size: 14.5, weight: .semibold))
                    }
                    .foregroundColor(PLOS.Palette.ink2)
                    .frame(maxWidth: .infinity).frame(height: PLOS.Size.secondaryButtonHeight)
                    .background(RoundedRectangle(cornerRadius: PLOS.Radius.pill).fill(PLOS.Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.pill).stroke(PLOS.Palette.hairline, lineWidth: 1.5)))
                }

                // Re-pick energy: plans are free to regenerate — only tomorrow is a new day.
                Button("状态变了？重新选能量") { vm.resetTodayPlan() }
                    .font(.system(size: 13)).foregroundColor(PLOS.Palette.ink3)
            }
        }
    }

    // MARK: - Rest Day

    var restDayBody: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)
            Image(systemName: "cup.and.saucer.fill").font(.system(size: 50)).foregroundColor(PLOS.Palette.clay)
            Text("今天是计划内的休息日")
                .font(.system(size: PLOS.FontScale.title, weight: .bold)).foregroundColor(PLOS.Palette.clayInk)
            Text(vm.todayRestMessage)
                .font(.system(size: PLOS.FontScale.body)).foregroundColor(PLOS.Palette.clayText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .onAppear { vm.loadRestDay() }
    }

    var flexRestDayBody: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)
            Image(systemName: "moon.stars.fill").font(.system(size: 50)).foregroundColor(PLOS.Palette.slate)
            Text("今天先歇一下")
                .font(.system(size: PLOS.FontScale.title, weight: .bold)).foregroundColor(PLOS.Palette.slateInk)
            Text(vm.todayRestMessage)
                .font(.system(size: PLOS.FontScale.body)).foregroundColor(PLOS.Palette.slateText)
                .multilineTextAlignment(.center)
            Button("点错了？撤销") { vm.undoFlexRest() }
                .font(.system(size: 13)).foregroundColor(PLOS.Palette.slateMuted)
            Spacer()
        }
    }
}

// MARK: - Evening Report Int View

struct EveningReportIntView: View {
    @Environment(AppViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @State private var sliders: [String: Double] = [:]  // goalId → pct
    @State private var note = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("今天做得怎么样？").font(.system(size: 22, weight: .bold)).foregroundColor(PLOS.Palette.ink)
                Text("拖动滑块就好。全部 0% 也没关系——系统仍在运行。")
                    .font(.system(size: 13)).foregroundColor(PLOS.Palette.ink2)

                if vm.todayPlannedItems.isEmpty {
                    Text("今天没有计划项。先在「今天」页生成计划。")
                        .font(.system(size: 14)).foregroundColor(PLOS.Palette.ink3)
                        .padding(.vertical, 30)
                }

                ForEach(vm.todayPlannedItems, id: \.order) { item in
                    VStack(spacing: 13) {
                        HStack {
                            Text(item.label).font(.system(size: PLOS.FontScale.subject, weight: .bold))
                                .foregroundColor(PLOS.Palette.ink)
                            Spacer()
                            Text("\(Int(sliders[item.goalId] ?? 0))%")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(PLOS.Palette.g700)
                        }
                        Slider(value: Binding(
                            get: { sliders[item.goalId] ?? 0 },
                            set: { sliders[item.goalId] = $0 }
                        ), in: 0...100, step: 1)
                        .tint(PLOS.Palette.g500)
                    }
                    .padding(15)
                    .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1)))
                }

                // Optional one-line personal memo — display only, never affects scheduling (§1.9).
                TextField("一句话备注（可选，不影响明天的计划）", text: $note)
                    .font(.system(size: 14))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1)))

                if !vm.todayPlannedItems.isEmpty {
                    Button(action: saveReport) {
                        Text("完成汇报 · 今天结束").font(.system(size: PLOS.FontScale.button, weight: .bold))
                            .foregroundColor(.white).frame(maxWidth: .infinity)
                            .frame(height: PLOS.Size.primaryButtonHeight)
                            .background(RoundedRectangle(cornerRadius: PLOS.Radius.pill).fill(PLOS.Palette.g500))
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 18)
        }
        .background(PLOS.Palette.paper)
        .navigationTitle("晚间汇报")
        .onAppear(perform: restoreExistingReport)
    }

    /// Re-opening the report screen shows what was already saved instead of zeros,
    /// so a re-save edits today's report rather than silently wiping it.
    private func restoreExistingReport() {
        guard sliders.isEmpty, let day = vm.todayDayEntity() else { return }
        for report in day.reportItems {
            sliders[report.goalId] = Double(report.completionPct)
        }
        if note.isEmpty { note = day.note ?? "" }
    }

    private func saveReport() {
        // Unmoved sliders count as 0% — every planned item gets a report record.
        var completions: [String: Int] = [:]
        for item in vm.todayPlannedItems {
            completions[item.goalId] = Int(sliders[item.goalId] ?? 0)
        }
        vm.reportCompletions = completions
        vm.reportNotes = note.isEmpty ? [:] : ["day": note]
        vm.saveEveningReport()
        dismiss()
    }
}


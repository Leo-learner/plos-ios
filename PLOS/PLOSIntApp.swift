import SwiftUI
import SwiftData
import PLOSKernel

// MARK: - App Entry Point (Phase INT — SwiftData + Kernel)

@main
struct PLOSIntApp: App {
    @State private var vm = AppViewModel()
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vm)
                .onAppear {
                    NotificationManager.shared.requestPermission()
                }
        }
        .modelContainer(for: [MonthEntity.self, GoalEntity.self, DayEntity.self,
                              PlannedItemEntity.self, ReportItemEntity.self, EventEntity.self])
    }
}

// MARK: - Root Content View

struct ContentView: View {
    @Environment(AppViewModel.self) private var vm
    @Environment(\.modelContext) private var ctx

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
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
                ProgressStubView()
            }
            .tabItem { Label("进度", systemImage: "chart.bar") }
            .tag(2)
        }
        .onAppear {
            vm.configure(modelContext: ctx)
            // Auto-create or load this month
            let (y, m, _) = RestSchedule.dateComponents(vm.today)
            _ = vm.fetchOrCreateMonth(year: y, month: m, cycleStudy: 5, cycleRest: 2, flexRestTotal: 2)
            vm.buildSkeleton()
            vm.loadTodayState()
        }
    }
}

// MARK: - Plan Int View (today's main screen)

struct PlanIntView: View {
    @Environment(AppViewModel.self) private var vm

    var body: some View {
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

                // Rest day
                if case .rhythmRest = vm.todayDayType {
                    restDayBody
                } else if case .flexRest = vm.todayDayType {
                    flexRestDayBody
                } else {
                    studyDayBody
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(PLOS.Palette.paper)
        .navigationTitle("今天")
        .onAppear { vm.loadTodayState() }
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
                    Text(note).font(.system(size: 12)).foregroundColor(Color(hex: 0x8A6420))
                        .padding(10).background(RoundedRectangle(cornerRadius: 8).fill(PLOS.Palette.warnBg))
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
            }
        }
    }

    // MARK: - Rest Day

    var restDayBody: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)
            Image(systemName: "cup.and.saucer.fill").font(.system(size: 50)).foregroundColor(PLOS.Palette.clay)
            Text("今天是计划内的休息日")
                .font(.system(size: PLOS.FontScale.title, weight: .bold)).foregroundColor(Color(hex: 0x5A4A2E))
            Text(vm.todayRestMessage)
                .font(.system(size: PLOS.FontScale.body)).foregroundColor(Color(hex: 0x8A7550))
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
                .font(.system(size: PLOS.FontScale.title, weight: .bold)).foregroundColor(Color(hex: 0x37545C))
            Text(vm.todayRestMessage)
                .font(.system(size: PLOS.FontScale.body)).foregroundColor(Color(hex: 0x5C7C84))
                .multilineTextAlignment(.center)
            Button("点错了？撤销") { vm.undoFlexRest() }
                .font(.system(size: 13)).foregroundColor(Color(hex: 0x6F8F97))
            Spacer()
        }
    }
}

// MARK: - Evening Report Int View

struct EveningReportIntView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var sliders: [String: Double] = [:]  // goalId → pct

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("今天做得怎么样？").font(.system(size: 22, weight: .bold)).foregroundColor(PLOS.Palette.ink)
                Text("拖动滑块就好，不用打字。").font(.system(size: 13)).foregroundColor(PLOS.Palette.ink2)

                ForEach(vm.todayPlannedItems, id: \.order) { item in
                    VStack(spacing: 13) {
                        HStack {
                            Text(item.label).font(.system(size: PLOS.FontScale.subject, weight: .bold))
                                .foregroundColor(PLOS.Palette.ink)
                            Spacer()
                            Text("\(item.minutes) min").font(.system(size: 13)).foregroundColor(PLOS.Palette.ink3)
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

                Button(action: saveReport) {
                    Text("保存 · 今天结束").font(.system(size: PLOS.FontScale.button, weight: .bold))
                        .foregroundColor(.white).frame(maxWidth: .infinity)
                        .frame(height: PLOS.Size.primaryButtonHeight)
                        .background(RoundedRectangle(cornerRadius: PLOS.Radius.pill).fill(PLOS.Palette.g500))
                }
            }
            .padding(.horizontal, 20).padding(.top, 18)
        }
        .background(PLOS.Palette.paper)
        .navigationTitle("晚间汇报")
    }

    private func saveReport() {
        vm.reportCompletions = sliders.mapValues { Int($0) }
        vm.saveEveningReport()
        // Reset sliders after save
        sliders = [:]
    }
}

// MARK: - Progress Stub

struct ProgressStubView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill").font(.system(size: 40)).foregroundColor(PLOS.Palette.g400)
            Text("进度面板").font(.system(size: 20, weight: .bold)).foregroundColor(PLOS.Palette.ink)
            Text("Phase P 实现：各科完成率环/条、达标线标记、负荷曲线、streak 日历热力")
                .font(.system(size: 14)).foregroundColor(PLOS.Palette.ink2).multilineTextAlignment(.center)
        }
        .padding()
        .background(PLOS.Palette.paper)
        .navigationTitle("进度")
    }
}

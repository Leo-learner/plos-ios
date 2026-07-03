import SwiftUI
import SwiftData
import PLOSKernel

// MARK: - MonthSetupView (integrated: SwiftData + kernel)

struct MonthSetupIntView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var studyDays = 5
    @State private var restDays = 2
    @State private var flexTotal = 2
    @State private var showAddGoal = false
    @State private var goalToDelete: GoalEntity?

    private var goals: [GoalEntity] { vm.activeMonth?.goals ?? [] }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // --- goals list ---
                VStack(alignment: .leading, spacing: 11) {
                    Text("目标").font(.system(size: 13, weight: .bold)).foregroundColor(PLOS.Palette.ink2)
                    + Text(" · \(goals.count)").foregroundColor(PLOS.Palette.ink3)
                    ForEach(goals, id: \.persistentModelID) { g in
                        IntGoalCard(goal: g, onDelete: { goalToDelete = g })
                    }
                    if goals.isEmpty {
                        Text("还没有目标").font(.system(size: 13)).foregroundColor(PLOS.Palette.ink3)
                    }
                    Button { showAddGoal = true } label: {
                        Label("添加目标", systemImage: "plus").font(.system(size: 14, weight: .semibold))
                            .foregroundColor(PLOS.Palette.g600).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.g50))
                    }
                }

                // --- rest strategy ---
                VStack(alignment: .leading, spacing: 12) {
                    Text("休息节奏").font(.system(size: 13, weight: .bold)).foregroundColor(PLOS.Palette.ink2)
                    HStack(spacing: 12) {
                        IntStepper(label: "学习", value: $studyDays, range: 1...7, color: PLOS.Palette.g500)
                        IntStepper(label: "休息", value: $restDays, range: 1...5, color: PLOS.Palette.clay)
                        IntStepper(label: "灵活额度", value: $flexTotal, range: 0...5, color: PLOS.Palette.slate)
                    }
                }

                // --- preview ---
                IntPreviewCard(backbone: vm.backboneStudyDays, guaranteed: vm.studyDaysTotal,
                               study: studyDays, rest: restDays)

                // --- confirm ---
                Button(action: confirmMonth) {
                    Text("确认并生成本月骨架").font(.system(size: PLOS.FontScale.button, weight: .bold))
                        .foregroundColor(.white).frame(maxWidth: .infinity)
                        .frame(height: PLOS.Size.primaryButtonHeight)
                        .background(RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                            .fill(goals.isEmpty ? PLOS.Palette.g200 : PLOS.Palette.g500))
                }.disabled(goals.isEmpty)

                Text("单日基准将对齐保底学习日完成 100%").font(.system(size: 12))
                    .foregroundColor(PLOS.Palette.ink3).padding(.bottom, 6)
            }
            .padding(.horizontal, 22).padding(.top, 18)
        }
        .background(PLOS.Palette.paper)
        .sheet(isPresented: $showAddGoal) {
            IntAddGoalSheet { subject, type, target, unit, total, deadline, imp, threshold in
                vm.addGoal(GoalEntity(uid: UUID().uuidString.prefix(8).lowercased(),
                                       subject: subject, rawType: type,
                                       targetDesc: target, unit: unit, total: total,
                                       startDate: Date(), deadlineDate: deadline,
                                       importance: imp, successThreshold: threshold))
            }
        }
        .alert("删除目标", isPresented: .init(get: { goalToDelete != nil },
                set: { if !$0 { goalToDelete = nil } })) {
            Button("取消", role: .cancel) { goalToDelete = nil }
            Button("删除", role: .destructive) { if let g = goalToDelete { vm.deleteGoal(g); goalToDelete = nil } }
        }
    }

    private func confirmMonth() {
        let (y, m, _) = RestSchedule.dateComponents(vm.today)
        _ = vm.fetchOrCreateMonth(year: y, month: m, cycleStudy: studyDays,
                                   cycleRest: restDays, flexRestTotal: flexTotal)
        vm.buildSkeleton()
    }
}

// --- shared subviews ---

struct IntGoalCard: View {
    let goal: GoalEntity
    let onDelete: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(goal.subject).font(.system(size: 16, weight: .bold)).foregroundColor(PLOS.Palette.ink)
                    Text(goal.rawType == "habit" ? "每天做" : goal.rawType == "milestone" ? "节点完成" : "按期完成")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(PLOS.Palette.g700)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: PLOS.Radius.pill).fill(PLOS.Palette.g50))
                }
                HStack(spacing: 6) {
                    Text(goal.targetDesc).font(.system(size: 11.5)).foregroundColor(PLOS.Palette.ink2)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 7).fill(PLOS.Palette.surface2))
                    Text("截止 \(goal.deadlineDate.formatted(date: .numeric, time: .omitted))")
                        .font(.system(size: 11.5)).foregroundColor(PLOS.Palette.ink2)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 7).fill(PLOS.Palette.surface2))
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundColor(PLOS.Palette.ink3.opacity(0.5))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1)))
        .shadow(color: Color(hex: 0x263A2C).opacity(0.06), radius: 6, y: 3)
    }
}

struct IntStepper: View {
    let label: String; @Binding var value: Int; let range: ClosedRange<Int>; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(PLOS.Palette.ink3)
            HStack(spacing: 6) {
                Button { if value > range.lowerBound { value -= 1 } } label: {
                    Image(systemName: "minus").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32)
                }
                Text("\(value)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(color)
                Button { if value < range.upperBound { value += 1 } } label: {
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32)
                }
            }
        }
        .padding(.vertical, 10).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: PLOS.Radius.md).fill(PLOS.Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.md).stroke(PLOS.Palette.hairline, lineWidth: 1)))
    }
}

struct IntPreviewCard: View {
    let backbone: Int; let guaranteed: Int; let study: Int; let rest: Int
    var body: some View {
        VStack(spacing: 14) {
            HStack { Image(systemName: "leaf.fill").font(.system(size: 14)).foregroundColor(PLOS.Palette.g600)
                Text("保底学习日预览").font(.system(size: 13, weight: .bold)).foregroundColor(PLOS.Palette.g700); Spacer() }
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(guaranteed)").font(.system(size: PLOS.FontScale.statHero, weight: .bold, design: .rounded))
                        .foregroundColor(PLOS.Palette.g700)
                    Text("保底学习日").font(.system(size: 12)).foregroundColor(PLOS.Palette.ink3)
                }
                VStack(spacing: 4) {
                    Text("\(backbone)").font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(PLOS.Palette.ink2)
                    Text("骨架学习日").font(.system(size: 12)).foregroundColor(PLOS.Palette.ink3)
                }
                VStack(spacing: 4) {
                    Text("学\(study)休\(rest)").font(.system(size: 16, weight: .bold))
                        .foregroundColor(PLOS.Palette.g600); Text("节奏").font(.system(size: 12)).foregroundColor(PLOS.Palette.ink3)
                }
            }
        }.padding(16).background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1)))
    }
}

struct IntAddGoalSheet: View {
    let onAdd: (String, String, String, String, Double, Date, Double, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var rawType = "deadline"
    @State private var target = ""
    @State private var unit = "章"
    @State private var total: Double = 6
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var importance: Double = 1.0
    @State private var threshold: Double = 0.8

    var body: some View {
        NavigationStack {
            Form {
                TextField("科目（如 高数）", text: $subject)
                Picker("类型", selection: $rawType) {
                    Text("按期完成").tag("deadline"); Text("每天做").tag("habit"); Text("节点完成").tag("milestone")
                }
                TextField("目标描述（如 完成6章）", text: $target)
                HStack {
                    TextField("单位", text: $unit)
                    TextField("总量", value: $total, format: .number)
                }
                DatePicker("截止日期", selection: $deadline, displayedComponents: .date)
                HStack { Text("重要性"); Slider(value: $importance, in: 0.5...2.0, step: 0.1)
                    Text(String(format: "%.1f", importance)).font(.system(size: 13, design: .monospaced)) }
                HStack { Text("达标线"); Slider(value: $threshold, in: 0.5...1.0, step: 0.05)
                    Text("\(Int(threshold * 100))%").font(.system(size: 13, design: .monospaced)) }
            }
            .navigationTitle("添加目标")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        onAdd(subject, rawType, target, unit, total, deadline, importance, threshold)
                        dismiss()
                    }.disabled(subject.isEmpty || target.isEmpty)
                }
            }
        }
    }
}

import SwiftUI

// MARK: - Screen 02: Month Setup (build monthly plan)

struct MonthSetupView: View {
    @State private var goals: [MockGoal]
    @State private var studyDays: Int = 5
    @State private var restDays: Int = 2
    @State private var flexTotal: Int = 2
    @State private var showDeleteConfirmation = false
    @State private var goalToDelete: MockGoal?

    init(goals: [MockGoal] = MockData.defaultGoals) {
        _goals = State(initialValue: goals)
    }

    private var backboneStudy: Int { 23 } // 学5休2 × 31 days
    private var guaranteed: Int { backboneStudy - flexTotal }

    var body: some View {
        ScreenContainer {
            VStack(spacing: 0) {
                StatusBar(time: "9:24")

                // Navigation bar
                HStack {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(PLOS.Palette.ink2)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(PLOS.Palette.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(PLOS.Palette.hairline, lineWidth: 1))
                            )
                    }
                    Spacer()
                    Text("建立 6 月计划")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink)
                    Spacer()
                    Text("2026·06")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(PLOS.Palette.g700)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                                .fill(PLOS.Palette.g50)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 20) {
                        // Goals section
                        VStack(alignment: .leading, spacing: 11) {
                            HStack {
                                Text("目标")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(PLOS.Palette.ink2)
                                + Text(" · \(goals.count)")
                                    .foregroundColor(PLOS.Palette.ink3)
                                Spacer()
                                Text("越重要，平日分到的时间越多")
                                    .font(.system(size: 12))
                                    .foregroundColor(PLOS.Palette.ink3)
                            }

                            ForEach(goals) { goal in
                                GoalCard(goal: goal, onDelete: {
                                    goalToDelete = goal
                                    showDeleteConfirmation = true
                                })
                            }

                            // Add goal button
                            Button(action: {}) {
                                HStack(spacing: 7) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("添加目标")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(PLOS.Palette.ink3)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                        .foregroundColor(PLOS.Palette.hairline)
                                )
                            }
                        }

                        // Rest Strategy
                        VStack(alignment: .leading, spacing: 12) {
                            Text("休息节奏")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(PLOS.Palette.ink2)

                            HStack(spacing: 12) {
                                StrategyBlock(label: "学习", value: $studyDays, range: 1...7, color: PLOS.Palette.g500)
                                StrategyBlock(label: "休息", value: $restDays, range: 1...5, color: PLOS.Palette.clay)
                                StrategyBlock(label: "灵活额度", value: $flexTotal, range: 0...5, color: PLOS.Palette.slate)
                            }
                        }

                        // Preview card
                        VStack(spacing: 14) {
                            HStack {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(PLOS.Palette.g600)
                                Text("保底学习日预览")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(PLOS.Palette.g700)
                                Spacer()
                            }

                            HStack(spacing: 20) {
                                VStack(spacing: 4) {
                                    Text("\(guaranteed)")
                                        .font(.system(size: PLOS.FontScale.statHero, weight: .bold, design: .rounded))
                                        .foregroundColor(PLOS.Palette.g700)
                                    Text("保底学习日")
                                        .font(.system(size: 12))
                                        .foregroundColor(PLOS.Palette.ink3)
                                }
                                VStack(spacing: 4) {
                                    Text("\(backboneStudy)")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(PLOS.Palette.ink2)
                                    Text("骨架学习日")
                                        .font(.system(size: 12))
                                        .foregroundColor(PLOS.Palette.ink3)
                                }
                                VStack(spacing: 4) {
                                    Text("学\(studyDays)休\(restDays)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(PLOS.Palette.g600)
                                    Text("节奏")
                                        .font(.system(size: 12))
                                        .foregroundColor(PLOS.Palette.ink3)
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                                .fill(PLOS.Palette.surface)
                                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1))
                        )

                        // Confirm button
                        PrimaryButton(title: "确认并生成本月骨架", action: {})
                            .padding(.top, 4)

                        Text("单日基准将对齐保底学习日完成 100%")
                            .font(.system(size: 12))
                            .foregroundColor(PLOS.Palette.ink3)
                            .padding(.bottom, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
        }
        .alert("删除目标", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let goal = goalToDelete {
                    goals.removeAll { $0.id == goal.id }
                }
            }
        } message: {
            Text("确定删除「\(goalToDelete?.subject ?? "")」？此操作不可撤销。")
        }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: MockGoal
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        Text(goal.subject)
                            .font(.system(size: 16.5, weight: .bold))
                            .foregroundColor(PLOS.Palette.ink)
                        TypeChip(type: goal.type)
                    }
                    HStack(spacing: 6) {
                        Text(goal.target)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(PLOS.Palette.ink2)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(PLOS.Palette.surface2)
                            )
                        Text("截止 \(goal.deadline)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(PLOS.Palette.ink2)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(PLOS.Palette.surface2)
                            )
                    }
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundColor(PLOS.Palette.ink3.opacity(0.5))
                        .frame(width: 30, height: 30)
                }
            }

            Rectangle().fill(PLOS.Palette.hairline).frame(height: 1)

            HStack {
                Text("重要性")
                    .font(.system(size: PLOS.FontScale.caption))
                    .foregroundColor(PLOS.Palette.ink3)
                Spacer()
                ImportancePicker(importance: goal.importance)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                .fill(PLOS.Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1))
        )
        .shadow(color: PLOS.Palette.shadow.opacity(0.06), radius: 6, y: 3)
        .shadow(color: PLOS.Palette.shadow.opacity(0.05), radius: 1, y: 1)
    }
}

struct TypeChip: View {
    let type: GoalType

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(PLOS.Palette.g500).frame(width: 6, height: 6)
            Text(type.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PLOS.Palette.g700)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                .fill(PLOS.Palette.g50)
        )
    }
}

struct ImportancePicker: View {
    let importance: Importance

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Importance.allCases, id: \.self) { level in
                Text(level.rawValue)
                    .font(.system(size: 12, weight: level == importance ? .bold : .semibold))
                    .foregroundColor(level == importance ? .white : PLOS.Palette.ink3)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                            .fill(level == importance ? PLOS.Palette.g500 : .clear)
                    )
                    .shadow(color: level == importance ? PLOS.Palette.g500.opacity(0.55) : .clear,
                            radius: 6, y: 2)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                .fill(PLOS.Palette.surface2)
                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.pill).stroke(PLOS.Palette.hairline, lineWidth: 1))
        )
    }
}

struct StrategyBlock: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(PLOS.Palette.ink3)
            HStack(spacing: 6) {
                Button(action: { if value > range.lowerBound { value -= 1 } }) {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink2)
                        .frame(width: 32, height: 32)
                }
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .frame(minWidth: 30)
                Button(action: { if value < range.upperBound { value += 1 } }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink2)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.md)
                .fill(PLOS.Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.md).stroke(PLOS.Palette.hairline, lineWidth: 1))
        )
    }
}

// MARK: - Dash Pattern Shape

extension View {
    func dashedBorder(radius: CGFloat, dash: [CGFloat]) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: dash))
        )
    }
}

#Preview("Month Setup") {
    MonthSetupView()
        .preferredColorScheme(.light)
}

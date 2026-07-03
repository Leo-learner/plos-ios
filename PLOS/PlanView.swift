import SwiftUI

// MARK: - Screen 08: Plan View (main day screen, low-launch-cost)

struct PlanView: View {
    let state: MockMonthState

    private let monthlyProgress: [(subject: String, progress: Double, threshold: Double?, isPassed: Bool)] = [
        ("高数", 0.62, 0.80, false),
        ("英语", 0.86, 0.70, true),
        ("线代", 0.48, 0.80, false),
        ("项目", 0.70, nil, false),
    ]

    var body: some View {
        ScreenContainer {
            VStack(spacing: 0) {
                StatusBar(time: "13:26")

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Top row
                        HStack {
                            DayTypeChip(dayType: state.todayType)
                            Spacer()
                            StreakBadge(streak: 12)
                        }

                        // Today's tasks
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("今天 · \(state.plannedItems.count) 件事")
                                    .font(.system(size: PLOS.FontScale.body, weight: .bold))
                                    .foregroundColor(PLOS.Palette.ink)
                                Spacer()
                                Text("已完成 **67%**")
                                    .font(.system(size: PLOS.FontScale.caption))
                                    .foregroundColor(PLOS.Palette.ink3)
                            }

                            // Task rows with completion state
                            CompletedTaskRow(
                                subject: "线代", minutes: 30, isDone: true
                            )
                            ActiveTaskRow(
                                subject: "英语", minutes: 15, status: "进行中"
                            )
                        }

                        // Condensed reasoning
                        HStack(spacing: 11) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 16))
                                .foregroundColor(PLOS.Palette.g700)
                            Text("低谷日，只保线代和英语，**预算 45 分钟**。")
                                .font(.system(size: PLOS.FontScale.footnote))
                                .foregroundColor(PLOS.Palette.g800)
                                .lineSpacing(2)
                            Spacer()
                            Text("展开 ›")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(PLOS.Palette.g600)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                                .fill(PLOS.Palette.g50)
                                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                                    .stroke(PLOS.Palette.g100, lineWidth: 1))
                        )

                        // Monthly progress
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Text("本月进度")
                                    .font(.system(size: PLOS.FontScale.footnote, weight: .bold))
                                    .foregroundColor(PLOS.Palette.ink2)
                                Spacer()
                                HStack(spacing: 5) {
                                    Rectangle()
                                        .fill(PLOS.Palette.g700)
                                        .frame(width: 2, height: 11)
                                    Text("达标线")
                                        .font(.system(size: 11))
                                        .foregroundColor(PLOS.Palette.ink3)
                                }
                            }

                            ForEach(monthlyProgress, id: \.subject) { item in
                                MiniProgressBar(
                                    label: item.subject,
                                    progress: item.progress,
                                    threshold: item.threshold,
                                    isPassed: item.isPassed
                                )
                            }

                            // Project deadline marker
                            HStack(spacing: 11) {
                                Text("项目")
                                    .font(.system(size: 13))
                                    .foregroundColor(PLOS.Palette.ink2)
                                    .frame(width: 34, alignment: .leading)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 999)
                                        .fill(PLOS.Palette.surface2)
                                        .frame(height: 8)
                                    RoundedRectangle(cornerRadius: 999)
                                        .fill(PLOS.Palette.g400)
                                        .frame(width: 140, height: 8) // ~70%
                                }
                                Text("截止6/25")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: 0x8A6420))
                                    .frame(width: 52, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                                .fill(PLOS.Palette.surface)
                                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                                    .stroke(PLOS.Palette.hairline, lineWidth: 1))
                        )
                        .shadow(color: Color(hex: 0x263A2C).opacity(0.06), radius: 6, y: 3)
                        .shadow(color: Color(hex: 0x263A2C).opacity(0.05), radius: 1, y: 1)

                        Spacer(minLength: 8)

                        // Evening report button
                        PrimaryButton(title: "晚间汇报", action: {})

                        Text("晚上花一分钟汇报，明早重新排")
                            .font(.system(size: 12))
                            .foregroundColor(PLOS.Palette.ink3)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

// MARK: - Completed Task Row

struct CompletedTaskRow: View {
    let subject: String
    let minutes: Int
    let isDone: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isDone {
                ZStack {
                    Circle()
                        .fill(PLOS.Palette.g500)
                        .frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            } else {
                Circle()
                    .stroke(PLOS.Palette.hairline, lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
            Text(subject)
                .font(.system(size: PLOS.FontScale.body, weight: .bold))
                .foregroundColor(PLOS.Palette.ink)
            Spacer()
            Text("\(minutes) min")
                .font(.system(size: PLOS.FontScale.caption, weight: .semibold, design: .rounded))
                .foregroundColor(PLOS.Palette.ink3)
            Text(isDone ? "完成" : "进行中")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isDone ? PLOS.Palette.g600 : Color(hex: 0x436670))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                        .fill(isDone ? PLOS.Palette.g50 : PLOS.Palette.slateBg)
                )
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.md)
                .fill(PLOS.Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.md).stroke(PLOS.Palette.hairline, lineWidth: 1))
        )
        .shadow(color: Color(hex: 0x263A2C).opacity(0.06), radius: 6, y: 3)
        .shadow(color: Color(hex: 0x263A2C).opacity(0.05), radius: 1, y: 1)
    }
}

// MARK: - Active Task Row (in progress)

struct ActiveTaskRow: View {
    let subject: String
    let minutes: Int
    let status: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(PLOS.Palette.slate, lineWidth: 2)
                    .frame(width: 24, height: 24)
                // Clock hands
                Path { path in
                    path.move(to: CGPoint(x: 12, y: 12))
                    path.addLine(to: CGPoint(x: 12, y: 5))
                    path.move(to: CGPoint(x: 12, y: 12))
                    path.addLine(to: CGPoint(x: 16, y: 14.5))
                }
                .stroke(PLOS.Palette.slate, lineWidth: 1.5)
                .frame(width: 24, height: 24)
            }
            Text(subject)
                .font(.system(size: PLOS.FontScale.body, weight: .bold))
                .foregroundColor(PLOS.Palette.ink)
            Spacer()
            Text("\(minutes) min")
                .font(.system(size: PLOS.FontScale.caption, weight: .semibold, design: .rounded))
                .foregroundColor(PLOS.Palette.ink3)
            Text(status)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: 0x436670))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                        .fill(PLOS.Palette.slateBg)
                )
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.md)
                .fill(PLOS.Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.md).stroke(PLOS.Palette.hairline, lineWidth: 1))
        )
        .shadow(color: Color(hex: 0x263A2C).opacity(0.06), radius: 6, y: 3)
        .shadow(color: Color(hex: 0x263A2C).opacity(0.05), radius: 1, y: 1)
    }
}

// MARK: - Preview

#Preview("Plan View") {
    PlanView(state: MockData.lowEnergy())
}

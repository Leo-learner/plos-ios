import SwiftUI

// MARK: - Reusable Health Reminder Banner

/// Yellow-tinted dismissible health alert. Does NOT modify the plan budget.
struct HealthReminderBanner: View {
    let message: String
    let onDismiss: () -> Void
    @State private var isVisible: Bool = true

    var body: some View {
        if isVisible {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(PLOS.Palette.warn)
                    .padding(.top, 2)
                Text(.init(message))
                    .font(.system(size: PLOS.FontScale.caption))
                    .foregroundColor(PLOS.Palette.amberInk)
                    .lineSpacing(1.55)
                Spacer()
                Button(action: {
                    withAnimation { isVisible = false }
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(PLOS.Palette.amberInk.opacity(0.55))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(PLOS.Palette.warnBg)
            .overlay(alignment: .top) {
                Rectangle().fill(PLOS.Palette.sand).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(PLOS.Palette.sand).frame(height: 1)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Exam Warning Banner

/// Info-tinted banner for pre-exam day.
struct ExamWarningBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 14))
                .foregroundColor(PLOS.Palette.slate)
                .padding(.top, 2)
            Text(.init(message))
                .font(.system(size: PLOS.FontScale.caption))
                .foregroundColor(PLOS.Palette.teal)
                .lineSpacing(1.55)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .background(PLOS.Palette.slateBg)
        .overlay(alignment: .top) {
            Rectangle().fill(PLOS.Palette.slateLine).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(PLOS.Palette.slateLine).frame(height: 1)
        }
    }
}

// MARK: - Streak Badge

/// Compact "连续运行 N 天" badge with breathing animation dot.
struct StreakBadge: View {
    let streak: Int
    @State private var breathe = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(PLOS.Palette.g500)
                .frame(width: 7, height: 7)
                .opacity(breathe ? 1 : 0.5)
                .scaleEffect(breathe ? 1.35 : 1)
            Text("\(streak) 天")
                .font(.system(size: PLOS.FontScale.caption, weight: .semibold))
                .foregroundColor(PLOS.Palette.g700)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                .fill(PLOS.Palette.g50)
                .overlay(
                    RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                        .stroke(PLOS.Palette.g100, lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

// MARK: - Day Type Chip

/// Visual indicator for today's day type.
struct DayTypeChip: View {
    let dayType: MockDayType

    var body: some View {
        switch dayType {
        case .study:
            HStack(spacing: 6) {
                Circle().fill(energyColor).frame(width: 7, height: 7)
                Text(energyLabel)
                    .font(.system(size: PLOS.FontScale.caption, weight: .semibold))
                    .foregroundColor(labelColor)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                    .fill(bgColor)
                    .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.pill).stroke(borderColor, lineWidth: 1))
            )
        case .rhythmRest:
            HStack(spacing: 7) {
                Circle().fill(PLOS.Palette.clay).frame(width: 7, height: 7)
                Text("节奏休息日")
                    .font(.system(size: PLOS.FontScale.caption, weight: .bold))
                    .foregroundColor(PLOS.Palette.clayInkAlt)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                    .fill(PLOS.Palette.clayChipBg.opacity(0.8))
                    .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.pill).stroke(PLOS.Palette.clayChipEdge, lineWidth: 1))
            )
        case .flexRest:
            HStack(spacing: 7) {
                Circle().fill(PLOS.Palette.slate).frame(width: 7, height: 7)
                Text("灵活休息日")
                    .font(.system(size: PLOS.FontScale.caption, weight: .bold))
                    .foregroundColor(PLOS.Palette.teal)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                    .fill(PLOS.Palette.slateChipBg.opacity(0.8))
                    .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.pill).stroke(PLOS.Palette.slateLine, lineWidth: 1))
            )
        }
    }

    private var energyColor: Color {
        switch dayType {
        case .study(let e):
            switch e {
            case .high: return PLOS.Palette.amber
            case .normal: return PLOS.Palette.g500
            case .low: return PLOS.Palette.peri
            }
        default: return .clear
        }
    }

    private var bgColor: Color {
        switch dayType {
        case .study(let e):
            switch e {
            case .high: return PLOS.Palette.amberBg
            case .normal: return PLOS.Palette.g50
            case .low: return PLOS.Palette.periBg
            }
        default: return .clear
        }
    }

    private var borderColor: Color {
        switch dayType {
        case .study(let e):
            switch e {
            case .high: return PLOS.Palette.sand
            case .normal: return PLOS.Palette.g100
            case .low: return PLOS.Palette.periChipBg
            }
        default: return .clear
        }
    }

    private var labelColor: Color {
        switch dayType {
        case .study(let e):
            switch e {
            case .high: return PLOS.Palette.amberInk
            case .normal: return PLOS.Palette.g700
            case .low: return PLOS.Palette.periInk
            }
        default: return .clear
        }
    }

    private var energyLabel: String {
        switch dayType {
        case .study(let e):
            switch e {
            case .high: return "高能"
            case .normal: return "普通"
            case .low: return "低谷"
            }
        default: return ""
        }
    }
}

// MARK: - Passed Goal Dimmed Row

/// A goal that has passed its threshold — dimmed, with a checkmark and yield message.
struct PassedGoalRow: View {
    let subject: String
    let thresholdPct: Int

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(PLOS.Palette.g50)
                    .frame(width: 27, height: 27)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(PLOS.Palette.g500)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(subject)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink2)
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("已达标 \(thresholdPct)%")
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(PLOS.Palette.g600)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                            .fill(PLOS.Palette.g50)
                    )
                }
                Text("今天让位给未达标科目，明天轻量维持")
                    .font(.system(size: 12))
                    .foregroundColor(PLOS.Palette.ink3)
            }
            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                .fill(PLOS.Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                        .stroke(PLOS.Palette.g200, style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
        )
        .opacity(0.62)
    }
}

// MARK: - Reasoning Card

/// The reasoning card — the system's "why" explanation. Prominent and readable.
struct ReasoningCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(PLOS.Palette.g100)
                        .frame(width: 30, height: 30)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 15))
                        .foregroundColor(PLOS.Palette.g700)
                }
                Text("系统为什么这么排")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(PLOS.Palette.g700)
            }
            Text(.init(text))
                .font(.system(size: PLOS.FontScale.reasoning))
                .foregroundColor(PLOS.Palette.g800)
                .lineSpacing(PLOS.FontScale.reasoning * PLOS.LineHeight.reasoning - PLOS.FontScale.reasoning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(17)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.card)
                .fill(PLOS.Gradients.reasoning)
                .overlay(
                    RoundedRectangle(cornerRadius: PLOS.Radius.card)
                        .stroke(PLOS.Palette.g100, lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview("Health Banner") {
    VStack(spacing: 0) {
        HealthReminderBanner(
            message: "已连续 **4 天**没有运动，今晚早点睡、动一动。**不改今天的计划**。",
            onDismiss: {}
        )
        Spacer()
    }
    .background(PLOS.Palette.paper)
}

#Preview("Streak Badge") {
    StreakBadge(streak: 12)
        .padding()
        .background(PLOS.Palette.paper)
}

#Preview("Day Chips") {
    HStack(spacing: 10) {
        DayTypeChip(dayType: .study(energy: .high))
        DayTypeChip(dayType: .study(energy: .normal))
        DayTypeChip(dayType: .study(energy: .low))
        DayTypeChip(dayType: .rhythmRest)
        DayTypeChip(dayType: .flexRest)
    }
    .padding()
    .background(PLOS.Palette.paper)
}

#Preview("Passed Goal") {
    PassedGoalRow(subject: "线代", thresholdPct: 80)
        .padding()
        .background(PLOS.Palette.paper)
}

#Preview("Reasoning Card") {
    ReasoningCard(text: "高能日，预算 **150 分钟**，安排 4 项。线代落后节奏 **27%**、压力最高。")
        .padding()
        .background(PLOS.Palette.paper)
}

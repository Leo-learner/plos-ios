import SwiftUI
import Charts

// MARK: - Progress Dashboard View (§P.1)

struct ProgressDashboardView: View {
    @Environment(AppViewModel.self) private var vm

    private var summaries: [GoalProgressSummary] { vm.computeProgressSummaries() }
    private var loadHistory: [LoadSummary] { vm.computeLoadHistory() }
    private var calendar: [StreakDay] { vm.computeStreakCalendar() }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // ── Section: Per-goal completion rings + bars ──
                VStack(alignment: .leading, spacing: 13) {
                    Text("各科完成率").font(.system(size: PLOS.FontScale.footnote, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink2)
                    ForEach(summaries) { s in
                        GoalProgressRow(summary: s)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1)))

                // ── Section: Projected finish (deterministic extrapolation) ──
                VStack(alignment: .leading, spacing: 11) {
                    Text("按保底节奏预计完成度")
                        .font(.system(size: PLOS.FontScale.footnote, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink2)
                    Text("直线外推：current + baseline_today × remaining_study_days，纯算术，不预测。")
                        .font(.system(size: 11))
                        .foregroundColor(PLOS.Palette.ink3)
                    ForEach(summaries) { s in
                        ProjectionRow(summary: s)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1)))

                // ── Section: Load curve (planned minutes vs actual completion) ──
                if !loadHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("负荷曲线").font(.system(size: PLOS.FontScale.footnote, weight: .bold))
                            .foregroundColor(PLOS.Palette.ink2)
                        Text("蓝色=计划分钟 · 绿色=实际完成比例")
                            .font(.system(size: 11))
                            .foregroundColor(PLOS.Palette.ink3)
                        Chart(loadHistory) { pt in
                            let label = String(pt.dateStr.suffix(5))
                            BarMark(x: .value("日期", label),
                                    y: .value("计划分钟", pt.plannedMinutes))
                                .foregroundStyle(PLOS.Palette.slate.opacity(0.5))
                            if pt.isStudyDay {
                                LineMark(x: .value("日期", label),
                                         y: .value("完成%", pt.actualPct * 100))
                                    .foregroundStyle(PLOS.Palette.g500)
                            }
                        }
                        .frame(height: 180)
                        .chartLegend(.hidden)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1)))
                }

                // ── Section: Streak calendar heatmap ──
                VStack(alignment: .leading, spacing: 11) {
                    Text("连续运行日历").font(.system(size: PLOS.FontScale.footnote, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink2)
                    StreakCalendarGrid(days: calendar)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1)))

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
        }
        .background(PLOS.Palette.paper)
        .navigationTitle("进度")
    }
}

// MARK: - Sub-components

struct GoalProgressRow: View {
    let summary: GoalProgressSummary

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(summary.subject)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(summary.isPassed ? PLOS.Palette.ink2 : PLOS.Palette.ink)
                Spacer()
                Text("\(Int(summary.progress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(summary.isPassed ? PLOS.Palette.g500 : PLOS.Palette.g700)
                HStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                    Text("\(Int(summary.threshold * 100))%")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(PLOS.Palette.g700)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(PLOS.Palette.g50))
            }

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999).fill(PLOS.Palette.surface2).frame(height: 8)
                    RoundedRectangle(cornerRadius: 999)
                        .fill(summary.isPassed ? PLOS.Palette.g500 : PLOS.Palette.g400)
                        .frame(width: CGFloat(summary.progress) * geo.size.width, height: 8)
                    // Threshold marker
                    RoundedRectangle(cornerRadius: 2)
                        .fill(PLOS.Palette.g700)
                        .frame(width: 2, height: 12)
                        .offset(x: CGFloat(summary.threshold) * geo.size.width - 1)
                }
            }
            .frame(height: 12)
        }
    }
}

struct ProjectionRow: View {
    let summary: GoalProgressSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(summary.subject).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PLOS.Palette.ink2)
                Spacer()
                Text("当前 \(Int(summary.progress * 100))%")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(PLOS.Palette.ink3)
                Text(" → ")
                    .font(.system(size: 12)).foregroundColor(PLOS.Palette.ink3)
                Text("预计 \(Int(summary.projectedFinishPct * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(projectionColor)
            }
            // Projection bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999).fill(PLOS.Palette.surface2).frame(height: 6)
                    RoundedRectangle(cornerRadius: 999)
                        .fill(PLOS.Palette.g300)
                        .frame(width: CGFloat(summary.progress) * geo.size.width, height: 6)
                    RoundedRectangle(cornerRadius: 999)
                        .fill(projectionColor.opacity(0.3))
                        .frame(width: CGFloat(summary.projectedFinishPct) * geo.size.width, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var projectionColor: Color {
        if summary.projectedFinishPct >= summary.threshold { return PLOS.Palette.g500 }
        if summary.projectedFinishPct >= summary.threshold * 0.7 { return PLOS.Palette.amber }
        return Color(hex: 0xB4842F)
    }
}

struct StreakCalendarGrid: View {
    let days: [StreakDay]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(["日","一","二","三","四","五","六"], id: \.self) { d in
                Text(d).font(.system(size: 10, weight: .semibold))
                    .foregroundColor(PLOS.Palette.ink3)
                    .frame(maxWidth: .infinity)
            }
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 4)
                    .fill(cellColor(day))
                    .frame(height: 22)
                    .overlay(
                        Text(String(day.dateStr.suffix(2)))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(day.systemRan ? .white : PLOS.Palette.ink3)
                    )
            }
        }
    }

    private func cellColor(_ day: StreakDay) -> Color {
        if !day.isStudyDay { return PLOS.Palette.clayBg }
        if day.systemRan { return PLOS.Palette.g500 }
        return PLOS.Palette.g100
    }
}

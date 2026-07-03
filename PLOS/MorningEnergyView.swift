import SwiftUI

// MARK: - Screen 03: Morning · Energy Selection (study day)

struct MorningEnergyView: View {
    let state: MockMonthState

    var body: some View {
        ScreenContainer {
            VStack(spacing: 0) {
                StatusBar(time: "7:12")

                VStack(alignment: .leading, spacing: 18) {
                    // Header row
                    HStack {
                        DayTypeChip(dayType: .study(energy: .low))
                        Spacer()
                        StreakBadge(streak: state.streak)
                    }

                    // Date and greeting
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(state.dateString) · 早安")
                            .font(.system(size: PLOS.FontScale.footnote))
                            .foregroundColor(PLOS.Palette.ink3)
                        Text("系统先替你预判了今天")
                            .font(.system(size: PLOS.FontScale.title, weight: .bold))
                            .foregroundColor(PLOS.Palette.ink)
                    }

                    // Energy selector
                    VStack(spacing: 11) {
                        EnergyButton(
                            level: .high,
                            icon: "bolt.fill",
                            title: "高能",
                            subtitle: "状态很好，可以多推进一点",
                            isSelected: false,
                            action: {}
                        )
                        EnergyButton(
                            level: .normal,
                            icon: "sun.max.fill",
                            title: "普通",
                            subtitle: "按基准来，稳稳当当",
                            isSelected: false,
                            action: {}
                        )
                        EnergyButton(
                            level: .low,
                            icon: "moon.zzz.fill",
                            title: "低谷",
                            subtitle: "先别为难自己，做最要紧的",
                            isSelected: true,
                            badge: "系统预填",
                            action: {}
                        )
                    }

                    // Explanation box
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(PLOS.Palette.peri)
                            .padding(.top, 2)
                        Text("依据：连续 3 晚睡得晚 · 高数考试还剩 **7 天**，先稳一稳。**不对？点上面任意一个改掉。**")
                            .font(.system(size: PLOS.FontScale.caption))
                            .foregroundColor(PLOS.Palette.periInk)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: PLOS.Radius.md)
                            .fill(PLOS.Palette.periBg)
                    )

                    Spacer()

                    // Generate button
                    VStack(spacing: 10) {
                        PrimaryButton(title: "生成今日计划", action: {})
                        Text("已按「低谷」预填，直接生成 —— 或先改状态")
                            .font(.system(size: 12))
                            .foregroundColor(PLOS.Palette.ink3)
                    }
                    .padding(.bottom, 6)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Energy Button

struct EnergyButton: View {
    let level: EnergyLevel
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    var badge: String?
    let action: () -> Void

    private var accentColor: Color {
        switch level {
        case .high: return PLOS.Palette.amber
        case .normal: return PLOS.Palette.g400
        case .low: return PLOS.Palette.peri
        }
    }

    private var bgColor: Color {
        switch level {
        case .high: return PLOS.Palette.amberBg
        case .normal: return PLOS.Palette.g50
        case .low: return PLOS.Palette.periBg
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: isSelected ? 14 : 13)
                        .fill(bgColor)
                        .frame(width: isSelected ? 46 : 42, height: isSelected ? 46 : 42)
                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 19 : 17))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: isSelected ? 4 : 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: isSelected ? 16.5 : 15.5, weight: .bold))
                            .foregroundColor(PLOS.Palette.ink)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(PLOS.Palette.g500)
                                )
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: isSelected ? 12.5 : 12))
                        .foregroundColor(isSelected ? PLOS.Palette.ink2 : PLOS.Palette.ink3)
                }

                Spacer()

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(PLOS.Palette.g500)
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                    .fill(isSelected ? PLOS.Palette.g50 : PLOS.Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                            .stroke(isSelected ? PLOS.Palette.g500 : PLOS.Palette.hairline, lineWidth: isSelected ? 2 : 1.5)
                    )
            )
            .shadow(color: isSelected ? PLOS.Palette.g500.opacity(0.5) : .clear, radius: 8, y: 10)
        }
    }
}

// MARK: - Preview

#Preview("Morning Energy") {
    MorningEnergyView(state: MockData.lowEnergy())
}

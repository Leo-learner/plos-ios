import SwiftUI

// MARK: - Screens 09-10: Evening Report

struct EveningReportView: View {
    let state: MockMonthState

    var body: some View {
        ScreenContainer {
            VStack(spacing: 0) {
                StatusBar(time: "22:41")

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Header
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(state.dateString) · 睡前一分钟")
                                .font(.system(size: PLOS.FontScale.footnote))
                                .foregroundColor(PLOS.Palette.ink3)
                            Text("今天做得怎么样？")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(PLOS.Palette.ink)
                            Text("拖动滑块就好，不用打字。")
                                .font(.system(size: 13))
                                .foregroundColor(PLOS.Palette.ink2)
                        }

                        // Report items
                        ForEach(state.plannedItems) { item in
                            ReportSliderCard(item: item)
                        }

                        Spacer(minLength: 16)

                        // Save button
                        VStack(spacing: 10) {
                            PrimaryButton(title: "保存 · 今天结束", action: {})
                            Text("明早系统会接着今天，重新排")
                                .font(.system(size: 12))
                                .foregroundColor(PLOS.Palette.ink3)
                        }
                        .padding(.bottom, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }
            }
        }
    }
}

// MARK: - Report Slider Card

struct ReportSliderCard: View {
    let item: MockPlannedItem
    @State private var sliderValue: Double
    @State private var note: String = ""

    init(item: MockPlannedItem) {
        self.item = item
        _sliderValue = State(initialValue: item.isDone ? 100 : 80)
    }

    private var pctValue: Int { Int(sliderValue) }
    private var effectiveMinutes: Int { Int(Double(item.minutes) * sliderValue / 100.0) }

    var body: some View {
        VStack(spacing: 13) {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.subject)
                        .font(.system(size: PLOS.FontScale.subject, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink)
                    Text("目标 \(item.minutes) min")
                        .font(.system(size: 12))
                        .foregroundColor(PLOS.Palette.ink3)
                }
                Spacer()
                if pctValue >= 100 {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("完成")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(PLOS.Palette.g600)
                } else {
                    Text("\(effectiveMinutes) min")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(PLOS.Palette.g700)
                }
            }

            // Slider
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(PLOS.Palette.surface2)
                    .frame(height: 10)

                RoundedRectangle(cornerRadius: 999)
                    .fill(PLOS.Palette.g500)
                    .frame(width: max(0, CGFloat(sliderValue / 100.0) * 300), height: 10)

                // Thumb
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(PLOS.Palette.g500, lineWidth: 3))
                    .frame(width: 26, height: 26)
                    .shadow(color: Color(hex: 0x263A2C).opacity(0.25), radius: 3, y: 3)
                    .offset(x: CGFloat(sliderValue / 100.0) * 290 - 13)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                let width: CGFloat = 290
                                let newValue = (g.location.x / width) * 100
                                sliderValue = min(max(newValue, 0), 100)
                            }
                    )
            }
            .padding(.vertical, 6)

            // Note field
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundColor(PLOS.Palette.ink3)
                TextField("个人备忘（可选 · 仅记录，不影响明天计划）", text: $note)
                    .font(.system(size: 13))
                    .foregroundColor(PLOS.Palette.ink2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: PLOS.Radius.md)
                    .fill(PLOS.Palette.surface2)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                .fill(PLOS.Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1))
        )
        .shadow(color: Color(hex: 0x263A2C).opacity(0.06), radius: 6, y: 3)
        .shadow(color: Color(hex: 0x263A2C).opacity(0.05), radius: 1, y: 1)
    }
}

// MARK: - Zero Percent Report (Screen 10)

struct ZeroReportView: View {
    let state: MockMonthState

    var body: some View {
        ScreenContainer {
            VStack(spacing: 0) {
                StatusBar(time: "23:58")

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 5) {
                            Text("6 月 22 日 · 睡前")
                                .font(.system(size: PLOS.FontScale.footnote))
                                .foregroundColor(PLOS.Palette.ink3)
                            Text("今天没推进也没关系")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(PLOS.Palette.ink)
                        }

                        // Encouragement card
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 17))
                                .foregroundColor(PLOS.Palette.g700)
                            Text("系统不会断。保存后，今天**仍然算运行的一天**。明天照常生成，接着往前走。")
                                .font(.system(size: PLOS.FontScale.footnote))
                                .foregroundColor(PLOS.Palette.g800)
                                .lineSpacing(PLOS.FontScale.footnote * PLOS.LineHeight.body - PLOS.FontScale.footnote)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                                .fill(PLOS.Gradients.reasoning)
                                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                                    .stroke(PLOS.Palette.g100, lineWidth: 1))
                        )

                        // All-zero sliders
                        ForEach(state.plannedItems) { item in
                            ZeroSliderCard(item: item)
                        }

                        Spacer(minLength: 16)

                        // Save button
                        VStack(spacing: 10) {
                            PrimaryButton(title: "保存 · 今天结束", action: {})
                            Text("保存后 → 连续运行第 \(state.streak) 天（0% 也计入）")
                                .font(.system(size: 12))
                                .foregroundColor(PLOS.Palette.g600)
                        }
                        .padding(.bottom, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }
            }
        }
    }
}

// MARK: - Zero Slider Card (all at 0%)

struct ZeroSliderCard: View {
    let item: MockPlannedItem

    var body: some View {
        VStack(spacing: 11) {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.subject)
                        .font(.system(size: PLOS.FontScale.subject, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink)
                    Text("目标 \(item.minutes) min")
                        .font(.system(size: 12))
                        .foregroundColor(PLOS.Palette.ink3)
                }
                Spacer()
                Text("0 min")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(PLOS.Palette.ink3)
            }

            // Zero slider
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(PLOS.Palette.surface2)
                    .frame(height: 10)

                // Thumb at 0
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(PLOS.Palette.ink3, lineWidth: 3))
                    .frame(width: 26, height: 26)
                    .shadow(color: Color(hex: 0x263A2C).opacity(0.2), radius: 3, y: 3)
                    .offset(x: -13)
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                .fill(PLOS.Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1))
        )
        .shadow(color: Color(hex: 0x263A2C).opacity(0.06), radius: 6, y: 3)
        .shadow(color: Color(hex: 0x263A2C).opacity(0.05), radius: 1, y: 1)
    }
}

// MARK: - Preview

#Preview("Evening Report") {
    EveningReportView(state: MockData.evening())
}

#Preview("Zero Report") {
    ZeroReportView(state: MockData.evening())
}

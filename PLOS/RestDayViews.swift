import SwiftUI

// MARK: - Screens 06-07: Rest Day Views (rhythm rest + flex rest)

struct RhythmRestView: View {
    let state: MockMonthState

    var body: some View {
        ScreenContainer {
            VStack(spacing: 0) {
                StatusBar(time: "8:40")

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        DayTypeChip(dayType: .rhythmRest)
                        Spacer()
                        Text(state.dateString)
                            .font(.system(size: 13))
                            .foregroundColor(PLOS.Palette.clayMuted)
                    }

                    Spacer()

                    // Center illustration + message
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [PLOS.Palette.clayOrb1, PLOS.Palette.clayOrb2],
                                        center: .init(x: 0.5, y: 0.38), startRadius: 0, endRadius: 56
                                    )
                                )
                                .frame(width: 112, height: 112)
                                .overlay(
                                    Circle().stroke(PLOS.Palette.clayOrbEdge, lineWidth: 1)
                                )
                                .shadow(color: PLOS.Palette.clayShadow.opacity(0.5), radius: 14, y: 14)
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 38))
                                .foregroundColor(PLOS.Palette.clay)
                        }

                        VStack(spacing: 11) {
                            Text("今天是计划内的休息日")
                                .font(.system(size: PLOS.FontScale.title, weight: .bold))
                                .foregroundColor(PLOS.Palette.clayInk)
                            Text("系统按你的节奏（学 5 休 2）安排了今天休息。什么都不用做。")
                                .font(.system(size: PLOS.FontScale.body))
                                .foregroundColor(PLOS.Palette.clayText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 266)
                                .lineSpacing(PLOS.FontScale.body * PLOS.LineHeight.body - PLOS.FontScale.body)
                        }
                    }

                    Spacer()

                    // System running card
                    VStack(spacing: 11) {
                        HStack(spacing: 13) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(PLOS.Palette.g50)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(PLOS.Palette.g700)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("系统仍在运行")
                                    .font(.system(size: PLOS.FontScale.caption))
                                    .foregroundColor(PLOS.Palette.ink3)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("第 \(state.streak) 天")
                                        .font(.system(size: 23, weight: .bold, design: .rounded))
                                        .foregroundColor(PLOS.Palette.g700)
                                    Text("连续")
                                        .font(.system(size: 13))
                                        .foregroundColor(PLOS.Palette.ink2)
                                }
                            }
                            Spacer()
                            Circle()
                                .fill(PLOS.Palette.g500)
                                .frame(width: 9, height: 9)
                                .opacity(0.5)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: PLOS.Radius.card)
                                .fill(PLOS.Palette.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: PLOS.Radius.card)
                                        .stroke(PLOS.Palette.clayLine, lineWidth: 1)
                                )
                        )

                        Text("明天回到学习日 —— 接着上次的线代继续。")
                            .font(.system(size: PLOS.FontScale.caption))
                            .foregroundColor(PLOS.Palette.clayMuted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(
                LinearGradient(
                    colors: [PLOS.Palette.clayBg1, PLOS.Palette.clayBg2],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Flex Rest View

struct FlexRestView: View {
    let state: MockMonthState

    var flexRemaining: Int {
        state.restStrategy.flexTotal - state.restStrategy.flexUsed
    }

    var body: some View {
        ScreenContainer {
            VStack(spacing: 0) {
                StatusBar(time: "9:02")

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        DayTypeChip(dayType: .flexRest)
                        Spacer()
                        Text(state.dateString)
                            .font(.system(size: 13))
                            .foregroundColor(PLOS.Palette.slateMuted)
                    }

                    Spacer()

                    // Center
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [PLOS.Palette.slateOrb1, PLOS.Palette.slateOrbEdge],
                                        center: .init(x: 0.5, y: 0.38), startRadius: 0, endRadius: 56
                                    )
                                )
                                .frame(width: 112, height: 112)
                                .overlay(
                                    Circle().stroke(PLOS.Palette.slateOrbEdge, lineWidth: 1)
                                )
                                .shadow(color: PLOS.Palette.slateShadow.opacity(0.45), radius: 14, y: 14)
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 38))
                                .foregroundColor(PLOS.Palette.slate)
                        }

                        VStack(spacing: 11) {
                            Text("今天先歇一下")
                                .font(.system(size: PLOS.FontScale.title, weight: .bold))
                                .foregroundColor(PLOS.Palette.slateInk)
                            Text("你用了一个灵活休息日，今天转为休息。这不是脱轨 —— 是系统给你留的余地。")
                                .font(.system(size: PLOS.FontScale.body))
                                .foregroundColor(PLOS.Palette.slateText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 270)
                                .lineSpacing(PLOS.FontScale.body * PLOS.LineHeight.body - PLOS.FontScale.body)
                        }
                    }

                    Spacer()

                    // Flex quota card
                    VStack(spacing: 0) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("灵活休息额度")
                                    .font(.system(size: 13))
                                    .foregroundColor(PLOS.Palette.ink2)
                                Spacer()
                                HStack(spacing: 6) {
                                    ForEach(0..<state.restStrategy.flexTotal, id: \.self) { i in
                                        if i < flexRemaining {
                                            RoundedRectangle(cornerRadius: 999)
                                                .fill(PLOS.Palette.slate)
                                                .frame(width: 22, height: 10)
                                        } else {
                                            RoundedRectangle(cornerRadius: 999)
                                                .stroke(PLOS.Palette.slateDash, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                                .frame(width: 22, height: 10)
                                        }
                                    }
                                    Text("剩 \(flexRemaining) / \(state.restStrategy.flexTotal)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(PLOS.Palette.teal)
                                }
                            }

                            Rectangle().fill(PLOS.Palette.hairline).frame(height: 1)

                            HStack(spacing: 13) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(PLOS.Palette.g50)
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(PLOS.Palette.g700)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("系统仍在运行")
                                        .font(.system(size: PLOS.FontScale.caption))
                                        .foregroundColor(PLOS.Palette.ink3)
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text("第 \(state.streak) 天")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(PLOS.Palette.g700)
                                        Text("连续 · 今天也算")
                                            .font(.system(size: PLOS.FontScale.caption))
                                            .foregroundColor(PLOS.Palette.ink2)
                                    }
                                }
                                Spacer()
                                Circle()
                                    .fill(PLOS.Palette.g500)
                                    .frame(width: 9, height: 9)
                                    .opacity(0.5)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: PLOS.Radius.card)
                                .fill(PLOS.Palette.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: PLOS.Radius.card)
                                        .stroke(PLOS.Palette.slateLine, lineWidth: 1)
                                )
                        )

                        Button(action: {}) {
                            Text("点错了？**撤销**，回到学习日")
                                .font(.system(size: PLOS.FontScale.caption))
                                .foregroundColor(PLOS.Palette.slateMuted)
                        }
                        .padding(.vertical, 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(
                LinearGradient(
                    colors: [PLOS.Palette.slateBg1, PLOS.Palette.slateBg2],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Preview

#Preview("Rhythm Rest") {
    RhythmRestView(state: MockData.rhythmRest())
}

#Preview("Flex Rest") {
    FlexRestView(state: MockData.flexRest())
}

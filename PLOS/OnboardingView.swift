import SwiftUI

// MARK: - Screen 01: First Run Empty State

struct OnboardingView: View {
    @State private var logoFloat = false

    var body: some View {
        ScreenContainer {
            VStack(spacing: 0) {
                StatusBar(time: "9:24")

                VStack(spacing: 0) {
                    // Nav bar
                    HStack {
                        HStack(spacing: 7) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 14))
                                .foregroundColor(PLOS.Palette.g600)
                            Text("PLOS")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(PLOS.Palette.g700)
                        }
                        Spacer()
                        Text("系统尚未启动")
                            .font(.system(size: 11.5))
                            .foregroundColor(PLOS.Palette.ink3)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                                    .fill(PLOS.Palette.surface2)
                            )
                    }

                    Spacer()

                    // Center
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [PLOS.Palette.g100, PLOS.Palette.g50],
                                        center: .init(x: 0.5, y: 0.38), startRadius: 0, endRadius: 52
                                    )
                                )
                                .frame(width: 104, height: 104)
                                .overlay(
                                    Circle().stroke(PLOS.Palette.g100, lineWidth: 1)
                                )
                                .shadow(color: PLOS.Palette.g500.opacity(0.5), radius: 12, y: 12)
                                .offset(y: logoFloat ? -5 : 0)

                            Image(systemName: "leaf.fill")
                                .font(.system(size: 40))
                                .foregroundColor(PLOS.Palette.g600)
                        }
                        .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true), value: logoFloat)
                        .onAppear { logoFloat = true }

                        VStack(spacing: 11) {
                            Text("还没有本月的系统")
                                .font(.system(size: PLOS.FontScale.title, weight: .bold))
                                .foregroundColor(PLOS.Palette.ink)
                            Text("先花两分钟建一个月计划。之后每天早上，系统会替你决定今天学什么 —— 你只要打开看一眼。")
                                .font(.system(size: PLOS.FontScale.body))
                                .foregroundColor(PLOS.Palette.ink2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 272)
                                .lineSpacing(PLOS.FontScale.body * PLOS.LineHeight.body - PLOS.FontScale.body)
                        }
                    }

                    Spacer()

                    // Philosophy card
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 16))
                            .foregroundColor(PLOS.Palette.g600)
                        Text("每天不是新的开始，只是**系统运行**的一天。允许失败，不允许脱轨。")
                            .font(.system(size: PLOS.FontScale.footnote))
                            .foregroundColor(PLOS.Palette.g700)
                            .lineSpacing(PLOS.FontScale.footnote * PLOS.LineHeight.body - PLOS.FontScale.footnote)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                            .fill(PLOS.Palette.g50)
                            .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg)
                                .stroke(PLOS.Palette.g100, lineWidth: 1))
                    )
                    .padding(.bottom, 16)

                    // CTA
                    VStack(spacing: 13) {
                        Button(action: {}) {
                            HStack(spacing: 8) {
                                Text("建立本月计划")
                                    .font(.system(size: PLOS.FontScale.button, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: PLOS.Size.primaryButtonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                                    .fill(PLOS.Palette.g500)
                            )
                            .shadow(color: PLOS.Palette.g500.opacity(0.65), radius: 10, y: 7)
                        }

                        Text("建一次，用一个月")
                            .font(.system(size: 12))
                            .foregroundColor(PLOS.Palette.ink3)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)
                .padding(.bottom, 6)
            }
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView()
}

import SwiftUI

// MARK: - App Entry Point

/// Root view with a segmented control to preview all screens.
/// In production, this would use NavigationStack + programmatic routing.
@main
struct PLOSApp: App {
    @State private var selectedScreen: Screen = .onboarding

    enum Screen: String, CaseIterable, Identifiable {
        case onboarding = "空态"
        case monthSetup = "建月"
        case morningEnergy = "能量"
        case todayLow = "低谷日"
        case todayNormal = "考前日"
        case todayHigh = "高能日"
        case rhythmRest = "节奏休息"
        case flexRest = "灵活休息"
        case planView = "主屏"
        case evening = "晚间"
        case zeroReport = "0%汇报"

        var id: String { rawValue }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                PLOS.Palette.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Screen picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Screen.allCases) { screen in
                                Button(action: { selectedScreen = screen }) {
                                    Text(screen.rawValue)
                                        .font(.system(size: 12, weight: selectedScreen == screen ? .bold : .medium))
                                        .foregroundColor(selectedScreen == screen ? .white : PLOS.Palette.ink2)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                                                .fill(selectedScreen == screen ? PLOS.Palette.g500 : PLOS.Palette.surface)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .background(PLOS.Palette.paper)

                    Spacer()

                    // Active screen
                    screenView
                        .padding(.vertical, 20)

                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var screenView: some View {
        switch selectedScreen {
        case .onboarding:
            OnboardingView()
        case .monthSetup:
            MonthSetupView()
        case .morningEnergy:
            MorningEnergyView(state: MockData.lowEnergy())
        case .todayLow:
            TodayPlanView(state: MockData.lowEnergy())
        case .todayNormal:
            TodayPlanView(state: MockData.normalWithExam())
        case .todayHigh:
            TodayPlanView(state: MockData.highEnergy())
        case .rhythmRest:
            RhythmRestView(state: MockData.rhythmRest())
        case .flexRest:
            FlexRestView(state: MockData.flexRest())
        case .planView:
            PlanView(state: MockData.lowEnergy())
        case .evening:
            EveningReportView(state: MockData.evening())
        case .zeroReport:
            ZeroReportView(state: MockData.evening())
        }
    }
}

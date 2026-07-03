import SwiftUI

// MARK: - Screens 04-05-12: Today's Plan (after energy selection)

struct TodayPlanView: View {
    let state: MockMonthState

    var body: some View {
        ScreenContainer {
            VStack(spacing: 0) {
                StatusBar(time: "7:14")

                // Health reminder (if any)
                if let health = state.healthReminder {
                    HealthReminderBanner(message: health, onDismiss: {})
                }

                // Exam warning (if any)
                if let exam = state.examWarning {
                    ExamWarningBanner(message: exam)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        // Header
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(state.dateString) · 今日计划")
                                    .font(.system(size: PLOS.FontScale.footnote))
                                    .foregroundColor(PLOS.Palette.ink3)
                                HStack(alignment: .firstTextBaseline, spacing: 7) {
                                    Text("\(state.budgetMinutes)")
                                        .font(.system(size: PLOS.FontScale.statLarge, weight: .bold, design: .rounded))
                                        .foregroundColor(PLOS.Palette.ink)
                                    Text("分钟 · \(state.plannedItems.count) 件事")
                                        .font(.system(size: 14))
                                        .foregroundColor(PLOS.Palette.ink2)
                                }
                            }
                            Spacer()
                            DayTypeChip(dayType: state.todayType)
                        }

                        // Task list
                        VStack(spacing: 10) {
                            ForEach(state.plannedItems.filter { !$0.isDone }) { item in
                                TaskRow(item: item)
                            }

                            // Passed-goal items (dimmed)
                            ForEach(state.plannedItems.filter { $0.isDone }) { item in
                                if let goal = state.goals.first(where: { $0.id == item.goalId }) {
                                    PassedGoalRow(
                                        subject: goal.subject,
                                        thresholdPct: Int(goal.successThreshold * 100)
                                    )
                                }
                            }
                        }

                        // Reasoning card
                        if !state.reasoning.isEmpty {
                            ReasoningCard(text: state.reasoning)
                        }

                        Spacer(minLength: 8)

                        // Flex rest button
                        SecondaryButton(
                            title: "用一个灵活休息日",
                            subtitle: "灵活休息 \(state.restStrategy.flexTotal - state.restStrategy.flexUsed)/\(state.restStrategy.flexTotal)",
                            action: {}
                        )

                        Text("晚上回来花一分钟汇报，明早接着今天重排")
                            .font(.system(size: 12))
                            .foregroundColor(PLOS.Palette.ink3)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Today Plan · Low Energy + Health + Reasoning") {
    TodayPlanView(state: MockData.lowEnergy())
}

#Preview("Today Plan · Normal + Exam + Passed Goal") {
    TodayPlanView(state: MockData.normalWithExam())
}

#Preview("Today Plan · High Energy") {
    TodayPlanView(state: MockData.highEnergy())
}

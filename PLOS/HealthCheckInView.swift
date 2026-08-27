import SwiftUI
import SwiftData
import PLOSKernel

// MARK: - §P.4: Health Check-in View

struct HealthCheckInView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var exercisedToday = false
    @State private var lateNightsThisWeek: Int = 0
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("健康数据").font(.system(size: PLOS.FontScale.title, weight: .bold))
                    .foregroundColor(PLOS.Palette.ink)

                Text("这些数据只影响健康提醒条（黄色条），不会改变预算或计划。预算下调只能由你手动选「低谷日」。")
                    .font(.system(size: 13))
                    .foregroundColor(PLOS.Palette.ink2)

                // Exercise
                VStack(alignment: .leading, spacing: 10) {
                    Text("今天运动了吗？")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink)
                    Toggle("已运动", isOn: $exercisedToday)
                        .toggleStyle(SwitchToggleStyle(tint: PLOS.Palette.g500))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1)))

                // Late nights
                VStack(alignment: .leading, spacing: 10) {
                    Text("近一周熬夜次数")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(PLOS.Palette.ink)
                    Stepper("\(lateNightsThisWeek) 次", value: $lateNightsThisWeek, in: 0...7)
                    Text("≥3 次会触发健康提醒")
                        .font(.system(size: 12))
                        .foregroundColor(PLOS.Palette.ink3)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: PLOS.Radius.lg).fill(PLOS.Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: PLOS.Radius.lg).stroke(PLOS.Palette.hairline, lineWidth: 1)))

                Button(action: saveHealth) {
                    Text(saved ? "已保存" : "保存")
                        .font(.system(size: PLOS.FontScale.button, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: PLOS.Size.primaryButtonHeight)
                        .background(RoundedRectangle(cornerRadius: PLOS.Radius.pill)
                            .fill(saved ? PLOS.Palette.g300 : PLOS.Palette.g500))
                }
                .disabled(saved)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
        }
        .background(PLOS.Palette.paper)
        .navigationTitle("健康")
    }

    private func saveHealth() {
        vm.updateHealth(exercisedToday: exercisedToday, lateNights7d: lateNightsThisWeek)
        saved = true
    }
}

// MARK: - Health extension on AppViewModel

extension AppViewModel {
    func updateHealth(exercisedToday: Bool, lateNights7d: Int) {
        // Lightweight manual data — UserDefaults, not SwiftData.
        let defaults = UserDefaults.standard
        if exercisedToday {
            // Kernel-canonical day (midnight UTC of the local calendar day) so the
            // kernel's "days since exercise" math is exact across time zones.
            let canonical = RestSchedule.canonicalDate(from: Date(), in: .current)
            defaults.set(canonical.timeIntervalSince1970, forKey: "health_last_exercise")
        }
        defaults.set(lateNights7d, forKey: "health_late_nights_7d")
    }

    /// Assemble a Health struct from stored manual data, for kernel consumption.
    func currentHealth() -> PLOSKernel.Health {
        let defaults = UserDefaults.standard
        let exerciseTS = defaults.double(forKey: "health_last_exercise")
        let lastExercise: Date? = exerciseTS > 0 ? Date(timeIntervalSince1970: exerciseTS) : nil
        let lateNights = defaults.integer(forKey: "health_late_nights_7d")
        return PLOSKernel.Health(lastExercise: lastExercise, lateNights7d: lateNights, highPressureStreak: 0)
    }
}

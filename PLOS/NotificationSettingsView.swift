import SwiftUI

// MARK: - §5.7: Notification time settings (morning plan / evening report)

/// Times are stored in UserDefaults and re-applied through NotificationManager.updateSchedule.
struct NotificationSettingsView: View {
    @AppStorage("notify_morning_enabled") private var morningEnabled = true
    @AppStorage("notify_morning_hour") private var morningHour = 8
    @AppStorage("notify_morning_minute") private var morningMinute = 0
    @AppStorage("notify_evening_enabled") private var eveningEnabled = true
    @AppStorage("notify_evening_hour") private var eveningHour = 21
    @AppStorage("notify_evening_minute") private var eveningMinute = 30

    var body: some View {
        List {
            Section {
                Toggle("早晨提醒", isOn: $morningEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: PLOS.Palette.g500))
                if morningEnabled {
                    DatePicker("时间", selection: morningBinding, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("生成今日计划")
            } footer: {
                Text("早上提醒你打开 PLOS，选能量、看今天学什么。")
            }

            Section {
                Toggle("晚间提醒", isOn: $eveningEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: PLOS.Palette.g500))
                if eveningEnabled {
                    DatePicker("时间", selection: eveningBinding, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("一分钟汇报今天")
            } footer: {
                Text("睡前拖动滑块汇报，全 0% 也算系统在运行。")
            }
        }
        .navigationTitle("提醒设置")
        .onChange(of: morningEnabled) { apply() }
        .onChange(of: eveningEnabled) { apply() }
        .onChange(of: morningHour) { apply() }
        .onChange(of: morningMinute) { apply() }
        .onChange(of: eveningHour) { apply() }
        .onChange(of: eveningMinute) { apply() }
    }

    private var morningBinding: Binding<Date> {
        timeBinding(hour: $morningHour, minute: $morningMinute)
    }

    private var eveningBinding: Binding<Date> {
        timeBinding(hour: $eveningHour, minute: $eveningMinute)
    }

    /// Bridge (hour, minute) integers to the DatePicker's Date value.
    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                var comp = DateComponents()
                comp.hour = hour.wrappedValue
                comp.minute = minute.wrappedValue
                return Calendar.current.date(from: comp) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                hour.wrappedValue = c.hour ?? 8
                minute.wrappedValue = c.minute ?? 0
            }
        )
    }

    private func apply() {
        NotificationManager.shared.updateSchedule(
            morningHour: morningHour, morningMinute: morningMinute,
            eveningHour: eveningHour, eveningMinute: eveningMinute,
            morningEnabled: morningEnabled, eveningEnabled: eveningEnabled
        )
    }
}

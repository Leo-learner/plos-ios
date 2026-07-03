import SwiftUI
import SwiftData
import PLOSKernel

// MARK: - §P.2: Exam Event Input + Kernel Rule Verification

struct EventsView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var showAdd = false

    var events: [EventEntity] { vm.activeMonth?.events ?? [] }

    var body: some View {
        List {
            if events.isEmpty {
                Text("还没有考试事件。添加后，内核考前规则（§1.6）会自动在考试前一天安排只复习、不上新内容。")
                    .font(.system(size: 13))
                    .foregroundColor(PLOS.Palette.ink3)
            }
            ForEach(events, id: \.persistentModelID) { event in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.subject).font(.system(size: 15, weight: .bold))
                            .foregroundColor(PLOS.Palette.ink)
                        Text(event.date).font(.system(size: 13, design: .rounded))
                            .foregroundColor(PLOS.Palette.ink3)
                    }
                    Spacer()
                    Text("考试")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: 0x436670))
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: PLOS.Radius.pill).fill(PLOS.Palette.slateBg))
                }
            }
            .onDelete(perform: deleteEvents)
        }
        .navigationTitle("考试事件")
        .toolbar {
            Button("添加") { showAdd = true }
        }
        .sheet(isPresented: $showAdd) {
            AddEventSheet { subject, dateStr in
                vm.addEvent(subject: subject, dateStr: dateStr)
            }
        }
    }

    private func deleteEvents(at offsets: IndexSet) {
        guard let ctx = vm.modelContext else { return }
        for idx in offsets {
            ctx.delete(events[idx])
        }
        try? ctx.save()
    }
}

struct AddEventSheet: View {
    let onAdd: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("科目（如 高数）", text: $subject)
                DatePicker("考试日期", selection: $date, displayedComponents: .date)
            }
            .navigationTitle("添加考试")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                        onAdd(subject, fmt.string(from: date))
                        dismiss()
                    }.disabled(subject.isEmpty)
                }
            }
        }
    }
}

// MARK: - Event helpers on AppViewModel

extension AppViewModel {
    func addEvent(subject: String, dateStr: String) {
        guard let month = activeMonth, let ctx = modelContext else { return }
        let event = EventEntity(eventType: "exam", subject: subject, date: dateStr)
        event.month = month
        ctx.insert(event)
        month.events.append(event)
        try? ctx.save()
    }
}

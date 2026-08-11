import SwiftUI

struct AddScheduleBlockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileStore.self) private var profileStore
    @Environment(ScheduleStore.self) private var scheduleStore
    @Environment(ToastCenter.self) private var toastCenter

    @State private var title = ""
    @State private var kind: ScheduleBlock.Kind = .away
    @State private var isRecurring = true
    @State private var selectedDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var oneOffDate = Date()
    @State private var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("What's happening") {
                    TextField("e.g. Chem lecture", text: $title)
                    Picker("Type", selection: $kind) {
                        Text("I'm away").tag(ScheduleBlock.Kind.away)
                        Text("I'm in the room").tag(ScheduleBlock.Kind.inRoom)
                    }
                    .pickerStyle(.segmented)
                }

                Section("When") {
                    Toggle("Repeats weekly", isOn: $isRecurring)
                    if isRecurring {
                        WeekdaySelector(selectedDays: $selectedDays)
                    } else {
                        DatePicker("Date", selection: $oneOffDate, displayedComponents: .date)
                    }
                    DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                    if endTime <= startTime {
                        Text("End time needs to be after the start time.")
                            .font(.shortyCaption)
                            .foregroundStyle(DukeTheme.occupied)
                    }
                }
            }
            .shortyBackground()
            .scrollContentBackground(.hidden)
            .navigationTitle("Add to Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .disabled(isSaving || (isRecurring && selectedDays.isEmpty) || endTime <= startTime)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        var block = ScheduleBlock.draft(owner: profileStore.profile.myName)
        block.title = title
        block.kind = kind
        let calendar = Calendar.current
        block.startTime = DateComponents(hour: calendar.component(.hour, from: startTime), minute: calendar.component(.minute, from: startTime))
        block.endTime = DateComponents(hour: calendar.component(.hour, from: endTime), minute: calendar.component(.minute, from: endTime))
        if isRecurring {
            block.recurringWeekdays = selectedDays
            block.date = nil
        } else {
            block.date = oneOffDate
            block.recurringWeekdays = []
        }
        Task {
            await scheduleStore.save(block)
            isSaving = false
            Haptics.success()
            toastCenter.show("Added to schedule")
            dismiss()
        }
    }
}

private struct WeekdaySelector: View {
    @Binding var selectedDays: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                let isSelected = selectedDays.contains(day)
                Button {
                    Haptics.tap()
                    if isSelected { selectedDays.remove(day) } else { selectedDays.insert(day) }
                } label: {
                    Text(day.short.prefix(1))
                        .font(.shortyCaption.bold())
                        .frame(width: 32, height: 32)
                        .foregroundStyle(isSelected ? .white : DukeTheme.dukeBlue)
                        .background(isSelected ? DukeTheme.dukeBlue : DukeTheme.dukeBlue.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullName)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }
}

import SwiftUI

/// Proposes a recurring, ask-once room slot. The roommate approves it a single time in
/// the Schedule tab, and after that it just repeats -- the whole point being to remove
/// the need to ask at all for predictable, recurring time.
struct ProposeStandingArrangementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileStore.self) private var profileStore
    @Environment(StandingArrangementStore.self) private var standingStore
    @Environment(ToastCenter.self) private var toastCenter

    @State private var title = ""
    @State private var purpose: Purpose = .study
    @State private var selectedDays: Set<Weekday> = []
    @State private var startTime = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Once your roommate approves this, it repeats automatically every week -- neither of you needs to ask again.")
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.inkMuted)
                }

                Section("What's it for?") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Purpose.visibleCases) { option in
                            Button {
                                Haptics.tap()
                                purpose = option
                            } label: {
                                PurposeChip(purpose: option, isSelected: purpose == option)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    TextField("Title (optional)", text: $title)
                }

                Section("Which days") {
                    ProposalWeekdaySelector(selectedDays: $selectedDays)
                }

                Section("Time") {
                    DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                    if endTime <= startTime {
                        Text("End time needs to be after the start time.")
                            .font(.shortyCaption)
                            .foregroundStyle(DukeTheme.occupied)
                    }
                }
            }
            .navigationTitle("Propose Standing Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Sending…" : "Send") { send() }
                        .disabled(isSaving || selectedDays.isEmpty || endTime <= startTime)
                }
            }
        }
    }

    private func send() {
        guard let roommate = profileStore.profile.roommateName else { return }
        isSaving = true
        var arrangement = StandingArrangement.draft(owner: profileStore.profile.myName, other: roommate)
        arrangement.title = title
        arrangement.purpose = purpose
        arrangement.weekdays = selectedDays
        let calendar = Calendar.current
        arrangement.startTime = DateComponents(hour: calendar.component(.hour, from: startTime), minute: calendar.component(.minute, from: startTime))
        arrangement.endTime = DateComponents(hour: calendar.component(.hour, from: endTime), minute: calendar.component(.minute, from: endTime))
        Task {
            await standingStore.propose(arrangement)
            isSaving = false
            Haptics.success()
            toastCenter.show("Proposal sent to \(roommate)")
            dismiss()
        }
    }
}

private struct ProposalWeekdaySelector: View {
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

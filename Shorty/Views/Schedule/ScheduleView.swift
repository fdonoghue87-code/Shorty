import SwiftUI

struct ScheduleView: View {
    @Environment(ScheduleStore.self) private var scheduleStore
    @Environment(ProfileStore.self) private var profileStore

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Recurring blocks help you both see, at a glance, when the room is naturally free or spoken for — so a rental request is only needed when it's actually needed.")
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.inkMuted)
                }
                .listRowSeparator(.hidden)

                ForEach(Weekday.allCases) { day in
                    let dayBlocks = blocks(for: day)
                    if !dayBlocks.isEmpty {
                        Section(day.fullName) {
                            ForEach(dayBlocks) { block in
                                ScheduleBlockDetailRow(block: block)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            Task { await scheduleStore.delete(block) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }

                let oneOffs = scheduleStore.blocks.filter { $0.date != nil }.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
                if !oneOffs.isEmpty {
                    Section("One-time") {
                        ForEach(oneOffs) { block in
                            ScheduleBlockDetailRow(block: block)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task { await scheduleStore.delete(block) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                if scheduleStore.blocks.isEmpty {
                    EmptyStateView(systemImage: "calendar.badge.plus", title: "No schedule yet", message: "Add your class times or predictable in-room hours so your roommate always knows the lay of the week.")
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .shortyBackground()
            .scrollContentBackground(.hidden)
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await scheduleStore.refresh() }
            .sheet(isPresented: $showingAdd) {
                AddScheduleBlockView()
            }
        }
    }

    private func blocks(for day: Weekday) -> [ScheduleBlock] {
        scheduleStore.blocks
            .filter { $0.date == nil && $0.recurringWeekdays.contains(day) }
            .sorted { ($0.startTime?.hour ?? 0, $0.startTime?.minute ?? 0) < ($1.startTime?.hour ?? 0, $1.startTime?.minute ?? 0) }
    }
}

private extension Weekday {
    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

struct ScheduleBlockDetailRow: View {
    let block: ScheduleBlock

    var body: some View {
        HStack {
            Image(systemName: block.kind == .away ? "figure.walk.motion" : "person.fill")
                .foregroundStyle(DukeTheme.dukeBlue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title.isEmpty ? (block.kind == .away ? "Away" : "In the room") : block.title)
                    .font(.shortyBody)
                Text("\(block.ownerName) · \(timeRange)")
                    .font(.shortyCaption)
                    .foregroundStyle(DukeTheme.inkMuted)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var timeRange: String {
        guard let start = block.startTime, let end = block.endTime else { return "" }
        return "\(time(start)) – \(time(end))"
    }

    private func time(_ components: DateComponents) -> String {
        var calendarComponents = DateComponents()
        calendarComponents.hour = components.hour
        calendarComponents.minute = components.minute
        let date = Calendar.current.date(from: calendarComponents) ?? Date()
        return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }
}

import SwiftUI

struct ScheduleView: View {
    @Environment(ScheduleStore.self) private var scheduleStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(StandingArrangementStore.self) private var standingStore
    @Environment(SubscriptionStore.self) private var subscriptionStore

    @State private var showingAdd = false
    @State private var showingImport = false
    @State private var showingProposeStanding = false
    @State private var showingPaywall = false
    @State private var selectedDate = Date()

    private static let freeStandingLimit = 1
    private static let freePhotoImportLimit = 3

    private var hasReachedStandingLimit: Bool {
        guard !subscriptionStore.isPlus else { return false }
        let mine = standingStore.arrangements.filter {
            $0.ownerName == profileStore.profile.myName && ($0.status == .active || $0.status == .pending)
        }
        return mine.count >= Self.freeStandingLimit
    }

    private var hasReachedImportLimit: Bool {
        !subscriptionStore.isPlus && profileStore.profile.photoImportsUsedCount >= Self.freePhotoImportLimit
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Recurring blocks help you both see, at a glance, when the room is naturally free or spoken for — so a request is only needed when it's actually needed.")
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.inkMuted)
                }
                .listRowSeparator(.hidden)

                Section {
                    if todaysBlocks.isEmpty {
                        Text("Nothing scheduled today.")
                            .font(.shortyCaption)
                            .foregroundStyle(DukeTheme.inkMuted)
                    } else {
                        ForEach(todaysBlocks) { block in
                            ScheduleBlockDetailRow(block: block)
                        }
                    }
                } header: {
                    Text("Today, \(todayDateLabel)")
                }

                let standingToShow = standingStore.pending + standingStore.active
                if !standingToShow.isEmpty {
                    Section {
                        ForEach(standingToShow) { arrangement in
                            StandingArrangementRow(
                                arrangement: arrangement,
                                myName: profileStore.profile.myName,
                                onAccept: { Task { await standingStore.accept(arrangement) } },
                                onDecline: { Task { await standingStore.decline(arrangement) } },
                                onCancel: { Task { await standingStore.cancel(arrangement) } }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("Standing Arrangements")
                    } footer: {
                        Text("Approved once, these repeat automatically — no need to ask again.")
                    }
                }

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

                Section {
                    DatePicker("Selected day", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(DukeTheme.dukeBlue)

                    let dayBlocks = scheduleStore.status(at: selectedDate)
                    if dayBlocks.isEmpty {
                        Text("Nothing scheduled on \(selectedDateLabel).")
                            .font(.shortyCaption)
                            .foregroundStyle(DukeTheme.inkMuted)
                    } else {
                        ForEach(dayBlocks) { block in
                            ScheduleBlockDetailRow(block: block)
                        }
                    }
                } header: {
                    Text("Browse a Different Day")
                } footer: {
                    Text(selectedDateLabel)
                }
            }
            .listStyle(.plain)
            .shortyBackground()
            .scrollContentBackground(.hidden)
            .shortyHeader("Schedule")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAdd = true
                        } label: {
                            Label("Add Manually", systemImage: "pencil")
                        }
                        Button {
                            if hasReachedImportLimit {
                                showingPaywall = true
                            } else {
                                showingImport = true
                            }
                        } label: {
                            Label("Import from Photo", systemImage: "camera.viewfinder")
                        }
                        Button {
                            if hasReachedStandingLimit {
                                showingPaywall = true
                            } else {
                                showingProposeStanding = true
                            }
                        } label: {
                            Label("Propose Standing Time", systemImage: "repeat")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add to schedule")
                }
            }
            .refreshable {
                await scheduleStore.refresh()
                await standingStore.refresh()
            }
            .task {
                await standingStore.refresh()
            }
            .sheet(isPresented: $showingAdd) {
                AddScheduleBlockView()
            }
            .sheet(isPresented: $showingImport) {
                ImportScheduleView()
            }
            .sheet(isPresented: $showingProposeStanding) {
                ProposeStandingArrangementView()
            }
            .sheet(isPresented: $showingPaywall) {
                SubscriptionView()
            }
        }
    }

    private var todaysBlocks: [ScheduleBlock] {
        scheduleStore.status(at: Date())
    }

    private var todayDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date())
    }

    private var selectedDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }

    private func blocks(for day: Weekday) -> [ScheduleBlock] {
        scheduleStore.blocks
            .filter { $0.date == nil && $0.recurringWeekdays.contains(day) }
            .sorted { ($0.startTime?.hour ?? 0, $0.startTime?.minute ?? 0) < ($1.startTime?.hour ?? 0, $1.startTime?.minute ?? 0) }
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

struct StandingArrangementRow: View {
    let arrangement: StandingArrangement
    let myName: String
    var onAccept: (() -> Void)?
    var onDecline: (() -> Void)?
    var onCancel: (() -> Void)?

    var body: some View {
        ShortyCard {
            HStack {
                Image(systemName: "repeat")
                    .foregroundStyle(DukeTheme.dukeBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(arrangement.title.isEmpty ? arrangement.purpose.label : arrangement.title)
                        .font(.shortyHeadline)
                    Text("\(daysLabel) · \(timeRange) · \(arrangement.ownerName)")
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.inkMuted)
                }
                Spacer()
            }

            if arrangement.status == .pending {
                if arrangement.otherName == myName {
                    HStack(spacing: 10) {
                        PrimaryButton(title: "Accept", systemImage: "checkmark") { onAccept?() }
                        SecondaryButton(title: "Decline", systemImage: "xmark") { onDecline?() }
                    }
                } else {
                    Text("Waiting for \(arrangement.otherName) to accept")
                        .font(.shortyCaption)
                        .foregroundStyle(DukeTheme.pending)
                }
            } else if arrangement.status == .active, arrangement.ownerName == myName {
                SecondaryButton(title: "Cancel Standing Time", systemImage: "xmark.circle") { onCancel?() }
            }
        }
    }

    private var daysLabel: String {
        Weekday.allCases.filter { arrangement.weekdays.contains($0) }.map(\.code).joined()
    }

    private var timeRange: String {
        "\(time(arrangement.startTime)) – \(time(arrangement.endTime))"
    }

    private func time(_ components: DateComponents) -> String {
        var calendarComponents = DateComponents()
        calendarComponents.hour = components.hour
        calendarComponents.minute = components.minute
        let date = Calendar.current.date(from: calendarComponents) ?? Date()
        return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }
}

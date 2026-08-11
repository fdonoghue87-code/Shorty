import PhotosUI
import SwiftUI
import UIKit

/// Lets a roommate snap or pick a photo of their class schedule and have Shorty try to
/// pull out day/time blocks automatically. Detected entries always land in an editable
/// review list -- OCR plus free-form schedule layouts is too unreliable to trust blindly,
/// so nothing saves until the roommate confirms it. Saved blocks go through the normal
/// ScheduleStore, so they sync to both roommates the same as a manually added block.
struct ImportScheduleView: View {
    private enum Stage: Equatable {
        case pickSource
        case scanning
        case reviewing
        case failed(String)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(ProfileStore.self) private var profileStore
    @Environment(ScheduleStore.self) private var scheduleStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(ToastCenter.self) private var toastCenter

    @State private var stage: Stage = .pickSource
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var entries: [DetectedScheduleEntry] = []
    @State private var kind: ScheduleBlock.Kind = .away
    @State private var isSaving = false

    private var cameraIsAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import Schedule")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    if stage == .reviewing {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(isSaving ? "Saving…" : "Save") { save() }
                                .disabled(isSaving || !entries.contains { $0.isIncluded })
                        }
                    }
                }
                .sheet(isPresented: $showingCamera) {
                    CameraCaptureView { image in
                        showingCamera = false
                        if let image { scan(image) }
                    }
                    .ignoresSafeArea()
                }
                .onChange(of: photosPickerItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            scan(image)
                        } else {
                            stage = .failed("Couldn't read that photo. Try again or pick a different one.")
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .pickSource:
            pickSourceView
        case .scanning:
            VStack(spacing: 16) {
                ProgressView()
                Text("Reading your schedule…")
                    .font(.shortyBody)
                    .foregroundStyle(DukeTheme.inkMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shortyBackground()
        case .reviewing:
            reviewView
        case .failed(let message):
            VStack(spacing: 16) {
                EmptyStateView(systemImage: "text.magnifyingglass", title: "Nothing found", message: message)
                SecondaryButton(title: "Try Another Photo", systemImage: "arrow.counterclockwise") {
                    stage = .pickSource
                }
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shortyBackground()
        }
    }

    private var pickSourceView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 44))
                    .foregroundStyle(DukeTheme.dukeBlue)

                Text("Pull your schedule in automatically instead of typing it block by block.")
                    .font(.shortyBody)
                    .foregroundStyle(DukeTheme.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                PrimaryButton(title: "Import from Calendar", systemImage: "calendar.badge.clock") {
                    importFromCalendar()
                }
                .padding(.horizontal, 20)

                Text("Works with any calendar already synced to your phone -- Google, Outlook, iCloud -- through the Calendar app. Classes and other repeating events come in automatically; one-off events are skipped.")
                    .font(.shortyCaption)
                    .foregroundStyle(DukeTheme.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack {
                    Rectangle().fill(DukeTheme.divider).frame(height: 1)
                    Text("or").font(.shortyCaption).foregroundStyle(DukeTheme.inkMuted)
                    Rectangle().fill(DukeTheme.divider).frame(height: 1)
                }
                .padding(.horizontal, 40)

                Text("Snap a photo of a printed or on-screen class schedule instead -- it's read by Shorty's AI-powered backend for better accuracy on messy table layouts.")
                    .font(.shortyCaption)
                    .foregroundStyle(DukeTheme.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if cameraIsAvailable {
                    SecondaryButton(title: "Take Photo", systemImage: "camera.fill") {
                        showingCamera = true
                    }
                    .padding(.horizontal, 20)
                }

                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    Text("Choose from Library")
                        .font(.shortyHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(DukeTheme.dukeBlue)
                        .background(DukeTheme.dukeBlue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: DukeTheme.controlCornerRadius, style: .continuous))
                }
                .padding(.horizontal, 20)

                Text("Whichever way it comes in, you'll review and can edit everything before anything is saved.")
                    .font(.shortyCaption)
                    .foregroundStyle(DukeTheme.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .shortyBackground()
    }

    private var reviewView: some View {
        List {
            Section {
                Picker("Type", selection: $kind) {
                    Text("Away").tag(ScheduleBlock.Kind.away)
                    Text("In the room").tag(ScheduleBlock.Kind.inRoom)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Found \(entries.filter(\.isIncluded).count) of \(entries.count) — uncheck anything that's wrong")
            }

            ForEach($entries) { $entry in
                DetectedEntryRow(entry: $entry)
            }
        }
        .listStyle(.plain)
        .shortyBackground()
        .scrollContentBackground(.hidden)
    }

    private func importFromCalendar() {
        stage = .scanning
        Task {
            do {
                try await CalendarImportService.requestAccess()
                let detected = try await CalendarImportService.detectRecurringEntries()
                if detected.isEmpty {
                    stage = .failed("Didn't find any repeating events in your calendar over the next 8 weeks. One-off events are skipped on purpose -- only things that happen more than once count as a predictable schedule. Try a photo instead, or add times manually.")
                } else {
                    entries = detected
                    stage = .reviewing
                }
            } catch CalendarImportService.ImportError.accessDenied {
                stage = .failed("Shorty needs Calendar access to import your schedule this way. You can allow it under Settings → Shorty → Calendars, then try again.")
            } catch {
                stage = .failed("Something went wrong reading your calendar: \(error.localizedDescription)")
            }
        }
    }

    /// Every photo is routed to Shorty's AI-powered backend first, for meaningfully better
    /// accuracy on messy table layouts; if the network or the backend has a bad moment, it
    /// falls back to the free, fully on-device Vision parser instead. Nobody ever sees an
    /// outright failure just because the smarter path had a hiccup.
    private func scan(_ image: UIImage) {
        stage = .scanning
        Task {
            do {
                var detected = (try? await SmartScheduleImportService.detectEntries(in: image)) ?? []
                if detected.isEmpty {
                    let lines = try ScheduleImportService.recognizeText(in: image)
                    detected = ScheduleImportService.parse(lines: lines)
                }
                if detected.isEmpty {
                    stage = .failed("Couldn't make out any day/time pairs in that photo. Try a clearer, well-lit shot, or add times manually instead.")
                } else {
                    entries = detected
                    stage = .reviewing
                }
            } catch {
                stage = .failed("Something went wrong reading that photo: \(error.localizedDescription)")
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            var savedCount = 0
            for entry in entries where entry.isIncluded {
                var block = ScheduleBlock.draft(owner: profileStore.profile.myName)
                block.title = entry.title
                block.kind = kind
                block.recurringWeekdays = entry.weekdays
                block.startTime = entry.startTime
                block.endTime = entry.endTime
                await scheduleStore.save(block)
                savedCount += 1
            }
            if !subscriptionStore.isPlus {
                profileStore.profile.photoImportsUsedCount += 1
            }
            isSaving = false
            Haptics.success()
            toastCenter.show(savedCount == 1 ? "1 block added" : "\(savedCount) blocks added")
            dismiss()
        }
    }
}

private struct DetectedEntryRow: View {
    @Binding var entry: DetectedScheduleEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                entry.isIncluded.toggle()
            } label: {
                Image(systemName: entry.isIncluded ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(entry.isIncluded ? DukeTheme.dukeBlue : DukeTheme.inkMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.isIncluded ? "Included, tap to exclude" : "Excluded, tap to include")

            VStack(alignment: .leading, spacing: 4) {
                TextField("Title", text: $entry.title)
                    .font(.shortyBody)
                Text("\(daysLabel) · \(timeRangeLabel)")
                    .font(.shortyCaption)
                    .foregroundStyle(DukeTheme.inkMuted)
            }
        }
        .opacity(entry.isIncluded ? 1 : 0.4)
        .padding(.vertical, 4)
    }

    private var daysLabel: String {
        entry.weekdays.isEmpty
            ? "Day unclear"
            : Weekday.allCases.filter { entry.weekdays.contains($0) }.map(\.code).joined()
    }

    private var timeRangeLabel: String {
        "\(formatted(entry.startTime)) – \(formatted(entry.endTime))"
    }

    private func formatted(_ components: DateComponents) -> String {
        var calendarComponents = DateComponents()
        calendarComponents.hour = components.hour
        calendarComponents.minute = components.minute
        let date = Calendar.current.date(from: calendarComponents) ?? Date()
        return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }
}

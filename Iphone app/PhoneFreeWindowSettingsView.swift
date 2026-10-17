//
//  PhoneFreeWindowSettingsView.swift
//  Iphone app
//
//  Recurring phone-free windows: "no phone from 10pm to 7am", "no phone at
//  lunch". Each one is a *reminder*, not a lock — tapping it starts a goal.
//
//  Deliberately few controls. Windows are a way to cover the hours when
//  picking up the phone happens most, without asking anyone to decide anything
//  in the moment.
//

import SwiftUI

struct PhoneFreeWindowSettingsView: View {
    @Environment(PhoneFreeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var windows: [PhoneFreeWindow] = []
    @State private var showingEditor = false
    /// `nil` until the app has actually asked. Shown only once known, so the
    /// card never claims reminders are off before permission has been resolved.
    @State private var remindersOn: Bool?

    @State private var editedWindow = PhoneFreeWindow()
    @State private var editedIndex: Int?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    explainer

                    if let on = remindersOn {
                        reminderStatus(remindersOn: on)
                    }

                    if windows.isEmpty {
                        emptyState
                    }

                    ForEach(Array(windows.enumerated()), id: \.element.id) {
                        index, window in
                        windowCard(window, at: index)
                    }

                    addButtons
                }
                .padding(PhoneFreeTheme.screenPadding)
            }
            .background(PhoneFreeTheme.background)
            .navigationTitle("Phone-free windows")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Ask here, rather than at launch, so the permission prompt
                // sits next to an explanation of what it is for.
                if windows.isEmpty { windows = store.windows }

                _ = await PhoneFreeWindowScheduler.shared.requestAuthorization()
                let status =
                    await PhoneFreeWindowScheduler.shared.authorizationStatus()
                remindersOn = status == .authorized || status == .provisional
                PhoneFreeWindowScheduler.shared.reschedule(windows)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PhoneFreeTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if windows.isEmpty {
                windows = store.windows
            }
        }
        .onChange(of: windows) { _, updated in
            store.windows = updated
            store.save()
            PhoneFreeWindowScheduler.shared.reschedule(updated)
        }
        .sheet(isPresented: $showingEditor) {
            windowEditor
        }
    }

    // MARK: - Pieces

    private var explainer: some View {
        PhoneFreeCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("A reminder, not a lock")
                    .scaledFont(14, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(.white)

                Text(
                    "Each window reminds you when its time comes, every day. "
                    + "Tap the reminder to start a goal right away. The app "
                    + "does not block anything itself — the next step for "
                    + "that is Screen Time."
                )
                .font(.caption)
                .foregroundStyle(PhoneFreeTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func reminderStatus(remindersOn: Bool) -> some View {
        PhoneFreeCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: remindersOn ? "checkmark.circle" : "bell.slash")
                    .font(.subheadline)
                    .foregroundStyle(
                        remindersOn
                        ? PhoneFreeTheme.accent
                        : PhoneFreeTheme.muted
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(remindersOn ? "Reminders are on" : "Reminders are off")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(
                        remindersOn
                            ? "Every enabled window will remind you when it "
                              + "starts."
                            : "Allow notifications for PhoneFree if you want "
                              + "windows to remind you. You can change this "
                              + "any time in iOS Settings."
                    )
                    .font(.caption)
                    .foregroundStyle(PhoneFreeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var emptyState: some View {
        PhoneFreeCard {
            Text(
                "No windows yet. Add one below — evening wind-down and lunch "
                + "are the usual starting points."
            )
            .font(.footnote)
            .foregroundStyle(PhoneFreeTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func windowCard(
        _ window: PhoneFreeWindow,
        at index: Int
    ) -> some View {
        PhoneFreeCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.subheadline)
                        .foregroundStyle(
                            window.enabled ? PhoneFreeTheme.accent : PhoneFreeTheme.muted
                        )

                    Text(window.label.isEmpty ? "Phone-free window" : window.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { windows[index].enabled },
                        set: { enabled in
                            windows[index].enabled = enabled
                            windows = windows
                        }
                    ))
                    .labelsHidden()
                    .tint(PhoneFreeTheme.accent)
                }

                HStack(spacing: 8) {
                    ForEach(["sunset", "sunrise"], id: \.self) { symbol in
                        Image(systemName: symbol)
                            .font(.caption2)
                            .foregroundStyle(PhoneFreeTheme.muted)
                    }

                    Text(window.summary)
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(PhoneFreeTheme.muted)
                }

                if !window.enabled {
                    Text("Off — no reminder will be sent.")
                        .font(.caption2)
                        .foregroundStyle(PhoneFreeTheme.muted.opacity(0.8))
                }

                PhoneFreeAdaptiveStack(spacing: 8) {
                    PhoneFreeSecondaryButton(
                        title: "Edit",
                        symbol: "pencil"
                    ) {
                        editedWindow = window
                        editedIndex = index
                        showingEditor = true
                    }

                    PhoneFreeSecondaryButton(
                        title: "Delete",
                        symbol: "trash",
                        tint: PhoneFreeTheme.caution
                    ) {
                        windows.remove(at: index)
                        windows = windows
                    }
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize ? nil : 110
                    )
                }
            }
        }
    }

    private var addButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhoneFreeSectionLabel("ADD A WINDOW")

            PhoneFreeSecondaryButton(
                title: "Evening wind-down · 22:00 – 07:00",
                symbol: "moon"
            ) {
                windows.append(
                    PhoneFreeWindow(
                        label: "Evening wind-down",
                        startHour: 22,
                        startMinute: 0,
                        endHour: 7,
                        endMinute: 0
                    )
                )
                windows = windows
            }

            PhoneFreeSecondaryButton(
                title: "Lunch · 12:30 – 13:15",
                symbol: "fork.knife"
            ) {
                windows.append(
                    PhoneFreeWindow(
                        label: "Lunch",
                        startHour: 12,
                        startMinute: 30,
                        endHour: 13,
                        endMinute: 15
                    )
                )
                windows = windows
            }

            PhoneFreeSecondaryButton(title: "Custom window", symbol: "plus") {
                editedWindow = PhoneFreeWindow(label: "")
                editedIndex = nil
                showingEditor = true
            }
        }
    }

    // MARK: - Editor

    private var windowEditor: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("Evening wind-down", text: $editedWindow.label)
                        .autocorrectionDisabled()
                }

                Section("Start") {
                    DatePicker(
                        "Starts at",
                        selection: Binding(
                            get: { startDate(for: editedWindow) },
                            set: { editedWindow.startHour = hour($0); editedWindow.startMinute = minute($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                Section("End") {
                    DatePicker(
                        "Ends at",
                        selection: Binding(
                            get: { endDate(for: editedWindow) },
                            set: { editedWindow.endHour = hour($0); editedWindow.endMinute = minute($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                Section {
                    Text(editedWindow.isOvernight
                         ? "Runs overnight, ending the next morning."
                         : "Starts and ends on the same day.")
                        .font(.caption)
                        .foregroundStyle(PhoneFreeTheme.muted)
                } footer: {
                    Text("Example: 22:00 to 07:00 is overnight, so it is counted "
                         + "as running from tonight until morning.")
                        .font(.caption2)
                        .foregroundStyle(PhoneFreeTheme.muted.opacity(0.8))
                }
            }
            .navigationTitle(editedIndex == nil ? "Add window" : "Edit window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWindow()
                        showingEditor = false
                    }
                    .foregroundStyle(PhoneFreeTheme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveWindow() {
        if let index = editedIndex {
            windows[index] = editedWindow
        } else {
            windows.append(editedWindow)
        }
        windows = windows
    }

    // MARK: - Date helpers

    private func startDate(for window: PhoneFreeWindow) -> Date {
        Calendar.current.date(
            bySettingHour: window.startHour,
            minute: window.startMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func endDate(for window: PhoneFreeWindow) -> Date {
        Calendar.current.date(
            bySettingHour: window.endHour,
            minute: window.endMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func hour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    private func minute(_ date: Date) -> Int {
        Calendar.current.component(.minute, from: date)
    }
}

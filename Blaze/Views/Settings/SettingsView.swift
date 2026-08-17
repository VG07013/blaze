import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(BlazeEngine.self) private var engine

    var body: some View {
        NavigationStack {
            ZStack {
                BlazeBackground()
                settingsForm
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
        }
    }

    private var settingsForm: some View {
        Form {
            healthSection
            remindersSection
            quietHoursSection
            feelSection
            appIconSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .font(.blazeBody)
    }

    // MARK: Sections

    private var healthSection: some View {
        Section {
            HStack {
                Label("Health access", systemImage: "heart.fill")
                Spacer()
                if engine.settings.healthKitAuthorized {
                    Text("Connected")
                        .foregroundStyle(BlazeTheme.success)
                } else {
                    Button("Connect") {
                        Task { await engine.requestHealthAccess() }
                    }
                }
            }
        } header: {
            Text("Health")
        } footer: {
            Text("Blaze reads steps, exercise minutes, stairs, calories, and mindful minutes to auto-verify quests. Read-only, on-device.")
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle("Notifications", isOn: binding(\.notificationsEnabled))
                .onChange(of: engine.settings.notificationsEnabled) { _, isOn in
                    if isOn {
                        Task { _ = await engine.requestNotificationAccess() }
                    }
                    engine.rescheduleNotifications()
                }

            if engine.settings.notificationsEnabled {
                DatePicker("Morning nudge", selection: minutesBinding(\.reminderMinutes),
                           displayedComponents: .hourAndMinute)
                Toggle("Midday check-in", isOn: binding(\.middayEnabled))
                Toggle("Evening warning", isOn: binding(\.eveningEnabled))
                Toggle("Last-chance alert", isOn: binding(\.lastChanceEnabled))
                Toggle("Freeze & burnout alerts", isOn: binding(\.freezeAlertsEnabled))
                Toggle("Milestone celebrations", isOn: binding(\.milestoneEnabled))
                Toggle("Comeback nudges", isOn: binding(\.comebackEnabled))
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("All in Blaze's voice, never spammy. If notifications are off, the widget still keeps score.")
        }
    }

    @ViewBuilder
    private var quietHoursSection: some View {
        if engine.settings.notificationsEnabled {
            Section {
                DatePicker("Start", selection: minutesBinding(\.quietStartMinutes),
                           displayedComponents: .hourAndMinute)
                DatePicker("End", selection: minutesBinding(\.quietEndMinutes),
                           displayedComponents: .hourAndMinute)
            } header: {
                Text("Quiet hours")
            } footer: {
                Text("Blaze stays silent in this window. Overnight alerts wait until quiet hours end.")
            }
        }
    }

    private var feelSection: some View {
        Section("Feel") {
            Toggle("Sounds", isOn: binding(\.soundEnabled))
            Toggle("Haptics", isOn: binding(\.hapticsEnabled))
        }
    }

    private var appIconSection: some View {
        Section {
            ForEach(engine.cosmetics(in: .appIcon), id: \.itemID) { item in
                appIconRow(item)
            }
        } header: {
            Text("App icon")
        } footer: {
            Text("New icons unlock at streak milestones.")
        }
    }

    private func appIconRow(_ item: CosmeticItem) -> some View {
        HStack {
            Text(item.name)
            Spacer()
            if engine.isEquipped(item) {
                Image(systemName: "checkmark")
                    .foregroundStyle(BlazeTheme.success)
            } else if item.owned {
                Button("Use") { engine.equip(item) }
            } else {
                Text(item.unlockDescription)
                    .font(.blazeCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Label("Everything stays on this device", systemImage: "lock.fill")
            LabeledContent("Version", value: "1.0")
        } footer: {
            Text("No accounts, no cloud, no ads. Just you and a very needy phoenix.")
        }
    }

    // MARK: Bindings

    private func binding(_ keyPath: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { engine.settings[keyPath: keyPath] },
            set: { newValue in
                engine.settings[keyPath: keyPath] = newValue
                engine.rescheduleNotifications()
            }
        )
    }

    private func minutesBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = engine.settings[keyPath: keyPath]
                return Calendar.current.date(
                    bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now
                ) ?? .now
            },
            set: { newDate in
                engine.settings[keyPath: keyPath] = newDate.minutesIntoDay
                engine.rescheduleNotifications()
            }
        )
    }
}

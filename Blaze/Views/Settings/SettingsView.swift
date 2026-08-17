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
        let settings = engine.settings
        return Form {
            // MARK: Health
            Section {
                HStack {
                    Label("Health access", systemImage: "heart.fill")
                    Spacer()
                    if settings.healthKitAuthorized {
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

            // MARK: Notifications
            Section {
                Toggle("Notifications", isOn: binding(\.notificationsEnabled))
                    .onChange(of: settings.notificationsEnabled) { _, on in
                        if on {
                            Task { _ = await engine.requestNotificationAccess() }
                        }
                        engine.rescheduleNotifications()
                    }

                if settings.notificationsEnabled {
                    DatePicker("Morning nudge", selection: reminderBinding,
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

            // MARK: Quiet hours
            if engine.settings.notificationsEnabled {
                Section {
                    DatePicker("Start", selection: quietBinding(\.quietStartMinutes),
                               displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: quietBinding(\.quietEndMinutes),
                               displayedComponents: .hourAndMinute)
                } header: {
                    Text("Quiet hours")
                } footer: {
                    Text("Blaze stays silent in this window. Overnight alerts wait until quiet hours end.")
                }
            }

            // MARK: Feel
            Section("Feel") {
                Toggle("Sounds", isOn: binding(\.soundEnabled))
                Toggle("Haptics", isOn: binding(\.hapticsEnabled))
            }

            // MARK: App icon
            Section {
                ForEach(engine.cosmetics(in: .appIcon), id: \.itemID) { item in
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
            } header: {
                Text("App icon")
            } footer: {
                Text("New icons unlock at streak milestones.")
            }

            // MARK: About
            Section {
                Label("Everything stays on this device", systemImage: "lock.fill")
                LabeledContent("Version", value: "1.0")
            } footer: {
                Text("No accounts, no cloud, no ads. Just you and a very needy phoenix.")
            }
        }
        .scrollContentBackground(.hidden)
        .font(.blazeBody)
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

    private var reminderBinding: Binding<Date> {
        minutesBinding(\.reminderMinutes)
    }

    private func quietBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, Int>) -> Binding<Date> {
        minutesBinding(keyPath)
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

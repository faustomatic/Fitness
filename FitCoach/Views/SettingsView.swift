import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            if let profile = appState.profile {
                Section("Profile") {
                    LabeledContent("Name", value: profile.name.isEmpty ? "—" : profile.name)
                    LabeledContent("Goal", value: profile.goal.label)
                    LabeledContent("Schedule", value: "\(profile.constraints.daysPerWeek)×/week · \(profile.constraints.minutesPerSession) min")
                    LabeledContent("Experience", value: profile.experience.label)
                    Text("Change any of these by telling the Coach — e.g. “switch my goal to fat loss” or “train 5 days a week”.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Check-in reminder") {
                    Picker("Day", selection: weekdayBinding) {
                        ForEach(1...7, id: \.self) { d in
                            Text(Calendar.current.weekdaySymbols[d - 1]).tag(d)
                        }
                    }
                    Picker("Hour", selection: hourBinding) {
                        ForEach(5...22, id: \.self) { Text("\($0):00").tag($0) }
                    }
                }

                Section("AI Coach") {
                    SecureField("Anthropic API key (optional)", text: apiKeyBinding)
                    Text("Without a key the coach still handles structured commands offline. With one, you get free-form conversations powered by Claude.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Plan") {
                Button("Regenerate plan from current settings") {
                    appState.regeneratePlan(reason: PlanRevision(prompt: "Manual regenerate from Settings", summary: "Plan rebuilt"))
                    appState.recalcNutrition()
                }
            }

            Section {
                Button("Reset all data", role: .destructive) {
                    showResetConfirm = true
                }
            } footer: {
                Text("FitCoach v0.1 — training data stays on your device (and your own iCloud backups). The only network call is the optional AI coach.")
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete profile, plan, logs, check-ins and imported data?",
                            isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { reset() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var weekdayBinding: Binding<Int> {
        Binding(get: { appState.profile?.checkInWeekday ?? 1 },
                set: { newValue in
                    appState.profile?.checkInWeekday = newValue
                    rescheduleReminders()
                })
    }

    private var hourBinding: Binding<Int> {
        Binding(get: { appState.profile?.checkInHour ?? 9 },
                set: { newValue in
                    appState.profile?.checkInHour = newValue
                    rescheduleReminders()
                })
    }

    private var apiKeyBinding: Binding<String> {
        Binding(get: { appState.profile?.anthropicAPIKey ?? "" },
                set: { appState.profile?.anthropicAPIKey = $0; appState.persist() })
    }

    private func rescheduleReminders() {
        guard let p = appState.profile else { return }
        NotificationService.scheduleCheckInReminder(weekday: p.checkInWeekday, hour: p.checkInHour)
        NotificationService.scheduleOverdueNudge(weekday: p.checkInWeekday, hour: p.checkInHour)
        appState.persist()
    }

    private func reset() {
        NotificationService.cancelAll()
        appState.profile = nil
        appState.plan = nil
        appState.nutrition = nil
        appState.sessions = []
        appState.snapshots = []
        appState.checkIns = []
        appState.chat = []
        appState.flags = []
        appState.persist()
    }
}

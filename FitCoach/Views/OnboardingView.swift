import SwiftUI

/// Multi-step questionnaire: biology → goal → experience → constraints →
/// lifestyle → data connections → review & generate.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 0
    @State private var draft = UserProfile()
    @State private var healthKitStatus: String?
    @State private var syncing = false

    private let totalSteps = 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: Double(totalSteps))
                    .padding(.horizontal)

                TabView(selection: $step) {
                    aboutYou.tag(0)
                    goalStep.tag(1)
                    experienceStep.tag(2)
                    constraintsStep.tag(3)
                    lifestyleStep.tag(4)
                    connectStep.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)

                HStack {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    if step < totalSteps - 1 {
                        Button("Next") { step += 1 }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Build My Plan") {
                            appState.completeOnboarding(draft)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Let's build your plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Steps

    private var aboutYou: some View {
        Form {
            Section("About you") {
                TextField("Name", text: $draft.name)
                Picker("Sex", selection: $draft.sex) {
                    ForEach(Sex.allCases) { Text($0.label).tag($0) }
                }
                DatePicker("Date of birth", selection: $draft.birthDate, displayedComponents: .date)
            }
            Section("Body") {
                Stepper("Height: \(Int(draft.heightCm)) cm", value: $draft.heightCm, in: 130...220, step: 1)
                Stepper("Weight: \(String(format: "%.1f", draft.startWeightKg)) kg", value: $draft.startWeightKg, in: 35...220, step: 0.5)
                Stepper("Body fat: \(draft.startBodyFatPercent.map { String(format: "%.0f%%", $0) } ?? "unknown")",
                        value: Binding(get: { draft.startBodyFatPercent ?? 20 },
                                       set: { draft.startBodyFatPercent = $0 }),
                        in: 5...50, step: 1)
                if draft.startBodyFatPercent != nil {
                    Button("I don't know my body fat") { draft.startBodyFatPercent = nil }
                        .font(.footnote)
                }
            }
            Section {
                Text("Body-fat % (from a Withings scale or DEXA) lets us use the more accurate Katch-McArdle formula for your calories. A rough estimate is fine — we refine it from your data.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var goalStep: some View {
        Form {
            Section("Primary goal") {
                ForEach(Goal.allCases) { goal in
                    Button {
                        draft.goal = goal
                    } label: {
                        HStack {
                            Text(goal.label).foregroundStyle(.primary)
                            Spacer()
                            if draft.goal == goal { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
                        }
                    }
                }
            }
            Section("Muscles to emphasise (optional)") {
                ForEach(MuscleGroup.allCases) { m in
                    Button {
                        if draft.priorityMuscles.contains(m) {
                            draft.priorityMuscles.removeAll { $0 == m }
                        } else if draft.priorityMuscles.count < 3 {
                            draft.priorityMuscles.append(m)
                        }
                    } label: {
                        HStack {
                            Text(m.label).foregroundStyle(.primary)
                            Spacer()
                            if draft.priorityMuscles.contains(m) { Image(systemName: "checkmark").foregroundStyle(.tint) }
                        }
                    }
                }
            } header: { Text("Pick up to 3") }
        }
    }

    private var experienceStep: some View {
        Form {
            Section("Training experience") {
                ForEach(ExperienceLevel.allCases) { level in
                    Button {
                        draft.experience = level
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(level.label).foregroundStyle(.primary)
                                Text(experienceHint(level)).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if draft.experience == level { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
                        }
                    }
                }
            }
            Section {
                Text("Experience sets your starting volume: beginners grow on much less than advanced lifters, and starting too high just buys fatigue.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func experienceHint(_ l: ExperienceLevel) -> String {
        switch l {
        case .beginner: return "< 1 year of consistent lifting"
        case .intermediate: return "1–4 years, most newbie gains done"
        case .advanced: return "4+ years, progress is hard-won"
        }
    }

    private var constraintsStep: some View {
        Form {
            Section("Time & frequency") {
                Stepper("Sessions per week: \(draft.constraints.daysPerWeek)", value: $draft.constraints.daysPerWeek, in: 2...6)
                Stepper("Minutes per session: \(draft.constraints.minutesPerSession)", value: $draft.constraints.minutesPerSession, in: 30...120, step: 5)
                Text(PlanEngine.split(for: draft.constraints.daysPerWeek).name)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Equipment") {
                Picker("Available equipment", selection: $draft.equipment) {
                    ForEach(EquipmentSetting.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline).labelsHidden()
            }
            Section("Anything hurting? (movements loading these will be avoided)") {
                ForEach(InjuryArea.allCases) { area in
                    Button {
                        if draft.constraints.injuries.contains(area) {
                            draft.constraints.injuries.removeAll { $0 == area }
                        } else {
                            draft.constraints.injuries.append(area)
                        }
                    } label: {
                        HStack {
                            Text(area.label).foregroundStyle(.primary)
                            Spacer()
                            if draft.constraints.injuries.contains(area) { Image(systemName: "checkmark").foregroundStyle(.tint) }
                        }
                    }
                }
            }
        }
    }

    private var lifestyleStep: some View {
        Form {
            Section("Daily activity (outside the gym)") {
                Picker("Activity", selection: $draft.activityLevel) {
                    ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline).labelsHidden()
            }
            Section("Diet notes (allergies, preferences)") {
                TextField("e.g. lactose intolerant, vegetarian…", text: $draft.dietaryNotes, axis: .vertical)
                    .lineLimit(3...5)
            }
            Section("Weekly check-in reminder") {
                Picker("Day", selection: $draft.checkInWeekday) {
                    ForEach(1...7, id: \.self) { d in
                        Text(Calendar.current.weekdaySymbols[d - 1]).tag(d)
                    }
                }
                Picker("Hour", selection: $draft.checkInHour) {
                    ForEach(5...22, id: \.self) { Text("\($0):00").tag($0) }
                }
            }
        }
    }

    private var connectStep: some View {
        Form {
            Section("Connect your data") {
                Text("MyFitnessPal, Withings and Ultrahuman all sync into Apple Health. Link it once and FitCoach reads your weight, body fat, nutrition logs, sleep and HRV — and challenges anything that looks off.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button {
                    syncing = true
                    Task {
                        do {
                            let summary = try await appState.syncHealthKit()
                            healthKitStatus = "Linked ✓ — pulled \(summary.added + summary.merged) days of data" + (summary.flags.isEmpty ? "" : " (\(summary.flags.count) values flagged for review)")
                        } catch {
                            healthKitStatus = "Couldn't link: \(error.localizedDescription)"
                        }
                        syncing = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                        Text(syncing ? "Linking…" : "Link Apple Health")
                        if syncing { Spacer(); ProgressView() }
                    }
                }
                .disabled(syncing)
                if let healthKitStatus {
                    Text(healthKitStatus).font(.footnote)
                }
            }
            Section {
                Text("Prefer files? You can also import CSV/JSON exports from each app any time in Progress → Import Data.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Review") {
                LabeledContent("Goal", value: draft.goal.label)
                LabeledContent("Split", value: PlanEngine.split(for: draft.constraints.daysPerWeek).name)
                LabeledContent("Schedule", value: "\(draft.constraints.daysPerWeek)×/week, \(draft.constraints.minutesPerSession) min")
                LabeledContent("Experience", value: draft.experience.label)
            }
        }
    }
}

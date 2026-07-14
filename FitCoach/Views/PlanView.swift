import SwiftUI

struct PlanView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedWeek = 0
    @State private var showRationale = false
    @State private var activeWorkout: WorkoutDay?
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            Group {
                if let plan = appState.plan {
                    planContent(plan)
                } else {
                    ContentUnavailableView("No plan yet",
                                           systemImage: "dumbbell",
                                           description: Text("Complete onboarding to generate your program."))
                }
            }
            .navigationTitle(appState.plan?.splitName ?? "Training")
            .toolbar {
                Button { showRationale = true } label: { Image(systemName: "info.circle") }
            }
            .sheet(isPresented: $showRationale) { rationaleSheet }
            .fullScreenCover(item: $activeWorkout) { day in
                WorkoutSessionView(day: day)
            }
            .onAppear {
                if !appeared {
                    selectedWeek = appState.plan?.currentWeekIndex ?? 0
                    appeared = true
                }
            }
        }
    }

    private func planContent(_ plan: TrainingPlan) -> some View {
        List {
            Section {
                Picker("Week", selection: $selectedWeek) {
                    ForEach(plan.weeks.indices, id: \.self) { i in
                        Text(plan.weeks[i].isDeload ? "W\(i + 1) · Deload" : "Week \(i + 1)").tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if plan.weeks.indices.contains(selectedWeek) {
                let week = plan.weeks[selectedWeek]
                if week.isDeload {
                    Section {
                        Label("Deload week: ~60% volume, RIR 4, loads −10%. The point is to recover, not to grind.", systemImage: "leaf.fill")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                ForEach(week.days) { day in
                    Section {
                        ForEach(day.exercises) { p in
                            exerciseRow(p)
                        }
                        Button {
                            activeWorkout = day
                        } label: {
                            Label("Start \(day.name)", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    } header: {
                        HStack {
                            Text(day.name)
                            Spacer()
                            Text("~\(day.estimatedMinutes) min · RIR \(week.targetRIR)")
                        }
                    }
                }
                volumeSection(week)
            }
        }
    }

    private func exerciseRow(_ p: ExercisePrescription) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(p.exerciseName).font(.body.weight(.medium))
            HStack(spacing: 6) {
                chip("\(p.sets) sets")
                chip("\(p.repLower)–\(p.repUpper) reps")
                chip("RIR \(p.targetRIR)")
                chip("rest \(p.restSeconds / 60)′" + (p.restSeconds % 60 == 0 ? "" : "\(p.restSeconds % 60)″"))
            }
            if !p.note.isEmpty {
                Text(p.note).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }

    private func volumeSection(_ week: TrainingWeek) -> some View {
        Section("Weekly sets per muscle (vs MEV→MAV target)") {
            let volumes = weeklyVolumes(week)
            ForEach(MuscleGroup.allCases.filter { (volumes[$0] ?? 0) > 0 }) { m in
                let sets = volumes[m] ?? 0
                let lm = VolumeLandmarks.base(for: m).scaled(by: appState.profile?.experience.volumeScale ?? 1)
                HStack {
                    Text(m.label).font(.footnote)
                    Spacer()
                    Text("\(sets) sets").font(.footnote.bold())
                    Text("MEV \(Int(lm.mev)) · MAV \(Int(lm.mav))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func weeklyVolumes(_ week: TrainingWeek) -> [MuscleGroup: Int] {
        var out: [MuscleGroup: Int] = [:]
        for day in week.days {
            for p in day.exercises {
                guard let ex = ExerciseLibrary.byID(p.exerciseID) else { continue }
                out[ex.primary, default: 0] += p.sets
                for secondary in ex.secondary {
                    out[secondary, default: 0] += p.sets / 2
                }
            }
        }
        return out
    }

    private var rationaleSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(appState.plan?.rationale ?? "")
                    if let revisions = appState.plan?.revisions, !revisions.isEmpty {
                        Divider()
                        Text("Plan history").font(.headline)
                        ForEach(revisions) { r in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("“\(r.prompt)”").font(.footnote.italic())
                                Text(r.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Why this plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

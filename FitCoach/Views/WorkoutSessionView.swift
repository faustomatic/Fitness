import SwiftUI

/// Live workout companion: session clock, per-set weight/rep logging with
/// suggested loads from your last session, and an auto-starting rest timer.
struct WorkoutSessionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let day: WorkoutDay

    @State private var startedAt = Date()
    @State private var setInputs: [UUID: [SetInput]] = [:]
    @State private var restRemaining: Int = 0
    @State private var restTotal: Int = 0
    @State private var notes = ""
    @State private var showFinishConfirm = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    struct SetInput: Identifiable {
        let id = UUID()
        var weightKg: Double
        var reps: Int
        var done = false
    }

    var body: some View {
        NavigationStack {
            List {
                if let note = appState.latestRecoveryNote {
                    Section {
                        Label(note, systemImage: "moon.zzz.fill")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                ForEach(day.exercises) { prescription in
                    exerciseSection(prescription)
                }
                Section("Session notes") {
                    TextField("Anything to remember…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Button {
                        showFinishConfirm = true
                    } label: {
                        Label("Finish Workout", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(day.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(elapsedString)
                        .font(.system(.body, design: .monospaced).bold())
                }
            }
            .safeAreaInset(edge: .bottom) {
                if restRemaining > 0 { restBar }
            }
            .onReceive(tick) { _ in
                if restRemaining > 0 { restRemaining -= 1 }
            }
            .onAppear(perform: seedInputs)
            .confirmationDialog("Finish and save this workout?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
                Button("Save workout") { finish() }
                Button("Keep training", role: .cancel) {}
            }
        }
    }

    // MARK: Sections

    private func exerciseSection(_ p: ExercisePrescription) -> some View {
        Section {
            let suggestion = PlanEngine.suggestion(for: p, history: appState.sessions)
            if let s = suggestion {
                Label(String(format: "Suggested: %.1f kg × %d (double progression from last time)", s.weightKg, s.reps),
                      systemImage: "arrow.up.right")
                .font(.caption).foregroundStyle(.tint)
            }
            ForEach(bindingRows(for: p)) { $row in
                setRow(row: $row, prescription: p)
            }
            Button {
                var rows = setInputs[p.id] ?? []
                let template = rows.last ?? SetInput(weightKg: suggestion?.weightKg ?? 20, reps: p.repLower)
                rows.append(SetInput(weightKg: template.weightKg, reps: template.reps))
                setInputs[p.id] = rows
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.footnote)
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.exerciseName)
                Text("\(p.sets)×\(p.repLower)–\(p.repUpper) · RIR \(p.targetRIR) · rest \(p.restSeconds)s")
            }
        }
    }

    private func bindingRows(for p: ExercisePrescription) -> Binding<[SetInput]> {
        Binding(
            get: { setInputs[p.id] ?? [] },
            set: { setInputs[p.id] = $0 }
        )
    }

    private func setRow(row: Binding<SetInput>, prescription: ExercisePrescription) -> some View {
        HStack(spacing: 12) {
            Stepper(value: row.weightKg, in: 0...500, step: 2.5) {
                Text(String(format: "%.1f kg", row.wrappedValue.weightKg))
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 74, alignment: .leading)
            }
            .fixedSize()
            Stepper(value: row.reps, in: 0...50) {
                Text("\(row.wrappedValue.reps) reps")
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 58, alignment: .leading)
            }
            .fixedSize()
            Spacer()
            Button {
                row.wrappedValue.done.toggle()
                if row.wrappedValue.done {
                    restTotal = prescription.restSeconds
                    restRemaining = prescription.restSeconds
                }
            } label: {
                Image(systemName: row.wrappedValue.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(row.wrappedValue.done ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var restBar: some View {
        HStack {
            Image(systemName: "timer")
            Text("Rest \(restRemaining / 60):\(String(format: "%02d", restRemaining % 60))")
                .font(.system(.headline, design: .monospaced))
            Spacer()
            ProgressView(value: Double(restTotal - restRemaining), total: Double(max(restTotal, 1)))
                .frame(width: 110)
            Button("Skip") { restRemaining = 0 }
                .font(.footnote)
        }
        .padding()
        .background(.thinMaterial)
    }

    // MARK: Logic

    private var elapsedString: String {
        let secs = Int(Date().timeIntervalSince(startedAt))
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    private func seedInputs() {
        guard setInputs.isEmpty else { return }
        for p in day.exercises {
            let suggestion = PlanEngine.suggestion(for: p, history: appState.sessions)
            let weight = suggestion?.weightKg ?? 20
            let reps = suggestion?.reps ?? p.repLower
            setInputs[p.id] = (0..<p.sets).map { _ in SetInput(weightKg: weight, reps: reps) }
        }
    }

    private func finish() {
        var logs: [SetLog] = []
        for p in day.exercises {
            for (i, row) in (setInputs[p.id] ?? []).enumerated() where row.done {
                logs.append(SetLog(exerciseID: p.exerciseID,
                                   setNumber: i + 1,
                                   weightKg: row.weightKg,
                                   reps: row.reps,
                                   rir: p.targetRIR))
            }
        }
        var session = WorkoutSession(weekIndex: appState.plan?.currentWeekIndex ?? 0,
                                     dayID: day.id,
                                     dayName: day.name)
        session.logs = logs
        session.durationSeconds = Int(Date().timeIntervalSince(startedAt))
        session.notes = notes
        appState.finishSession(session)
        dismiss()
    }
}

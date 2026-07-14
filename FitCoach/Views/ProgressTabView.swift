import SwiftUI
import Charts
import UniformTypeIdentifiers

struct ProgressTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCheckIn = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showCheckIn = true
                    } label: {
                        Label(appState.checkInDue ? "Check-in due — start now" : "New check-in",
                              systemImage: "checkmark.seal.fill")
                    }
                }

                strengthSection

                Section("Check-in history") {
                    if appState.checkIns.isEmpty {
                        Text("No check-ins yet. Your first one sets the baseline.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(appState.checkIns.sorted { $0.date > $1.date }) { ci in
                        NavigationLink {
                            CheckInDetailView(checkIn: ci)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(ci.date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.bold())
                                    Spacer()
                                    if let w = ci.weightKg { Text(String(format: "%.1f kg", w)).font(.footnote) }
                                    if !ci.photos.isEmpty { Image(systemName: "photo.stack").font(.caption).foregroundStyle(.secondary) }
                                }
                                Text(ci.analysis.components(separatedBy: "\n").first ?? "")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }

                Section("Data") {
                    NavigationLink {
                        ImportView()
                    } label: {
                        Label("Import data (MFP / Withings / Ultrahuman)", systemImage: "square.and.arrow.down")
                    }
                    NavigationLink {
                        FlagsView()
                    } label: {
                        Label("Data quality flags (\(appState.flags.count))", systemImage: "exclamationmark.triangle")
                    }
                }
            }
            .navigationTitle("Progress")
            .sheet(isPresented: $showCheckIn) { CheckInView() }
        }
    }

    @State private var selectedExercise: String = "barbell-bench-press"

    private var loggedExerciseIDs: [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for session in appState.sessions {
            for log in session.logs where !seen.contains(log.exerciseID) {
                seen.insert(log.exerciseID)
                out.append(log.exerciseID)
            }
        }
        return out
    }

    @ViewBuilder
    private var strengthSection: some View {
        Section("Strength (estimated 1RM)") {
            if loggedExerciseIDs.isEmpty {
                Text("Log workouts to see strength trends per lift.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Picker("Exercise", selection: $selectedExercise) {
                    ForEach(loggedExerciseIDs, id: \.self) { id in
                        Text(ExerciseLibrary.byID(id)?.name ?? id).tag(id)
                    }
                }
                let trend = ProgressAnalyzer.strengthTrend(exerciseID: selectedExercise, sessions: appState.sessions)
                if trend.count >= 2 {
                    Chart(trend) { p in
                        LineMark(x: .value("Date", p.date), y: .value("e1RM", p.value))
                        PointMark(x: .value("Date", p.date), y: .value("e1RM", p.value))
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 140)
                    if let first = trend.first, let last = trend.last, first.value > 0 {
                        Text(String(format: "%+.1f%% since %@", (last.value - first.value) / first.value * 100,
                                    first.date.formatted(date: .abbreviated, time: .omitted)))
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Two or more logged sessions of this lift will draw the trend.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            if let first = loggedExerciseIDs.first, !loggedExerciseIDs.contains(selectedExercise) {
                selectedExercise = first
            }
        }
    }
}

// MARK: - Check-in detail

struct CheckInDetailView: View {
    let checkIn: CheckIn

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !checkIn.photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(checkIn.photos) { photo in
                                if let img = PersistenceStore.loadPhoto(filename: photo.filename) {
                                    VStack {
                                        Image(uiImage: img)
                                            .resizable().scaledToFill()
                                            .frame(width: 110, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        Text(photo.angle.label).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    if let w = checkIn.weightKg {
                        GridRow { Text("Weight").foregroundStyle(.secondary); Text(String(format: "%.1f kg", w)) }
                    }
                    if let waist = checkIn.waistCm {
                        GridRow { Text("Waist").foregroundStyle(.secondary); Text(String(format: "%.1f cm", waist)) }
                    }
                    GridRow { Text("Energy").foregroundStyle(.secondary); Text("\(checkIn.energy)/5") }
                    GridRow { Text("Sleep").foregroundStyle(.secondary); Text("\(checkIn.sleepQuality)/5") }
                    GridRow { Text("Hunger").foregroundStyle(.secondary); Text("\(checkIn.hunger)/5") }
                }
                .font(.subheadline)
                if !checkIn.notes.isEmpty {
                    Text(checkIn.notes).font(.footnote).italic()
                }
                Divider()
                Text("Analysis").font(.headline)
                Text(checkIn.analysis).font(.footnote)
            }
            .padding()
        }
        .navigationTitle(checkIn.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Import

struct ImportView: View {
    @EnvironmentObject var appState: AppState
    @State private var source: DataSource = .myFitnessPal
    @State private var showPicker = false
    @State private var result: String?
    @State private var syncingHK = false

    var body: some View {
        Form {
            Section("Live sync (recommended)") {
                Text("MyFitnessPal, Withings and Ultrahuman all push data into Apple Health — one link covers all three.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button {
                    syncingHK = true
                    Task {
                        do {
                            let summary = try await appState.syncHealthKit()
                            result = "Apple Health: \(summary.added) days added, \(summary.merged) merged." + (summary.flags.isEmpty ? "" : " \(summary.flags.count) values flagged — see Data quality flags.")
                        } catch {
                            result = "Sync failed: \(error.localizedDescription)"
                        }
                        syncingHK = false
                    }
                } label: {
                    HStack {
                        Label(appState.healthKitLinked ? "Re-sync Apple Health" : "Link Apple Health", systemImage: "heart.fill")
                        if syncingHK { Spacer(); ProgressView() }
                    }
                }
                .disabled(syncingHK)
            }

            Section("File import") {
                Picker("Source app", selection: $source) {
                    Text("MyFitnessPal").tag(DataSource.myFitnessPal)
                    Text("Withings").tag(DataSource.withings)
                    Text("Ultrahuman").tag(DataSource.ultrahuman)
                    Text("Other CSV").tag(DataSource.csvImport)
                }
                Button {
                    showPicker = true
                } label: {
                    Label("Choose CSV / JSON file", systemImage: "doc.badge.plus")
                }
                Text(exportHint)
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let result {
                Section("Result") { Text(result).font(.footnote) }
            }
        }
        .navigationTitle("Import Data")
        .fileImporter(isPresented: $showPicker,
                      allowedContentTypes: [.commaSeparatedText, .json, .plainText],
                      allowsMultipleSelection: false) { outcome in
            switch outcome {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let snaps = try ImportService.importFile(at: url, hint: source)
                    let summary = appState.ingest(snaps)
                    result = "\(summary.added) days added, \(summary.merged) merged from \(source.label)."
                        + (summary.flags.isEmpty ? " Everything passed sanity checks."
                           : " ⚠️ \(summary.flags.count) value(s) flagged: " + summary.flags.prefix(2).map(\.message).joined(separator: " "))
                } catch {
                    result = "Import failed: \(error.localizedDescription)"
                }
            case .failure(let error):
                result = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    private var exportHint: String {
        switch source {
        case .myFitnessPal: return "MFP: Settings → Export Data → Nutrition Summary CSV. Rows per meal are summed per day."
        case .withings: return "Withings/Health Mate: Settings → Download my data → weight.csv (weight + fat mass)."
        case .ultrahuman: return "Ultrahuman: Profile → Export → CSV/JSON (sleep, HRV, recovery score)."
        default: return "Any CSV with a date column plus weight / calories / protein / HRV / sleep columns."
        }
    }
}

// MARK: - Flags

struct FlagsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            if appState.flags.isEmpty {
                Text("No anomalies detected in your data. 👍").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(appState.flags.sorted { $0.date > $1.date }) { flag in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Image(systemName: flag.severity == .suspect ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(flag.severity == .suspect ? .red : .orange)
                        Text(flag.metric.capitalized).font(.footnote.bold())
                        Spacer()
                        Text(flag.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(flag.message).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Data Quality")
    }
}

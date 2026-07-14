import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCheckIn = false
    @State private var activeWorkout: WorkoutDay?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if appState.checkInDue {
                        checkInBanner
                    }
                    if let note = appState.latestRecoveryNote {
                        recoveryCard(note)
                    }
                    nextWorkoutCard
                    weightCard
                    if !recentFlags.isEmpty {
                        flagsCard
                    }
                    streakCard
                }
                .padding()
            }
            .navigationTitle(greeting)
            .toolbar {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            .sheet(isPresented: $showCheckIn) { CheckInView() }
            .fullScreenCover(item: $activeWorkout) { day in
                WorkoutSessionView(day: day)
            }
        }
    }

    private var greeting: String {
        let name = appState.profile?.name ?? ""
        return name.isEmpty ? "FitCoach" : "Hi, \(name.components(separatedBy: " ").first ?? name)"
    }

    private var checkInBanner: some View {
        Button { showCheckIn = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly check-in due").font(.headline)
                    Text("Weigh-in, photos & 3 quick questions").font(.footnote).opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.primary)
            .foregroundStyle(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func recoveryCard(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "moon.zzz.fill").foregroundStyle(.indigo)
            Text(note).font(.footnote)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.indigo.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var nextWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next workout").font(.subheadline).foregroundStyle(.secondary)
            if let day = appState.nextWorkout, let week = appState.currentWeek {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.name).font(.title2.bold())
                        Text("Week \(week.index + 1)\(week.isDeload ? " · DELOAD" : "") · ~\(day.estimatedMinutes) min · RIR \(week.targetRIR)")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text(day.exercises.prefix(3).map(\.exerciseName).joined(separator: " · ")
                             + (day.exercises.count > 3 ? " +\(day.exercises.count - 3) more" : ""))
                            .font(.footnote).foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        activeWorkout = day
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("No plan yet — finish onboarding or ask the Coach to build one.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weight trend").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if let rate = ProgressAnalyzer.weeklyRateKg(trend: appState.weightTrend) {
                    Text(String(format: "%+.2f kg/wk", rate))
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                }
            }
            let trend = appState.weightTrend
            if trend.count >= 2 {
                Chart {
                    ForEach(rawWeights) { p in
                        PointMark(x: .value("Date", p.date), y: .value("kg", p.value))
                            .opacity(0.25)
                    }
                    ForEach(trend) { p in
                        LineMark(x: .value("Date", p.date), y: .value("kg", p.value))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 160)
            } else {
                Text("Link Apple Health or import data to see your smoothed trend — daily scale noise is filtered out.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(height: 60)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var rawWeights: [TrendPoint] {
        appState.snapshots.compactMap { s in
            s.weightKg.map { TrendPoint(date: s.date, value: $0) }
        }
    }

    private var recentFlags: [DataQualityFlag] {
        Array(appState.flags
            .filter { Date().timeIntervalSince($0.date) < 7 * 86400 }
            .suffix(3))
    }

    private var flagsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Data worth a second look", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold()).foregroundStyle(.orange)
            ForEach(recentFlags) { flag in
                Text("• \(flag.message)").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var streakCard: some View {
        let done = sessionsThisWeek
        let target = appState.currentWeek?.days.count ?? 0
        return HStack {
            Image(systemName: "flame.fill").foregroundStyle(.orange)
            Text("\(done) of \(target) sessions this week")
                .font(.subheadline)
            Spacer()
            if target > 0 {
                ProgressView(value: Double(min(done, target)), total: Double(target))
                    .frame(width: 100)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var sessionsThisWeek: Int {
        guard let plan = appState.plan else { return 0 }
        let weekStart = Calendar.current.date(byAdding: .day, value: plan.currentWeekIndex * 7, to: plan.startDate) ?? plan.startDate
        return appState.sessions.filter { $0.completed && $0.date >= weekStart }.count
    }
}

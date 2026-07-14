import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {

    @Published var profile: UserProfile?
    @Published var plan: TrainingPlan?
    @Published var nutrition: NutritionTargets?
    @Published var sessions: [WorkoutSession] = []
    @Published var snapshots: [BiometricSnapshot] = []
    @Published var checkIns: [CheckIn] = []
    @Published var chat: [ChatMessage] = []
    @Published var flags: [DataQualityFlag] = []
    @Published var healthKitLinked = false

    init() {
        profile = PersistenceStore.load(UserProfile.self, from: "profile")
        plan = PersistenceStore.load(TrainingPlan.self, from: "plan")
        nutrition = PersistenceStore.load(NutritionTargets.self, from: "nutrition")
        sessions = PersistenceStore.load([WorkoutSession].self, from: "sessions") ?? []
        snapshots = PersistenceStore.load([BiometricSnapshot].self, from: "snapshots") ?? []
        checkIns = PersistenceStore.load([CheckIn].self, from: "checkins") ?? []
        chat = PersistenceStore.load([ChatMessage].self, from: "chat") ?? []
        flags = PersistenceStore.load([DataQualityFlag].self, from: "flags") ?? []
        healthKitLinked = UserDefaults.standard.bool(forKey: "healthKitLinked")
    }

    func persist() {
        if let profile { PersistenceStore.save(profile, as: "profile") }
        if let plan { PersistenceStore.save(plan, as: "plan") }
        if let nutrition { PersistenceStore.save(nutrition, as: "nutrition") }
        PersistenceStore.save(sessions, as: "sessions")
        PersistenceStore.save(snapshots, as: "snapshots")
        PersistenceStore.save(checkIns, as: "checkins")
        PersistenceStore.save(chat, as: "chat")
        PersistenceStore.save(flags, as: "flags")
    }

    // MARK: Derived

    var weightTrend: [TrendPoint] {
        ProgressAnalyzer.weightTrend(snapshots: snapshots, flags: flags)
    }

    var latestRecoveryNote: String? {
        let modifier = PlanEngine.recoveryModifier(snapshots: snapshots)
        guard modifier < 1.0 else { return nil }
        return "Recovery trend is down (sleep/HRV) — today's volume target is reduced \(Int((1 - modifier) * 100))%. Leave an extra rep in the tank."
    }

    var checkInDue: Bool {
        guard let last = checkIns.map(\.date).max() else { return true }
        return Date().timeIntervalSince(last) > 6.5 * 86400
    }

    var currentWeek: TrainingWeek? {
        guard let plan else { return nil }
        return plan.weeks[plan.currentWeekIndex]
    }

    /// First day of the current week without a completed session this week.
    var nextWorkout: WorkoutDay? {
        guard let plan, let week = currentWeek else { return nil }
        let weekStart = Calendar.current.date(byAdding: .day, value: plan.currentWeekIndex * 7, to: plan.startDate) ?? plan.startDate
        let doneIDs = Set(sessions.filter { $0.completed && $0.date >= weekStart }.map(\.dayID))
        return week.days.first { !doneIDs.contains($0.id) } ?? week.days.first
    }

    // MARK: Actions

    func completeOnboarding(_ newProfile: UserProfile) {
        profile = newProfile
        regeneratePlan(reason: nil)
        recalcNutrition()
        Task {
            let granted = await NotificationService.requestAuthorization()
            if granted {
                NotificationService.scheduleCheckInReminder(weekday: newProfile.checkInWeekday, hour: newProfile.checkInHour)
                NotificationService.scheduleOverdueNudge(weekday: newProfile.checkInWeekday, hour: newProfile.checkInHour)
            }
        }
        persist()
    }

    func regeneratePlan(reason: PlanRevision?) {
        guard let profile else { return }
        let modifier = PlanEngine.recoveryModifier(snapshots: snapshots)
        var newPlan = PlanEngine.generatePlan(profile: profile, recoveryModifier: modifier)
        if let old = plan {
            newPlan.revisions = old.revisions
        }
        if let reason { newPlan.revisions.append(reason) }
        plan = newPlan
        persist()
    }

    func recalcNutrition() {
        guard let profile else { return }
        let trend = weightTrend
        nutrition = NutritionEngine.targets(profile: profile,
                                            trendWeightKg: ProgressAnalyzer.latestTrendWeight(trend: trend),
                                            trendBodyFatPercent: ProgressAnalyzer.trendBodyFat(snapshots: snapshots))
        persist()
    }

    func finishSession(_ session: WorkoutSession) {
        var s = session
        s.completed = true
        sessions.append(s)
        persist()
    }

    @discardableResult
    func ingest(_ incoming: [BiometricSnapshot]) -> ImportSummary {
        var added = 0
        var merged = 0
        let cal = Calendar.current
        for snap in incoming {
            if let idx = snapshots.firstIndex(where: { cal.isDate($0.date, inSameDayAs: snap.date) }) {
                snapshots[idx] = mergeSnapshots(existing: snapshots[idx], incoming: snap)
                merged += 1
            } else {
                snapshots.append(snap)
                added += 1
            }
        }
        snapshots.sort { $0.date < $1.date }
        flags = DataSanityChecker.check(snapshots: snapshots, profile: profile)
        recalcNutrition()
        persist()
        return ImportSummary(added: added, merged: merged,
                             flags: flags.filter { f in incoming.contains { cal.isDate($0.date, inSameDayAs: f.date) } })
    }

    private func mergeSnapshots(existing: BiometricSnapshot, incoming: BiometricSnapshot) -> BiometricSnapshot {
        var out = existing
        out.weightKg = incoming.weightKg ?? out.weightKg
        out.bodyFatPercent = incoming.bodyFatPercent ?? out.bodyFatPercent
        out.leanMassKg = incoming.leanMassKg ?? out.leanMassKg
        out.restingHeartRate = incoming.restingHeartRate ?? out.restingHeartRate
        out.hrvMs = incoming.hrvMs ?? out.hrvMs
        out.sleepHours = incoming.sleepHours ?? out.sleepHours
        out.recoveryScore = incoming.recoveryScore ?? out.recoveryScore
        out.caloriesIn = incoming.caloriesIn ?? out.caloriesIn
        out.proteinG = incoming.proteinG ?? out.proteinG
        out.carbsG = incoming.carbsG ?? out.carbsG
        out.fatG = incoming.fatG ?? out.fatG
        out.steps = incoming.steps ?? out.steps
        out.activeEnergyKcal = incoming.activeEnergyKcal ?? out.activeEnergyKcal
        return out
    }

    func syncHealthKit() async throws -> ImportSummary {
        try await HealthKitService.shared.requestAuthorization()
        let snaps = try await HealthKitService.shared.fetchSnapshots()
        healthKitLinked = true
        UserDefaults.standard.set(true, forKey: "healthKitLinked")
        return ingest(snaps)
    }

    func submitCheckIn(_ checkIn: CheckIn) {
        guard let profile else { return }
        var ci = checkIn
        if let w = ci.weightKg {
            ingest([BiometricSnapshot(date: Calendar.current.startOfDay(for: ci.date), source: .manual, weightKg: w)])
        }
        let (analysis, adjustment) = ProgressAnalyzer.analyzeCheckIn(ci,
                                                                     profile: profile,
                                                                     snapshots: snapshots,
                                                                     flags: flags,
                                                                     sessions: sessions,
                                                                     plan: plan,
                                                                     targets: nutrition)
        ci.analysis = analysis
        checkIns.append(ci)
        if adjustment != 0, var n = nutrition {
            n.calories += adjustment
            n.carbsG += adjustment / 4
            n.rationale += "\n\nAdjusted \(adjustment > 0 ? "+" : "")\(adjustment) kcal at your check-in on \(ci.date.formatted(date: .abbreviated, time: .omitted)) based on your actual trend."
            n.updatedAt = Date()
            nutrition = n
        }
        persist()
    }

    func sendToCoach(_ text: String) async {
        chat.append(ChatMessage(role: "user", text: text))
        persist()
        guard let profile else { return }
        let result = await CoachService.respond(to: text, profile: profile, plan: plan)
        var changed = false
        if let updated = result.updatedProfile {
            self.profile = updated
            changed = true
        }
        if result.regeneratePlan {
            regeneratePlan(reason: PlanRevision(prompt: text, summary: String(result.reply.prefix(140))))
            recalcNutrition()
            changed = true
        }
        if result.deloadNow, var plan {
            // Jump the mesocycle so the deload week starts now.
            let deloadIndex = plan.weeks.count - 1
            plan.startDate = Calendar.current.date(byAdding: .day, value: -7 * deloadIndex, to: Calendar.current.startOfDay(for: Date())) ?? plan.startDate
            self.plan = plan
            changed = true
        }
        chat.append(ChatMessage(role: "coach", text: result.reply, planChanged: changed))
        persist()
    }
}

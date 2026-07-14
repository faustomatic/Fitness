import Foundation

struct TrendPoint: Identifiable {
    var id: Date { date }
    var date: Date
    var value: Double
}

/// Turns noisy daily data into trends and writes the weekly check-in analysis.
enum ProgressAnalyzer {

    /// Exponentially-weighted moving average of daily weight (alpha ≈ 7-day smoothing),
    /// skipping values flagged `.suspect`.
    static func weightTrend(snapshots: [BiometricSnapshot], flags: [DataQualityFlag]) -> [TrendPoint] {
        let suspectDays = Set(flags.filter { $0.metric == "weight" && $0.severity == .suspect }
                                   .map { Calendar.current.startOfDay(for: $0.date) })
        let points = snapshots
            .compactMap { s in s.weightKg.map { (Calendar.current.startOfDay(for: s.date), $0) } }
            .filter { !suspectDays.contains($0.0) }
            .sorted { $0.0 < $1.0 }
        guard !points.isEmpty else { return [] }

        var ema = points[0].1
        let alpha = 2.0 / 8.0
        return points.map { (date, w) in
            ema = alpha * w + (1 - alpha) * ema
            return TrendPoint(date: date, value: ema)
        }
    }

    /// kg change per week from the trend line (nil if under 2 weeks of data).
    static func weeklyRateKg(trend: [TrendPoint]) -> Double? {
        guard let last = trend.last,
              let ref = trend.last(where: { last.date.timeIntervalSince($0.date) >= 12 * 86400 })
        else { return nil }
        let days = last.date.timeIntervalSince(ref.date) / 86400
        return (last.value - ref.value) / days * 7
    }

    static func latestTrendWeight(trend: [TrendPoint]) -> Double? { trend.last?.value }

    static func trendBodyFat(snapshots: [BiometricSnapshot]) -> Double? {
        let vals = snapshots.sorted { $0.date < $1.date }
            .compactMap(\.bodyFatPercent)
            .filter { (3...60).contains($0) }
            .suffix(7)
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    /// Best e1RM per day for one exercise — powers the strength chart.
    static func strengthTrend(exerciseID: String, sessions: [WorkoutSession]) -> [TrendPoint] {
        let cal = Calendar.current
        var bestByDay: [Date: Double] = [:]
        for session in sessions {
            for log in session.logs where log.exerciseID == exerciseID {
                let day = cal.startOfDay(for: log.completedAt)
                bestByDay[day] = max(bestByDay[day] ?? 0, log.e1RM)
            }
        }
        return bestByDay.map { TrendPoint(date: $0.key, value: $0.value) }.sorted { $0.date < $1.date }
    }

    /// Sessions completed / planned over the last `weeks` weeks.
    static func adherence(sessions: [WorkoutSession], plan: TrainingPlan?, weeks: Int = 2) -> Double? {
        guard let plan else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7 * weeks, to: Date()) ?? Date()
        let done = sessions.filter { $0.date >= cutoff && $0.completed }.count
        let planned = plan.weeks.first.map { $0.days.count * weeks } ?? 0
        guard planned > 0 else { return nil }
        return min(Double(done) / Double(planned), 1.5)
    }

    // MARK: Check-in analysis

    static func analyzeCheckIn(_ checkIn: CheckIn,
                               profile: UserProfile,
                               snapshots: [BiometricSnapshot],
                               flags: [DataQualityFlag],
                               sessions: [WorkoutSession],
                               plan: TrainingPlan?,
                               targets: NutritionTargets?) -> (analysis: String, calorieAdjustment: Int) {
        var out: [String] = []
        var adjustment = 0

        let trend = weightTrend(snapshots: snapshots, flags: flags)
        if let rate = weeklyRateKg(trend: trend), let current = latestTrendWeight(trend: trend) {
            let pct = rate / current * 100
            let expected = profile.goal.expectedWeeklyRatePercent
            out.append(String(format: "Trend weight %.1f kg, moving %+.2f kg/week (%+.2f%% BW).", current, rate, pct))
            if pct < expected.lowerBound - 0.05 {
                if profile.goal == .fatLoss {
                    out.append("You're losing faster than the target range — risk of muscle loss. Add ~150 kcal/day (mostly carbs) and keep protein high.")
                    adjustment = 150
                } else {
                    out.append("You're below the target gain range. Add ~150 kcal/day and prioritise sleep; re-assess next week.")
                    adjustment = 150
                }
            } else if pct > expected.upperBound + 0.05 {
                if profile.goal == .fatLoss {
                    out.append("Loss has stalled versus target. Trim ~150 kcal/day (from carbs/fat, not protein) or add 2k daily steps.")
                    adjustment = -150
                } else {
                    out.append("Gaining faster than the lean-gain target — extra is mostly fat. Trim ~100 kcal/day.")
                    adjustment = -100
                }
            } else {
                out.append("Rate of change is inside the target range for \(profile.goal.label.lowercased()) — hold calories steady.")
            }
        } else {
            out.append("Not enough weight data yet for a reliable trend — log or sync at least ~10 weigh-ins over 2 weeks.")
        }

        if let adh = adherence(sessions: sessions, plan: plan) {
            out.append("Training adherence: \(Int(adh * 100))% of planned sessions in the last 2 weeks." + (adh < 0.75 ? " Consistency beats optimisation — consider dropping to fewer weekly sessions you can actually hit." : ""))
        }

        if checkIn.energy <= 2 || checkIn.sleepQuality <= 2 {
            out.append("Low energy/sleep scores this week — the next block will be volume-adjusted if this persists. Protect a consistent sleep window; it moves the needle more than any supplement.")
        }
        if checkIn.hunger >= 4 && profile.goal == .fatLoss {
            out.append("High hunger is expected in a deficit, but if it's disrupting adherence consider a 1-week diet break at maintenance every 6–8 weeks.")
        }

        let recentFlags = flags.filter { Date().timeIntervalSince($0.date) < 8 * 86400 }
        if !recentFlags.isEmpty {
            out.append("Data notes this week: " + recentFlags.map(\.message).joined(separator: " "))
        }

        if checkIn.photos.isEmpty {
            out.append("No photos attached — same pose, lighting and time of day each week makes visual progress far easier to judge.")
        }

        return (out.joined(separator: "\n\n"), adjustment)
    }
}

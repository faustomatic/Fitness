import Foundation

/// Challenges imported data instead of trusting it blindly. Implausible values
/// are flagged (and excluded from trends where marked `.suspect`), per the
/// principle that MFP/Withings/Ultrahuman data is often imperfect.
enum DataSanityChecker {

    static func check(snapshots: [BiometricSnapshot], profile: UserProfile?) -> [DataQualityFlag] {
        var flags: [DataQualityFlag] = []
        let sorted = snapshots.sorted { $0.date < $1.date }

        // --- Absolute range checks ---
        for s in sorted {
            if let w = s.weightKg, !(30...300).contains(w) {
                flags.append(.init(date: s.date, metric: "weight", severity: .suspect,
                                   message: "Weight \(fmt(w)) kg is outside a plausible range — ignored in trends. Check the unit (lb vs kg?) in \(s.source.label)."))
            }
            if let bf = s.bodyFatPercent, !(3...60).contains(bf) {
                flags.append(.init(date: s.date, metric: "bodyFat", severity: .suspect,
                                   message: "Body fat \(fmt(bf))% is implausible — smart-scale BIA readings can misfire. Ignored."))
            }
            if let sl = s.sleepHours, sl > 0, !(2.5...14).contains(sl) {
                flags.append(.init(date: s.date, metric: "sleep", severity: .caution,
                                   message: "Sleep of \(fmt(sl)) h looks off — possibly a partial or duplicated recording."))
            }
            if let cal = s.caloriesIn, cal > 0, cal < 800 {
                flags.append(.init(date: s.date, metric: "calories", severity: .caution,
                                   message: "Only \(Int(cal)) kcal logged on \(dayString(s.date)) — likely incomplete logging rather than actual intake. Take MFP averages with a pinch of salt."))
            }
            if let p = s.proteinG, let cal = s.caloriesIn, cal > 0, p * 4 > cal {
                flags.append(.init(date: s.date, metric: "macros", severity: .suspect,
                                   message: "Logged protein exceeds total calories on \(dayString(s.date)) — macro entries are inconsistent."))
            }
        }

        // --- Day-to-day jump checks ---
        let weights = sorted.compactMap { s in s.weightKg.map { (s.date, $0) } }
        for i in 1..<max(weights.count, 1) {
            let (d0, w0) = weights[i - 1]
            let (d1, w1) = weights[i]
            let dayGap = max(Calendar.current.dateComponents([.day], from: d0, to: d1).day ?? 1, 1)
            let pctPerDay = abs(w1 - w0) / w0 * 100 / Double(dayGap)
            if pctPerDay > 1.5 {
                flags.append(.init(date: d1, metric: "weight", severity: .caution,
                                   message: "Weight jumped \(fmt(w1 - w0)) kg in \(dayGap) day(s) — almost certainly water/glycogen or a scale glitch, not tissue. Trend uses the smoothed line."))
            }
        }

        let bfs = sorted.compactMap { s in s.bodyFatPercent.map { (s.date, $0) } }
        for i in 1..<max(bfs.count, 1) {
            let (d0, b0) = bfs[i - 1]
            let (d1, b1) = bfs[i]
            let dayGap = max(Calendar.current.dateComponents([.day], from: d0, to: d1).day ?? 1, 1)
            if abs(b1 - b0) / Double(dayGap) > 1.0 {
                flags.append(.init(date: d1, metric: "bodyFat", severity: .caution,
                                   message: "Body fat moved \(fmt(b1 - b0)) pts in \(dayGap) day(s) — BIA scales are hydration-sensitive; treat single readings sceptically."))
            }
        }

        // --- Energy-balance cross-check (logged intake vs actual weight change) ---
        if let profile, weights.count >= 10 {
            let cals = sorted.compactMap(\.caloriesIn)
            if cals.count >= 10 {
                let avgIntake = cals.reduce(0, +) / Double(cals.count)
                let first = weights.prefix(3).map(\.1).reduce(0, +) / Double(min(weights.count, 3))
                let last = weights.suffix(3).map(\.1).reduce(0, +) / 3.0
                let days = max(Calendar.current.dateComponents([.day], from: weights.first!.0, to: weights.last!.0).day ?? 1, 7)
                let impliedTDEE = avgIntake - (last - first) * 7700 / Double(days)
                let est = NutritionEngine.targets(profile: profile, trendWeightKg: last, trendBodyFatPercent: nil).tdee
                if impliedTDEE < Double(est) * 0.7 {
                    flags.append(.init(date: Date(), metric: "calories", severity: .caution,
                                       message: "Your weight change implies you eat ~\(Int(impliedTDEE)) kcal/day but MFP logs average \(Int(avgIntake)). Food logging looks under-reported (very common) — targets are anchored to your measured trend instead."))
                }
            }
        }

        return flags
    }

    private static func fmt(_ v: Double) -> String { String(format: "%.1f", v) }

    private static func dayString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }
}

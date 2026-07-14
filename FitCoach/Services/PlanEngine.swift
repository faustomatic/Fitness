import Foundation

/// Generates and adapts mesocycle-based hypertrophy/strength plans using
/// volume landmarks (MEV→MAV progression, MRV cap), RIR-based effort
/// progression, and a deload week — fitted to the user's time budget.
enum PlanEngine {

    // MARK: Split selection

    struct DayTemplate {
        var name: String
        var muscles: [MuscleGroup]   // in priority order for this day
    }

    static func split(for days: Int) -> (name: String, days: [DayTemplate]) {
        let upperA = DayTemplate(name: "Upper A", muscles: [.chest, .back, .shoulders, .triceps, .biceps])
        let upperB = DayTemplate(name: "Upper B", muscles: [.back, .chest, .shoulders, .biceps, .triceps])
        let lowerA = DayTemplate(name: "Lower A", muscles: [.quads, .hamstrings, .glutes, .calves, .abs])
        let lowerB = DayTemplate(name: "Lower B", muscles: [.hamstrings, .glutes, .quads, .calves, .abs])
        let push = DayTemplate(name: "Push", muscles: [.chest, .shoulders, .triceps])
        let pull = DayTemplate(name: "Pull", muscles: [.back, .biceps, .shoulders])
        let legs = DayTemplate(name: "Legs", muscles: [.quads, .hamstrings, .glutes, .calves, .abs])
        let full = DayTemplate(name: "Full Body", muscles: [.quads, .chest, .back, .hamstrings, .shoulders, .biceps, .triceps, .calves, .abs])

        switch max(2, min(days, 6)) {
        case 2: return ("Full Body ×2", [named(full, "Full Body A"), named(full, "Full Body B")])
        case 3: return ("Full Body ×3", [named(full, "Full Body A"), named(full, "Full Body B"), named(full, "Full Body C")])
        case 4: return ("Upper / Lower", [upperA, lowerA, upperB, lowerB])
        case 5: return ("Upper / Lower + PPL", [upperA, lowerA, push, pull, legs])
        default: return ("Push / Pull / Legs ×2", [push, pull, legs, named(push, "Push B"), named(pull, "Pull B"), named(legs, "Legs B")])
        }
    }

    private static func named(_ t: DayTemplate, _ name: String) -> DayTemplate {
        var c = t; c.name = name; return c
    }

    // MARK: Rep ranges & rest by goal

    static func repRange(goal: Goal, isCompound: Bool) -> (lower: Int, upper: Int, rest: Int) {
        switch goal {
        case .strength:
            return isCompound ? (3, 6, 210) : (8, 12, 90)
        case .hypertrophy, .recomposition:
            return isCompound ? (6, 10, 150) : (10, 15, 90)
        case .fatLoss:
            return isCompound ? (6, 10, 120) : (12, 15, 75)
        }
    }

    /// RIR progression across accumulation weeks: 3 → 1, deload at 4.
    static func targetRIR(week: Int, of totalAccumulation: Int) -> Int {
        guard totalAccumulation > 1 else { return 2 }
        let progress = Double(week) / Double(totalAccumulation - 1)
        return max(1, 3 - Int((progress * 2.0).rounded()))
    }

    // MARK: Generation

    static func generatePlan(profile: UserProfile, recoveryModifier: Double = 1.0) -> TrainingPlan {
        let mesoWeeks = 5   // 4 accumulation + 1 deload
        let accumulation = mesoWeeks - 1
        let (splitName, dayTemplates) = split(for: profile.constraints.daysPerWeek)
        let scale = profile.experience.volumeScale * recoveryModifier

        var weeks: [TrainingWeek] = []
        for w in 0..<mesoWeeks {
            let isDeload = (w == mesoWeeks - 1)
            let rir = isDeload ? 4 : targetRIR(week: w, of: accumulation)
            let weekProgress = isDeload ? 0.0 : Double(w) / Double(max(accumulation - 1, 1))

            // Weekly set target per muscle: MEV → MAV across the meso, capped at MRV.
            var weeklyTargets: [MuscleGroup: Int] = [:]
            for muscle in MuscleGroup.allCases {
                let lm = VolumeLandmarks.base(for: muscle).scaled(by: scale)
                var target = lm.mev + (lm.mav - lm.mev) * weekProgress
                if profile.priorityMuscles.contains(muscle) {
                    target = min(target + 3, lm.mrv)
                }
                if isDeload { target = lm.mev * 0.6 }
                weeklyTargets[muscle] = max(0, Int(target.rounded()))
            }

            let days = buildDays(templates: dayTemplates,
                                 weeklyTargets: weeklyTargets,
                                 profile: profile,
                                 rir: rir,
                                 weekIndex: w)
            weeks.append(TrainingWeek(index: w, isDeload: isDeload, targetRIR: rir, days: days))
        }

        let rationale = buildRationale(profile: profile, splitName: splitName, recoveryModifier: recoveryModifier)
        return TrainingPlan(goal: profile.goal,
                            mesocycleWeeks: mesoWeeks,
                            weeks: weeks,
                            splitName: splitName,
                            rationale: rationale)
    }

    private static func buildDays(templates: [DayTemplate],
                                  weeklyTargets: [MuscleGroup: Int],
                                  profile: UserProfile,
                                  rir: Int,
                                  weekIndex: Int) -> [WorkoutDay] {
        // How many days train each muscle (frequency).
        var frequency: [MuscleGroup: Int] = [:]
        for t in templates {
            for m in t.muscles { frequency[m, default: 0] += 1 }
        }

        var remaining = weeklyTargets
        var days: [WorkoutDay] = []

        for (dayIdx, template) in templates.enumerated() {
            var prescriptions: [ExercisePrescription] = []

            for muscle in template.muscles {
                let freq = max(frequency[muscle] ?? 1, 1)
                let weekly = weeklyTargets[muscle] ?? 0
                guard weekly > 0 else { continue }
                // Spread sets across the days that hit this muscle.
                let baseShare = Int((Double(weekly) / Double(freq)).rounded(.down))
                let extra = remaining[muscle, default: 0] - baseShare * daysLeft(for: muscle, templates: templates, from: dayIdx)
                var setsToday = min(remaining[muscle, default: 0], max(baseShare + max(extra, 0), 0))
                setsToday = min(setsToday, 8)   // per-session per-muscle cap (junk-volume guard)
                guard setsToday >= 2 else { continue }
                remaining[muscle, default: 0] -= setsToday

                let pool = ExerciseLibrary.candidates(for: muscle,
                                                      equipment: profile.equipment,
                                                      avoiding: profile.constraints.injuries)
                guard !pool.isEmpty else { continue }
                // Rotate variants between repeat days so Upper A ≠ Upper B.
                let variantOffset = countPreviousDays(for: muscle, templates: templates, before: dayIdx)

                var setsLeft = setsToday
                var exerciseSlot = 0
                while setsLeft > 0 && exerciseSlot < 3 {
                    let ex = pool[(variantOffset + exerciseSlot) % pool.count]
                    let chunk = ex.isCompound ? min(setsLeft, 4) : min(setsLeft, 3)
                    let (lo, hi, rest) = repRange(goal: profile.goal, isCompound: ex.isCompound)
                    prescriptions.append(ExercisePrescription(exerciseID: ex.id,
                                                              exerciseName: ex.name,
                                                              sets: chunk,
                                                              repLower: lo,
                                                              repUpper: hi,
                                                              targetRIR: rir,
                                                              restSeconds: rest,
                                                              note: ex.cueNotes))
                    setsLeft -= chunk
                    exerciseSlot += 1
                }
            }

            var day = WorkoutDay(name: template.name, focus: template.muscles, exercises: prescriptions)
            trimToTimeBudget(&day, minutes: profile.constraints.minutesPerSession, priorities: profile.priorityMuscles)
            days.append(day)
        }
        return days
    }

    private static func daysLeft(for muscle: MuscleGroup, templates: [DayTemplate], from index: Int) -> Int {
        templates[index...].filter { $0.muscles.contains(muscle) }.count
    }

    private static func countPreviousDays(for muscle: MuscleGroup, templates: [DayTemplate], before index: Int) -> Int {
        templates[..<index].filter { $0.muscles.contains(muscle) }.count
    }

    /// Drop isolation sets (lowest-priority muscles first) until the session fits.
    private static func trimToTimeBudget(_ day: inout WorkoutDay, minutes: Int, priorities: [MuscleGroup]) {
        var guardCounter = 0
        while day.estimatedMinutes > minutes && guardCounter < 50 {
            guardCounter += 1
            // candidate: last isolation exercise of a non-priority muscle with >2 sets, else drop it
            let idx = day.exercises.lastIndex { p in
                guard let ex = ExerciseLibrary.byID(p.exerciseID) else { return false }
                return !ex.isCompound && !priorities.contains(ex.primary)
            } ?? day.exercises.indices.last

            guard let i = idx else { return }
            if day.exercises[i].sets > 2 {
                day.exercises[i].sets -= 1
            } else if day.exercises.count > 3 {
                day.exercises.remove(at: i)
            } else if let j = day.exercises.indices.max(by: { day.exercises[$0].sets < day.exercises[$1].sets }),
                      day.exercises[j].sets > 2 {
                day.exercises[j].sets -= 1
            } else {
                return
            }
        }
    }

    private static func buildRationale(profile: UserProfile, splitName: String, recoveryModifier: Double) -> String {
        var lines: [String] = []
        lines.append("Split: \(splitName) — chosen for \(profile.constraints.daysPerWeek) days/week so each muscle is trained ~2× weekly, which meta-analyses (Schoenfeld 2016) show beats 1× at equal volume.")
        lines.append("Volume: each muscle starts near its minimum effective volume (MEV) and ramps toward maximum adaptive volume (MAV) over 4 weeks, capped at MRV — the Renaissance Periodization landmark model.")
        lines.append("Effort: sets are prescribed by reps-in-reserve (RIR 3 → 1 across the block). Training close to failure drives hypertrophy without the recovery cost of constant failure.")
        lines.append("Progression: double progression — add reps within the range first, then add ~2.5% load and repeat. The app suggests loads from your last logged session.")
        lines.append("Week 5 is a deload (~60% of starting volume, RIR 4, lighter loads) to resensitise and dissipate fatigue before the next mesocycle.")
        if !profile.priorityMuscles.isEmpty {
            lines.append("Priority: extra weekly sets biased toward \(profile.priorityMuscles.map(\.label).joined(separator: ", ")).")
        }
        if !profile.constraints.injuries.isEmpty {
            lines.append("Movements loading your \(profile.constraints.injuries.map(\.label.lowercased()).joined(separator: ", ")) were excluded and replaced with joint-friendly variants.")
        }
        if recoveryModifier < 1.0 {
            lines.append("Volume trimmed \(Int((1 - recoveryModifier) * 100))% because your recent sleep/HRV trend suggests recovery is compromised.")
        }
        lines.append("Sessions are auto-fitted to your \(profile.constraints.minutesPerSession)-minute budget by trimming accessory volume first — compounds are protected.")
        return lines.joined(separator: "\n\n")
    }

    // MARK: Progression suggestions

    /// Suggest next load/reps from history: double progression on the top set.
    static func suggestion(for prescription: ExercisePrescription,
                           history: [WorkoutSession]) -> (weightKg: Double, reps: Int)? {
        let logs = history
            .sorted { $0.date > $1.date }
            .flatMap { $0.logs }
            .filter { $0.exerciseID == prescription.exerciseID }
        guard let recentDate = logs.first?.completedAt else { return nil }
        // Sets from the most recent session containing this exercise.
        let calendar = Calendar.current
        let lastSets = logs.filter { calendar.isDate($0.completedAt, inSameDayAs: recentDate) }
        guard let topSet = lastSets.max(by: { $0.e1RM < $1.e1RM }) else { return nil }

        let allAtTop = lastSets.allSatisfy { $0.reps >= prescription.repUpper }
        if allAtTop {
            let increment = max(topSet.weightKg * 0.025, 1.0)
            let rounded = (topSet.weightKg + increment) / 2.5
            return ((rounded.rounded() * 2.5), prescription.repLower)
        }
        return (topSet.weightKg, min(topSet.reps + 1, prescription.repUpper))
    }

    // MARK: Recovery autoregulation

    /// 0.8–1.0 volume modifier from recent sleep / HRV / recovery-score trends.
    static func recoveryModifier(snapshots: [BiometricSnapshot]) -> Double {
        let recent = snapshots.sorted { $0.date > $1.date }.prefix(7)
        guard !recent.isEmpty else { return 1.0 }

        var penalties = 0.0
        let sleeps = recent.compactMap(\.sleepHours)
        if !sleeps.isEmpty, sleeps.reduce(0, +) / Double(sleeps.count) < 6.0 { penalties += 0.1 }

        let scores = recent.compactMap(\.recoveryScore)
        if !scores.isEmpty, scores.reduce(0, +) / Double(scores.count) < 50 { penalties += 0.1 }

        let hrvs = snapshots.compactMap(\.hrvMs)
        if hrvs.count >= 14 {
            let recentAvg = hrvs.suffix(7).reduce(0, +) / Double(hrvs.suffix(7).count)
            let baseline = hrvs.reduce(0, +) / Double(hrvs.count)
            if recentAvg < baseline * 0.75 { penalties += 0.1 }
        }
        return max(0.8, 1.0 - penalties)
    }
}

import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, quads, hamstrings, glutes, biceps, triceps, calves, abs
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// Weekly-set volume landmarks (Israetel et al. style): minimum effective volume,
/// maximum adaptive volume, maximum recoverable volume.
struct VolumeLandmarks {
    let mev: Double
    let mav: Double
    let mrv: Double

    static func base(for muscle: MuscleGroup) -> VolumeLandmarks {
        switch muscle {
        case .chest: return .init(mev: 8, mav: 16, mrv: 22)
        case .back: return .init(mev: 10, mav: 18, mrv: 25)
        case .shoulders: return .init(mev: 8, mav: 16, mrv: 22)
        case .quads: return .init(mev: 8, mav: 14, mrv: 20)
        case .hamstrings: return .init(mev: 5, mav: 10, mrv: 16)
        case .glutes: return .init(mev: 4, mav: 10, mrv: 16)
        case .biceps: return .init(mev: 6, mav: 14, mrv: 20)
        case .triceps: return .init(mev: 5, mav: 12, mrv: 18)
        case .calves: return .init(mev: 6, mav: 12, mrv: 16)
        case .abs: return .init(mev: 4, mav: 10, mrv: 16)
        }
    }

    func scaled(by factor: Double) -> VolumeLandmarks {
        .init(mev: mev * factor, mav: mav * factor, mrv: mrv * factor)
    }
}

struct Exercise: Codable, Identifiable, Hashable {
    var id: String            // stable slug, e.g. "barbell-bench-press"
    var name: String
    var primary: MuscleGroup
    var secondary: [MuscleGroup] = []
    var equipment: [EquipmentSetting]
    var isCompound: Bool
    /// 1 = first-choice movement, 2 = solid variant, 3 = accessory/fallback.
    var tier: Int
    /// Joints this movement loads heavily; used to filter around injuries.
    var stressedAreas: [InjuryArea] = []
    var cueNotes: String = ""
}

struct ExercisePrescription: Codable, Identifiable, Equatable {
    var id = UUID()
    var exerciseID: String
    var exerciseName: String
    var sets: Int
    var repLower: Int
    var repUpper: Int
    var targetRIR: Int
    var restSeconds: Int
    var note: String = ""
}

struct WorkoutDay: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String                  // "Upper A", "Push", …
    var focus: [MuscleGroup]
    var exercises: [ExercisePrescription]

    var estimatedMinutes: Int {
        // warmup + per-set cost (work + rest), compounds cost more
        let setCost = exercises.reduce(0.0) { acc, p in
            let perSet = Double(p.restSeconds) / 60.0 + 0.75
            return acc + Double(p.sets) * perSet
        }
        return Int((8.0 + setCost).rounded())
    }
}

struct TrainingWeek: Codable, Identifiable, Equatable {
    var id = UUID()
    var index: Int                    // 0-based within mesocycle
    var isDeload: Bool
    var targetRIR: Int
    var days: [WorkoutDay]
}

struct PlanRevision: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var prompt: String
    var summary: String
}

struct TrainingPlan: Codable, Identifiable {
    var id = UUID()
    var createdAt = Date()
    var startDate: Date = Calendar.current.startOfDay(for: Date())
    var goal: Goal
    var mesocycleWeeks: Int
    var weeks: [TrainingWeek]
    var splitName: String
    var rationale: String
    var revisions: [PlanRevision] = []

    /// 0-based index of the current calendar week within the mesocycle (clamped).
    var currentWeekIndex: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return min(max(days / 7, 0), weeks.count - 1)
    }
}

struct SetLog: Codable, Identifiable, Equatable {
    var id = UUID()
    var exerciseID: String
    var setNumber: Int
    var weightKg: Double
    var reps: Int
    var rir: Int?
    var completedAt = Date()

    /// Epley estimated 1RM.
    var e1RM: Double { weightKg * (1.0 + Double(reps) / 30.0) }
}

struct WorkoutSession: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var weekIndex: Int
    var dayID: UUID
    var dayName: String
    var logs: [SetLog] = []
    var durationSeconds: Int = 0
    var notes: String = ""
    var completed: Bool = false
}

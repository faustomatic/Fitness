import Foundation

enum Goal: String, Codable, CaseIterable, Identifiable {
    case hypertrophy, strength, fatLoss, recomposition
    var id: String { rawValue }
    var label: String {
        switch self {
        case .hypertrophy: return "Build Muscle"
        case .strength: return "Get Stronger"
        case .fatLoss: return "Lose Fat"
        case .recomposition: return "Recomposition"
        }
    }
    /// Expected body-weight change, % of body weight per week. Used to judge progress.
    var expectedWeeklyRatePercent: ClosedRange<Double> {
        switch self {
        case .hypertrophy: return 0.1...0.4
        case .strength: return 0.0...0.4
        case .fatLoss: return -1.0...(-0.4)
        case .recomposition: return -0.25...0.15
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    /// Multiplier applied to volume landmarks.
    var volumeScale: Double {
        switch self {
        case .beginner: return 0.7
        case .intermediate: return 1.0
        case .advanced: return 1.15
        }
    }
}

enum Sex: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum EquipmentSetting: String, Codable, CaseIterable, Identifiable {
    case fullGym, barbellRack, dumbbellsOnly, machinesOnly, bandsBodyweight
    var id: String { rawValue }
    var label: String {
        switch self {
        case .fullGym: return "Full commercial gym"
        case .barbellRack: return "Barbell + rack (home gym)"
        case .dumbbellsOnly: return "Dumbbells only"
        case .machinesOnly: return "Machines only"
        case .bandsBodyweight: return "Bands / bodyweight"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, high, athlete
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sedentary: return "Sedentary (desk job, little walking)"
        case .light: return "Lightly active (some walking)"
        case .moderate: return "Moderately active (on feet part of day)"
        case .high: return "Very active (physical job)"
        case .athlete: return "Extremely active"
        }
    }
    /// Multiplier over BMR, excluding formal training (training is added separately).
    var factor: Double {
        switch self {
        case .sedentary: return 1.25
        case .light: return 1.4
        case .moderate: return 1.55
        case .high: return 1.7
        case .athlete: return 1.85
        }
    }
}

enum InjuryArea: String, Codable, CaseIterable, Identifiable {
    case shoulder, elbow, wrist, lowerBack, hip, knee, ankle
    var id: String { rawValue }
    var label: String {
        switch self {
        case .lowerBack: return "Lower back"
        default: return rawValue.capitalized
        }
    }
}

struct TrainingConstraints: Codable, Equatable {
    var daysPerWeek: Int = 4
    var minutesPerSession: Int = 60
    /// 1 = Sunday ... 7 = Saturday (Calendar weekday numbering).
    var preferredWeekdays: [Int] = []
    var injuries: [InjuryArea] = []
}

struct UserProfile: Codable, Identifiable {
    var id = UUID()
    var name: String = ""
    var sex: Sex = .male
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -35, to: Date()) ?? Date()
    var heightCm: Double = 178
    /// Onboarding answers; live weight/BF come from BiometricSnapshots.
    var startWeightKg: Double = 80
    var startBodyFatPercent: Double?
    var goal: Goal = .hypertrophy
    var experience: ExperienceLevel = .intermediate
    var equipment: EquipmentSetting = .fullGym
    var activityLevel: ActivityLevel = .light
    var constraints = TrainingConstraints()
    /// Muscle groups the user asked to emphasise (via questionnaire or coach chat).
    var priorityMuscles: [MuscleGroup] = []
    var dietaryNotes: String = ""
    /// Anthropic API key for the conversational coach (optional; rule-based fallback works without it).
    var anthropicAPIKey: String = ""
    var checkInWeekday: Int = 1   // Sunday
    var checkInHour: Int = 9
    var createdAt = Date()

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 35
    }
}

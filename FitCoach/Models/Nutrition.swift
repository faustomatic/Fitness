import Foundation

struct NutritionTargets: Codable, Equatable {
    var calories: Int
    var proteinG: Int
    var carbsG: Int
    var fatG: Int
    var bmr: Int
    var tdee: Int
    /// Which BMR formula was used (Katch-McArdle when body-fat % is known).
    var method: String
    var rationale: String
    var updatedAt = Date()

    var proteinCalories: Int { proteinG * 4 }
    var carbCalories: Int { carbsG * 4 }
    var fatCalories: Int { fatG * 9 }
}

struct SupplementRecommendation: Codable, Identifiable, Equatable {
    var id: String { name }
    var name: String
    var dose: String
    var timing: String
    var evidence: String   // short evidence-grade note
}

struct MealTimingAdvice: Codable, Identifiable, Equatable {
    var id: String { title }
    var title: String
    var detail: String
}

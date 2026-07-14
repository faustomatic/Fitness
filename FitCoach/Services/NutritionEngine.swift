import Foundation

/// Computes calorie & macro targets and evidence-based supplement/meal-timing
/// advice. Uses Katch-McArdle when body-fat % is known (better for trained
/// individuals), Mifflin-St Jeor otherwise. Weight/BF come from the smoothed
/// biometric trend, not raw scale readings.
enum NutritionEngine {

    static func targets(profile: UserProfile,
                        trendWeightKg: Double?,
                        trendBodyFatPercent: Double?) -> NutritionTargets {
        let weight = trendWeightKg ?? profile.startWeightKg
        let bodyFat = trendBodyFatPercent ?? profile.startBodyFatPercent

        let bmr: Double
        let method: String
        if let bf = bodyFat, bf > 3, bf < 60 {
            let leanMass = weight * (1 - bf / 100)
            bmr = 370 + 21.6 * leanMass
            method = "Katch-McArdle (lean mass \(String(format: "%.1f", leanMass)) kg)"
        } else {
            let s: Double = profile.sex == .male ? 5 : -161
            bmr = 10 * weight + 6.25 * profile.heightCm - 5 * Double(profile.age) + s
            method = "Mifflin-St Jeor"
        }

        // TDEE: lifestyle multiplier + explicit training cost (~7.5 kcal/min lifting, averaged over the week).
        let weeklyTrainingKcal = Double(profile.constraints.daysPerWeek * profile.constraints.minutesPerSession) * 7.5
        let tdee = bmr * profile.activityLevel.factor + weeklyTrainingKcal / 7.0

        let calories: Double
        let goalNote: String
        switch profile.goal {
        case .fatLoss:
            calories = max(tdee * 0.80, bmr * 1.05)
            goalNote = "20% deficit — targets ~0.5–0.75% of body weight lost per week while sparing muscle. Floor set just above BMR."
        case .hypertrophy:
            calories = tdee * 1.10
            goalNote = "10% surplus — enough to support muscle growth (~0.25% BW/week gain) without excess fat accrual."
        case .strength:
            calories = tdee * 1.05
            goalNote = "Slight surplus to support performance and recovery."
        case .recomposition:
            calories = tdee * 0.97
            goalNote = "Roughly maintenance — recomposition is driven by high protein + progressive training."
        }

        // Protein: g/kg of body weight (upper range when dieting; per lean mass when very high BF).
        let proteinPerKg: Double = (profile.goal == .fatLoss) ? 2.2 : 1.8
        var protein = weight * proteinPerKg
        if let bf = bodyFat, bf > 30 {
            protein = weight * (1 - bf / 100) * 2.6   // scale by lean mass instead
        }

        // Fat: 0.8 g/kg, floored at 20% of calories (hormonal health).
        let fat = max(weight * 0.8, calories * 0.20 / 9)
        let carbs = max((calories - protein * 4 - fat * 9) / 4, 0)

        let rationale = """
        \(goalNote)

        Protein \(Int(protein)) g (\(String(format: "%.1f", protein / weight)) g/kg): the 1.6–2.2 g/kg range maximises muscle protein synthesis (Morton 2018 meta-analysis); dieting pushes you to the top of it.

        Fat \(Int(fat)) g: ≥0.8 g/kg and ≥20% of calories to support hormone production.

        Carbs \(Int(carbs)) g: the remainder — fuels training volume and recovery. Bias them around workouts.

        Recalculated from your trend weight, not single weigh-ins. The weekly check-in adjusts calories ±100–200 kcal if your actual rate of change drifts off target for 2+ weeks.
        """

        return NutritionTargets(calories: Int(calories.rounded()),
                                proteinG: Int(protein.rounded()),
                                carbsG: Int(carbs.rounded()),
                                fatG: Int(fat.rounded()),
                                bmr: Int(bmr.rounded()),
                                tdee: Int(tdee.rounded()),
                                method: method,
                                rationale: rationale)
    }

    // MARK: Supplements (evidence-graded, no fluff)

    static func supplements(profile: UserProfile) -> [SupplementRecommendation] {
        var list: [SupplementRecommendation] = [
            .init(name: "Creatine Monohydrate",
                  dose: "3–5 g daily",
                  timing: "Any time, every day (consistency beats timing). No loading needed.",
                  evidence: "Strongest evidence of any supplement: +strength, +lean mass, possible cognitive benefit."),
            .init(name: "Caffeine",
                  dose: "\(Int((profile.startWeightKg * 2).rounded())) –\(Int((profile.startWeightKg * 3).rounded())) mg (2–3 mg/kg)",
                  timing: "30–45 min pre-workout. Cut off 8+ h before bed to protect sleep.",
                  evidence: "Well-established ergogenic for strength & training volume."),
            .init(name: "Whey / Casein Protein",
                  dose: "As needed to hit daily protein",
                  timing: "Convenient post-workout or between meals; casein works well pre-sleep.",
                  evidence: "Food first — powder is just a convenient protein source."),
            .init(name: "Vitamin D3",
                  dose: "1000–2000 IU",
                  timing: "With a meal containing fat.",
                  evidence: "Worth taking if you get limited sun; supports bone & hormonal health. Ideally test levels."),
            .init(name: "Omega-3 (EPA+DHA)",
                  dose: "1–2 g combined EPA+DHA",
                  timing: "With meals.",
                  evidence: "Cardiovascular & joint support, especially if you eat little oily fish.")
        ]
        if profile.goal == .fatLoss {
            list.append(.init(name: "Electrolytes / Sodium",
                              dose: "To taste, especially around training",
                              timing: "Pre/intra-workout on low-calorie days.",
                              evidence: "Practical aid — deficits increase electrolyte losses; helps training quality."))
        }
        return list
    }

    static func mealTiming(profile: UserProfile) -> [MealTimingAdvice] {
        [
            .init(title: "Protein distribution",
                  detail: "Split protein over 3–5 meals of ~0.4 g/kg (~\(Int((profile.startWeightKg * 0.4).rounded())) g each). Per-meal distribution matters less than the daily total, but this pattern maximises synthesis."),
            .init(title: "Around training",
                  detail: "Have a protein + carb meal 1–3 h before lifting and another within ~2 h after. The 'anabolic window' is wide — total intake matters most."),
            .init(title: "Pre-sleep",
                  detail: "30–40 g slow protein (casein, Greek yogurt, cottage cheese) before bed supports overnight muscle protein synthesis."),
            .init(title: "Carb placement",
                  detail: "Bias carbs to the meals before and after your session for training quality; keep some at night if it helps you sleep."),
            .init(title: "What not to buy",
                  detail: "BCAAs (redundant with adequate protein), fat burners, and testosterone boosters have poor evidence. Spend the money on food.")
        ]
    }
}

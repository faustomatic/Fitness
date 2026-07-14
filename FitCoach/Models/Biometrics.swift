import Foundation

enum DataSource: String, Codable, CaseIterable, Identifiable {
    case healthKit, myFitnessPal, withings, ultrahuman, manual, csvImport
    var id: String { rawValue }
    var label: String {
        switch self {
        case .healthKit: return "Apple Health"
        case .myFitnessPal: return "MyFitnessPal"
        case .withings: return "Withings"
        case .ultrahuman: return "Ultrahuman"
        case .manual: return "Manual"
        case .csvImport: return "File import"
        }
    }
}

/// One day of biometric data, merged from whatever sources reported that day.
struct BiometricSnapshot: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Start of day, local calendar.
    var date: Date
    var source: DataSource
    var weightKg: Double?
    var bodyFatPercent: Double?
    var leanMassKg: Double?
    var restingHeartRate: Double?
    var hrvMs: Double?
    var sleepHours: Double?
    /// Ultrahuman recovery / readiness style score, 0–100.
    var recoveryScore: Double?
    var caloriesIn: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var steps: Double?
    var activeEnergyKcal: Double?
}

enum FlagSeverity: String, Codable {
    case info, caution, suspect
}

/// Result of sanity-checking imported data: imperfect data is kept but flagged,
/// and downstream engines use smoothed trends rather than raw values.
struct DataQualityFlag: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var metric: String
    var severity: FlagSeverity
    var message: String
}

struct ImportSummary {
    var added: Int
    var merged: Int
    var flags: [DataQualityFlag]
}

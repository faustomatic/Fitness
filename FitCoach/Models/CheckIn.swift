import Foundation

enum PhotoAngle: String, Codable, CaseIterable, Identifiable {
    case front, side, back
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct CheckInPhoto: Codable, Identifiable, Equatable {
    var id = UUID()
    var angle: PhotoAngle
    /// Filename inside the app's Photos directory.
    var filename: String
}

struct CheckIn: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var weightKg: Double?
    var waistCm: Double?
    /// 1–5 subjective scales.
    var energy: Int = 3
    var sleepQuality: Int = 3
    var hunger: Int = 3
    var trainingMotivation: Int = 3
    var notes: String = ""
    var photos: [CheckInPhoto] = []
    /// Generated progress analysis, stored so it can be revisited.
    var analysis: String = ""
}

struct ChatMessage: Codable, Identifiable {
    var id = UUID()
    var role: String        // "user" | "coach"
    var text: String
    var date = Date()
    var planChanged: Bool = false
}

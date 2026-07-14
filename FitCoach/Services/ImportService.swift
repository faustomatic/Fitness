import Foundation

/// Fallback ingestion path: parses native export files from MyFitnessPal
/// (Nutrition-Summary CSV), Withings (weight CSV) and Ultrahuman (CSV/JSON),
/// plus any generic CSV with recognisable column headers.
enum ImportService {

    enum ImportError: LocalizedError {
        case unreadable, noRows, unrecognisedFormat
        var errorDescription: String? {
            switch self {
            case .unreadable: return "Couldn't read the file."
            case .noRows: return "The file had no data rows."
            case .unrecognisedFormat: return "Couldn't recognise any known columns (date, weight, calories, protein, HRV, sleep…). Export the raw CSV from the source app and try again."
            }
        }
    }

    static func importFile(at url: URL, hint: DataSource) throws -> [BiometricSnapshot] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }

        if url.pathExtension.lowercased() == "json" {
            return try parseJSON(data, source: hint)
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.unreadable
        }
        return try parseCSV(text, source: hint)
    }

    // MARK: CSV

    static func parseCSV(_ text: String, source: DataSource) throws -> [BiometricSnapshot] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { throw ImportError.noRows }

        let header = splitCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        func col(_ candidates: [String]) -> Int? {
            for c in candidates {
                if let i = header.firstIndex(where: { $0 == c }) { return i }
            }
            for c in candidates {
                if let i = header.firstIndex(where: { $0.contains(c) }) { return i }
            }
            return nil
        }

        let dateCol = col(["date", "day", "timestamp", "time"])
        let weightCol = col(["weight (kg)", "weight"])
        let fatMassCol = col(["fat mass (kg)"])
        let bodyFatCol = col(["fat (%)", "body fat", "fat_ratio", "body_fat"])
        let caloriesCol = col(["calories", "energy (kcal)", "kcal_in", "energy"])
        let proteinCol = col(["protein (g)", "protein"])
        let carbsCol = col(["carbohydrates (g)", "carbs (g)", "carbohydrates", "carbs"])
        let fatGCol = col(["fat (g)"]) ?? (bodyFatCol == nil && fatMassCol == nil ? col(["fat"]) : nil)
        let hrvCol = col(["hrv", "heart rate variability", "avg_hrv", "night hrv"])
        let rhrCol = col(["resting heart rate", "resting_hr", "rhr", "lowest heart rate"])
        let sleepCol = col(["sleep duration", "total sleep", "sleep (h)", "asleep duration", "time asleep", "sleep hours"])
        let recoveryCol = col(["recovery", "readiness", "recovery score", "recovery index"])
        let stepsCol = col(["steps", "step count"])

        guard let dateCol else { throw ImportError.unrecognisedFormat }
        let hasAnyMetric = [weightCol, fatMassCol, bodyFatCol, caloriesCol, proteinCol, carbsCol, fatGCol, hrvCol, rhrCol, sleepCol, recoveryCol, stepsCol]
            .contains { $0 != nil }
        guard hasAnyMetric else { throw ImportError.unrecognisedFormat }

        // MFP exports one row per meal — accumulate per day.
        var byDay: [Date: BiometricSnapshot] = [:]
        let cal = Calendar.current

        for line in lines.dropFirst() {
            let fields = splitCSVLine(line)
            guard fields.count > dateCol, let date = parseDate(fields[dateCol]) else { continue }
            let day = cal.startOfDay(for: date)
            var snap = byDay[day] ?? BiometricSnapshot(date: day, source: source)

            func value(_ i: Int?) -> Double? {
                guard let i, fields.count > i else { return nil }
                let cleaned = fields[i].replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return Double(cleaned)
            }

            if let w = value(weightCol) { snap.weightKg = w }
            if let fm = value(fatMassCol), let w = snap.weightKg, w > 0 { snap.bodyFatPercent = fm / w * 100 }
            if let bf = value(bodyFatCol) { snap.bodyFatPercent = bf }
            if let c = value(caloriesCol) { snap.caloriesIn = (snap.caloriesIn ?? 0) + c }
            if let p = value(proteinCol) { snap.proteinG = (snap.proteinG ?? 0) + p }
            if let cb = value(carbsCol) { snap.carbsG = (snap.carbsG ?? 0) + cb }
            if let f = value(fatGCol) { snap.fatG = (snap.fatG ?? 0) + f }
            if let h = value(hrvCol) { snap.hrvMs = h }
            if let r = value(rhrCol) { snap.restingHeartRate = r }
            if let s = value(sleepCol) { snap.sleepHours = s > 20 ? s / 60 : s }  // minutes → hours heuristic
            if let rec = value(recoveryCol) { snap.recoveryScore = rec }
            if let st = value(stepsCol) { snap.steps = st }

            byDay[day] = snap
        }

        let result = byDay.values.sorted { $0.date < $1.date }
        guard !result.isEmpty else { throw ImportError.noRows }
        return result
    }

    /// Minimal CSV field splitter with quoted-field support.
    static func splitCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle(); continue }
            if ch == "," && !inQuotes { fields.append(current); current = ""; continue }
            current.append(ch)
        }
        fields.append(current)
        return fields
    }

    static func parseDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
        if let iso = ISO8601DateFormatter().date(from: s) { return iso }
        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy", "d MMM yyyy", "MMM d, yyyy"]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    // MARK: JSON (Ultrahuman-style exports)

    static func parseJSON(_ data: Data, source: DataSource) throws -> [BiometricSnapshot] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { throw ImportError.unreadable }
        var rows: [[String: Any]] = []
        if let arr = obj as? [[String: Any]] {
            rows = arr
        } else if let dict = obj as? [String: Any] {
            for key in ["data", "days", "records", "metrics"] {
                if let arr = dict[key] as? [[String: Any]] { rows = arr; break }
            }
        }
        guard !rows.isEmpty else { throw ImportError.unrecognisedFormat }

        var out: [BiometricSnapshot] = []
        for row in rows {
            let dateRaw = (row["date"] ?? row["day"] ?? row["timestamp"]) as? String
            guard let dateRaw, let date = parseDate(dateRaw) else { continue }
            var snap = BiometricSnapshot(date: Calendar.current.startOfDay(for: date), source: source)

            func num(_ keys: [String]) -> Double? {
                for k in keys {
                    if let v = row[k] as? Double { return v }
                    if let v = row[k] as? Int { return Double(v) }
                    if let v = row[k] as? String, let d = Double(v) { return d }
                }
                return nil
            }
            snap.hrvMs = num(["hrv", "avg_hrv", "night_hrv"])
            snap.restingHeartRate = num(["resting_heart_rate", "rhr", "lowest_hr"])
            if let sl = num(["sleep_duration", "total_sleep", "sleep_hours", "asleep_minutes"]) {
                snap.sleepHours = sl > 20 ? sl / 60 : sl
            }
            snap.recoveryScore = num(["recovery_score", "recovery", "readiness"])
            snap.steps = num(["steps", "step_count"])
            snap.weightKg = num(["weight", "weight_kg"])
            snap.caloriesIn = num(["calories", "kcal_in", "energy_kcal"])
            out.append(snap)
        }
        guard !out.isEmpty else { throw ImportError.noRows }
        return out.sorted { $0.date < $1.date }
    }
}

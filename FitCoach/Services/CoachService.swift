import Foundation

/// Conversational plan pivoting. A rule-based intent engine handles the common
/// requests offline; when an Anthropic API key is configured, unmatched
/// prompts are sent to Claude with the plan + profile as context.
enum CoachService {

    struct CoachResult {
        var reply: String
        var updatedProfile: UserProfile?
        var regeneratePlan: Bool
        var deloadNow: Bool = false
    }

    // MARK: Entry point

    static func respond(to prompt: String, profile: UserProfile, plan: TrainingPlan?) async -> CoachResult {
        if let local = localIntent(prompt: prompt, profile: profile) {
            return local
        }
        if !profile.anthropicAPIKey.isEmpty {
            do {
                return try await claudeIntent(prompt: prompt, profile: profile, plan: plan)
            } catch {
                return CoachResult(reply: "I couldn't reach the AI coach (\(error.localizedDescription)). Try again, or use direct commands like “more chest”, “train 5 days”, “shorter sessions”, “my knee hurts”, “make it harder”.", updatedProfile: nil, regeneratePlan: false)
            }
        }
        return CoachResult(reply: """
            I can adjust your plan with commands like:
            • “more <muscle>” / “less <muscle>” — shift weekly volume
            • “train N days a week” — change your split
            • “shorter sessions” / “I only have 45 minutes” — refit the time budget
            • “my <shoulder/knee/back/…> hurts” — swap out aggravating movements
            • “make it harder” / “make it easier” / “I need a deload”
            • “switch goal to fat loss / muscle / strength”

            Add an Anthropic API key in Settings to unlock free-form coaching conversations.
            """, updatedProfile: nil, regeneratePlan: false)
    }

    // MARK: Rule-based intents

    static func localIntent(prompt: String, profile: UserProfile) -> CoachResult? {
        let p = prompt.lowercased()
        var profile = profile

        // Injury / pain
        for area in InjuryArea.allCases {
            let words: [String]
            switch area {
            case .lowerBack: words = ["lower back", "low back", "back pain", "back hurts"]
            default: words = [area.rawValue]
            }
            if words.contains(where: p.contains) && ["hurt", "pain", "sore", "injur", "tweak"].contains(where: p.contains) {
                if !profile.constraints.injuries.contains(area) {
                    profile.constraints.injuries.append(area)
                }
                return CoachResult(reply: "Sorry to hear that. I've flagged your \(area.label.lowercased()) and rebuilt the plan without movements that load it heavily — joint-friendly variants are in their place. If pain persists more than a week or two, see a physio; train around pain, never through it.", updatedProfile: profile, regeneratePlan: true)
            }
        }

        // Muscle emphasis
        for muscle in MuscleGroup.allCases {
            let aliases: [String]
            switch muscle {
            case .biceps: aliases = ["biceps", "arms", "bicep"]
            case .triceps: aliases = ["triceps", "tricep"]
            case .shoulders: aliases = ["shoulders", "delts"]
            case .quads: aliases = ["quads", "legs"]
            case .abs: aliases = ["abs", "core", "six pack"]
            default: aliases = [muscle.rawValue]
            }
            if aliases.contains(where: p.contains) {
                if ["more", "bigger", "grow", "prioriti", "focus"].contains(where: p.contains) {
                    if !profile.priorityMuscles.contains(muscle) { profile.priorityMuscles.append(muscle) }
                    return CoachResult(reply: "Done — \(muscle.label) is now a priority. I've added ~3 extra weekly sets (capped at its maximum recoverable volume) and protected it when sessions get trimmed for time.", updatedProfile: profile, regeneratePlan: true)
                }
                if ["less", "reduce", "too much", "drop"].contains(where: p.contains) {
                    profile.priorityMuscles.removeAll { $0 == muscle }
                    return CoachResult(reply: "Okay — \(muscle.label) volume is back to the standard MEV→MAV ramp and will be first in line when trimming for time.", updatedProfile: profile, regeneratePlan: true)
                }
            }
        }

        // Days per week
        if let days = firstInt(in: p), ["day", "days", "session"].contains(where: p.contains),
           ["train", "week", "switch", "change", "only", "do "].contains(where: p.contains),
           (2...6).contains(days) {
            profile.constraints.daysPerWeek = days
            let (splitName, _) = PlanEngine.split(for: days)
            return CoachResult(reply: "Rebuilt for \(days) days/week on a \(splitName) split — still hitting every muscle about twice a week.", updatedProfile: profile, regeneratePlan: true)
        }

        // Session length
        if ["shorter", "less time", "quicker", "quick session"].contains(where: p.contains) || (p.contains("minute") && firstInt(in: p) != nil) {
            if let mins = firstInt(in: p), (20...180).contains(mins) {
                profile.constraints.minutesPerSession = mins
            } else {
                profile.constraints.minutesPerSession = max(30, Int(Double(profile.constraints.minutesPerSession) * 0.75))
            }
            return CoachResult(reply: "Sessions refitted to ~\(profile.constraints.minutesPerSession) minutes. Accessory volume was trimmed first; the big rocks stay.", updatedProfile: profile, regeneratePlan: true)
        }

        // Intensity
        if ["harder", "more intense", "challenge", "not enough"].contains(where: p.contains) {
            var boosted = profile
            boosted.experience = profile.experience == .beginner ? .intermediate : .advanced
            return CoachResult(reply: "Pushed volume landmarks up a tier — expect ~15% more weekly sets and RIR reaching 1 sooner. If performance drops across two consecutive sessions, tell me and I'll pull it back.", updatedProfile: boosted, regeneratePlan: true)
        }
        if ["easier", "too much", "exhausted", "burned out", "burnt out"].contains(where: p.contains) {
            var eased = profile
            eased.experience = profile.experience == .advanced ? .intermediate : .beginner
            return CoachResult(reply: "Dialled the volume down a tier. Fatigue is information — better to grow from the minimum effective dose than to dig a recovery hole.", updatedProfile: eased, regeneratePlan: true)
        }
        if ["deload", "recovery week", "need a break"].contains(where: p.contains) {
            return CoachResult(reply: "Starting a deload: this week runs at ~60% volume, RIR 4, loads about 10% lighter. Sleep and eat normally — you'll come back stronger next week.", updatedProfile: nil, regeneratePlan: false, deloadNow: true)
        }

        // Goal switch
        for goal in Goal.allCases {
            let keys: [String]
            switch goal {
            case .fatLoss: keys = ["fat loss", "lose fat", "lose weight", "cut", "lean out"]
            case .hypertrophy: keys = ["build muscle", "muscle", "bulk", "size", "hypertrophy"]
            case .strength: keys = ["strength", "stronger", "powerlifting"]
            case .recomposition: keys = ["recomp"]
            }
            if keys.contains(where: p.contains) && ["goal", "switch", "change", "want to", "focus on"].contains(where: p.contains) {
                profile.goal = goal
                return CoachResult(reply: "Goal switched to \(goal.label.lowercased()). Rep ranges, rest periods and your calorie/macro targets have all been recalculated — check the Nutrition tab.", updatedProfile: profile, regeneratePlan: true)
            }
        }

        return nil
    }

    private static func firstInt(in text: String) -> Int? {
        let digits = text.split(whereSeparator: { !$0.isNumber })
        return digits.compactMap { Int($0) }.first
    }

    // MARK: Claude API

    private struct APIResponse: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }

    static func claudeIntent(prompt: String, profile: UserProfile, plan: TrainingPlan?) async throws -> CoachResult {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(profile.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let planSummary = plan.map { pl in
            pl.weeks.first.map { week in
                week.days.map { d in "\(d.name): " + d.exercises.map { "\($0.exerciseName) \($0.sets)×\($0.repLower)-\($0.repUpper) @RIR \($0.targetRIR)" }.joined(separator: "; ") }.joined(separator: "\n")
            } ?? ""
        } ?? "No plan yet."

        let system = """
        You are an evidence-based strength coach inside the FitCoach iOS app. \
        User: \(profile.sex.rawValue), \(profile.age)y, \(Int(profile.startWeightKg))kg, goal \(profile.goal.rawValue), \
        \(profile.experience.rawValue), \(profile.constraints.daysPerWeek)d/week × \(profile.constraints.minutesPerSession)min, \
        injuries: \(profile.constraints.injuries.map(\.rawValue).joined(separator: ",")). \
        Current week 1 plan:\n\(planSummary)\n\
        Answer in under 150 words, practically and scientifically. If the user asks for a structural change, \
        end your reply with exactly one directive line: DIRECTIVE: {"daysPerWeek": n?, "minutesPerSession": n?, \
        "priorityMuscles": [..]?, "goal": "..."?, "regenerate": true} — omit the line entirely for pure Q&A.
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-5",
            "max_tokens": 600,
            "system": system,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "FitCoach", code: 2, userInfo: [NSLocalizedDescriptionKey: "API error (\((response as? HTTPURLResponse)?.statusCode ?? 0)). Check your key in Settings."])
        }
        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        var text = decoded.content.compactMap(\.text).joined(separator: "\n")

        var updated: UserProfile? = nil
        var regenerate = false
        if let range = text.range(of: "DIRECTIVE:") {
            let jsonPart = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            text = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let jd = jsonPart.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: jd) as? [String: Any] {
                var prof = profile
                if let d = obj["daysPerWeek"] as? Int, (2...6).contains(d) { prof.constraints.daysPerWeek = d }
                if let m = obj["minutesPerSession"] as? Int, (20...180).contains(m) { prof.constraints.minutesPerSession = m }
                if let pm = obj["priorityMuscles"] as? [String] {
                    prof.priorityMuscles = pm.compactMap { MuscleGroup(rawValue: $0) }
                }
                if let g = obj["goal"] as? String, let goal = Goal(rawValue: g) { prof.goal = goal }
                regenerate = (obj["regenerate"] as? Bool) ?? false
                updated = prof
            }
        }
        return CoachResult(reply: text, updatedProfile: updated, regeneratePlan: regenerate)
    }
}

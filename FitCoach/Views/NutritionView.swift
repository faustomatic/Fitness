import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let n = appState.nutrition {
                        calorieCard(n)
                        macroCard(n)
                        rationaleCard(n)
                    } else {
                        ContentUnavailableView("No targets yet", systemImage: "fork.knife",
                                               description: Text("Finish onboarding to compute your calories and macros."))
                    }
                    timingCard
                    supplementsCard
                }
                .padding()
            }
            .navigationTitle("Nutrition")
            .toolbar {
                Button {
                    appState.recalcNutrition()
                } label: {
                    Label("Recalculate", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private func calorieCard(_ n: NutritionTargets) -> some View {
        VStack(spacing: 6) {
            Text("\(n.calories)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
            Text("kcal / day").foregroundStyle(.secondary)
            HStack(spacing: 16) {
                statPill("BMR", "\(n.bmr)")
                statPill("TDEE", "\(n.tdee)")
            }
            Text(n.method).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statPill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Color(.tertiarySystemFill))
        .clipShape(Capsule())
    }

    private func macroCard(_ n: NutritionTargets) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macros").font(.subheadline).foregroundStyle(.secondary)
            macroBar("Protein", grams: n.proteinG, calories: n.proteinCalories, total: n.calories, color: .blue)
            macroBar("Carbs", grams: n.carbsG, calories: n.carbCalories, total: n.calories, color: .green)
            macroBar("Fat", grams: n.fatG, calories: n.fatCalories, total: n.calories, color: .orange)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func macroBar(_ name: String, grams: Int, calories: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.footnote.bold())
                Spacer()
                Text("\(grams) g · \(Int(Double(calories) / Double(max(total, 1)) * 100))%")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(calories) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 8)
        }
    }

    private func rationaleCard(_ n: NutritionTargets) -> some View {
        DisclosureGroup {
            Text(n.rationale)
                .font(.footnote)
                .padding(.top, 4)
        } label: {
            Label("Why these numbers", systemImage: "info.circle")
                .font(.subheadline.bold())
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meal timing").font(.subheadline).foregroundStyle(.secondary)
            if let profile = appState.profile {
                ForEach(NutritionEngine.mealTiming(profile: profile)) { advice in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(advice.title).font(.footnote.bold())
                        Text(advice.detail).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var supplementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supplements (evidence-based only)").font(.subheadline).foregroundStyle(.secondary)
            if let profile = appState.profile {
                ForEach(NutritionEngine.supplements(profile: profile)) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(s.name).font(.footnote.bold())
                            Spacer()
                            Text(s.dose).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Timing: \(s.timing)").font(.caption).foregroundStyle(.secondary)
                        Text(s.evidence).font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
            Text("Not medical advice — check with your doctor if you take medication.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

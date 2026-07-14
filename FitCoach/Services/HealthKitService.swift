import Foundation
import HealthKit

/// Primary connectivity path: MyFitnessPal, Withings and Ultrahuman all sync
/// to Apple Health, so reading HealthKit gives live data from all three with
/// no partner API keys. File import (ImportService) is the fallback.
final class HealthKitService {

    static let shared = HealthKitService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        let ids: [HKQuantityTypeIdentifier] = [
            .bodyMass, .bodyFatPercentage, .leanBodyMass,
            .restingHeartRate, .heartRateVariabilitySDNN,
            .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal,
            .stepCount, .activeEnergyBurned
        ]
        for id in ids {
            if let t = HKObjectType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        return types
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw NSError(domain: "FitCoach", code: 1, userInfo: [NSLocalizedDescriptionKey: "Health data isn't available on this device."]) }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Pull the last `days` days of daily data, merged into one snapshot per day.
    func fetchSnapshots(days: Int = 90) async throws -> [BiometricSnapshot] {
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: end))!

        async let weight = dailyValues(.bodyMass, unit: .gramUnit(with: .kilo), from: start, to: end, aggregate: .discreteAverage)
        async let bodyFat = dailyValues(.bodyFatPercentage, unit: .percent(), from: start, to: end, aggregate: .discreteAverage)
        async let leanMass = dailyValues(.leanBodyMass, unit: .gramUnit(with: .kilo), from: start, to: end, aggregate: .discreteAverage)
        async let rhr = dailyValues(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), from: start, to: end, aggregate: .discreteAverage)
        async let hrv = dailyValues(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), from: start, to: end, aggregate: .discreteAverage)
        async let kcalIn = dailyValues(.dietaryEnergyConsumed, unit: .kilocalorie(), from: start, to: end, aggregate: .cumulativeSum)
        async let protein = dailyValues(.dietaryProtein, unit: .gram(), from: start, to: end, aggregate: .cumulativeSum)
        async let carbs = dailyValues(.dietaryCarbohydrates, unit: .gram(), from: start, to: end, aggregate: .cumulativeSum)
        async let fat = dailyValues(.dietaryFatTotal, unit: .gram(), from: start, to: end, aggregate: .cumulativeSum)
        async let steps = dailyValues(.stepCount, unit: .count(), from: start, to: end, aggregate: .cumulativeSum)
        async let active = dailyValues(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end, aggregate: .cumulativeSum)
        async let sleep = sleepHoursByDay(from: start, to: end)

        let maps: [[Date: Double]] = try await [weight, bodyFat, leanMass, rhr, hrv, kcalIn, protein, carbs, fat, steps, active, sleep]
        let allDays = Set(maps.flatMap { $0.keys })

        return allDays.sorted().map { day in
            var s = BiometricSnapshot(date: day, source: .healthKit)
            s.weightKg = maps[0][day]
            s.bodyFatPercent = maps[1][day].map { $0 * 100 }
            s.leanMassKg = maps[2][day]
            s.restingHeartRate = maps[3][day]
            s.hrvMs = maps[4][day]
            s.caloriesIn = maps[5][day]
            s.proteinG = maps[6][day]
            s.carbsG = maps[7][day]
            s.fatG = maps[8][day]
            s.steps = maps[9][day]
            s.activeEnergyKcal = maps[10][day]
            s.sleepHours = maps[11][day]
            return s
        }
    }

    private enum Aggregate { case cumulativeSum, discreteAverage }

    private func dailyValues(_ id: HKQuantityTypeIdentifier,
                             unit: HKUnit,
                             from start: Date, to end: Date,
                             aggregate: Aggregate) async throws -> [Date: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [:] }
        let options: HKStatisticsOptions = aggregate == .cumulativeSum ? .cumulativeSum : .discreteAverage
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let anchor = Calendar.current.startOfDay(for: start)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: type,
                                                    quantitySamplePredicate: predicate,
                                                    options: options,
                                                    anchorDate: anchor,
                                                    intervalComponents: DateComponents(day: 1))
            query.initialResultsHandler = { _, results, error in
                if let error { continuation.resume(throwing: error); return }
                var out: [Date: Double] = [:]
                results?.enumerateStatistics(from: start, to: end) { stat, _ in
                    let q = options == .cumulativeSum ? stat.sumQuantity() : stat.averageQuantity()
                    if let q { out[Calendar.current.startOfDay(for: stat.startDate)] = q.doubleValue(for: unit) }
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }
    }

    /// Sum of asleep intervals, attributed to the day the sleep *ended* (a night's sleep).
    private func sleepHoursByDay(from start: Date, to end: Date) async throws -> [Date: Double] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                var out: [Date: Double] = [:]
                for case let sample as HKCategorySample in (samples ?? []) {
                    let asleepValues: Set<Int> = [
                        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    ]
                    guard asleepValues.contains(sample.value) else { continue }
                    let day = Calendar.current.startOfDay(for: sample.endDate)
                    out[day, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }
    }
}

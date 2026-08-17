import Foundation
import HealthKit

/// Read-only HealthKit access used to auto-verify movement and wildcard quests.
final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.flightsClimbed),
            HKQuantityType(.appleExerciseTime),
            HKCategoryType(.mindfulSession),
            HKObjectType.workoutType(),
        ]
    }

    /// Ask for read access. Returns true if the request flow completed
    /// (HealthKit never reveals what the user actually granted).
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    /// Today's total for a quest metric, in the quest's own units.
    func todayValue(for metric: QuestMetric) async -> Double? {
        guard isAvailable else { return nil }
        switch metric {
        case .steps:
            return await todaySum(HKQuantityType(.stepCount), unit: .count())
        case .activeCalories:
            return await todaySum(HKQuantityType(.activeEnergyBurned), unit: .kilocalorie())
        case .stairs:
            return await todaySum(HKQuantityType(.flightsClimbed), unit: .count())
        case .walkMinutes:
            return await todaySum(HKQuantityType(.appleExerciseTime), unit: .minute())
        case .mindfulMinutes:
            return await todayMindfulMinutes()
        case .strengthSet, .stretchMinutes:
            return nil
        }
    }

    private func todaySum(_ type: HKQuantityType, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let start = Date.now.startOfDay
            let predicate = HKQuery.predicateForSamples(withStart: start, end: .now,
                                                        options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func todayMindfulMinutes() async -> Double? {
        await withCheckedContinuation { continuation in
            let start = Date.now.startOfDay
            let predicate = HKQuery.predicateForSamples(withStart: start, end: .now,
                                                        options: .strictStartDate)
            let query = HKSampleQuery(sampleType: HKCategoryType(.mindfulSession),
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: nil) { _, samples, _ in
                guard let samples else {
                    continuation.resume(returning: nil)
                    return
                }
                let seconds = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: seconds / 60.0)
            }
            store.execute(query)
        }
    }
}

import HealthKit
import Foundation

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    @Published var isAvailable = false
    @Published var isAuthorized = false

    private let healthStore = HKHealthStore()

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]

    private init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
        await MainActor.run { isAuthorized = true }
    }

    func saveSleepSession(_ session: SleepSession) async throws {
        guard isAuthorized, let endDate = session.endDate else { return }

        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: session.startDate,
            end: endDate,
            metadata: [
                "SnoringPercentage": session.snoringPercentage,
                "QualityScore": session.qualityScore,
                "SnoringEventCount": session.snoringEvents.count
            ]
        )
        try await healthStore.save(sample)
    }

    func fetchRecentSleepSamples(days: Int = 7) async throws -> [HKCategorySample] {
        guard isAuthorized else { return [] }
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(Double(-days) * 86400),
            end: Date()
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 100,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
            }
            healthStore.execute(query)
        }
    }
}

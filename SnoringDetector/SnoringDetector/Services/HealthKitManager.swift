import HealthKit
import Foundation

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    @Published var isAvailable = false
    @Published var isAuthorized = false
    @Published var currentHeartRate: Double? = nil   // live value during session
    @Published var currentOxygen: Double? = nil
    @Published var todayStepCount: Int = 0
    @Published var latestWeight: Double? = nil

    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?

    // Types the app writes
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]

    // Types the app reads (sleep + Watch vitals)
    private var readTypes: Set<HKObjectType> {
        var t: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        let quantityIDs: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .oxygenSaturation,
            .respiratoryRate,
            .heartRateVariabilitySDNN,
            .stepCount,
            .bodyMass
        ]
        for qid in quantityIDs {
            if let qt = HKObjectType.quantityType(forIdentifier: qid) { t.insert(qt) }
        }
        return t
    }

    private init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
        await MainActor.run { isAuthorized = true }
    }

    // MARK: - Sleep session write

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
                "SnoringEventCount": session.snoringEvents.count,
                "SleepTalkingCount": session.sleepTalkingEvents.count,
                "TossCount": session.tossEvents.count
            ]
        )
        try await healthStore.save(sample)
    }

    // MARK: - Vitals fetch (post-session from Watch data stored in HealthKit)

    func fetchVitals(start: Date, end: Date) async -> [VitalSample] {
        guard isAuthorized else { return [] }
        var result: [VitalSample] = []

        let pairs: [(HKQuantityTypeIdentifier, VitalSample.VitalType, HKUnit)] = [
            (.heartRate,               .heartRate,         HKUnit.count().unitDivided(by: .minute())),
            (.oxygenSaturation,        .oxygenSaturation,  HKUnit.percent()),
            (.respiratoryRate,         .respiratoryRate,   HKUnit.count().unitDivided(by: .minute())),
            (.heartRateVariabilitySDNN, .heartRateVariability, HKUnit.secondUnit(with: .milli))
        ]

        for (identifier, vitalType, unit) in pairs {
            guard let qType = HKObjectType.quantityType(forIdentifier: identifier) else { continue }
            let samples = (try? await querySamples(type: qType, start: start, end: end)) ?? []
            let vitals = samples.compactMap { s -> VitalSample? in
                guard let q = s as? HKQuantitySample else { return nil }
                return VitalSample(
                    date: q.startDate,
                    value: q.quantity.doubleValue(for: unit),
                    type: vitalType
                )
            }
            result.append(contentsOf: vitals)
        }
        return result
    }

    // MARK: - Live heart rate during session

    func startLiveHeartRateMonitoring() {
        guard isAuthorized,
              let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: HKQuery.predicateForSamples(withStart: Date(), end: nil),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.updateLiveVitals(from: samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.updateLiveVitals(from: samples)
        }
        healthStore.execute(query)
        heartRateQuery = query
    }

    func stopLiveHeartRateMonitoring() {
        if let q = heartRateQuery { healthStore.stop(q) }
        heartRateQuery = nil
        Task { @MainActor in
            currentHeartRate = nil
            currentOxygen = nil
        }
    }

    private func updateLiveVitals(from samples: [HKSample]?) {
        guard let latest = (samples as? [HKQuantitySample])?.last else { return }
        let bpm = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        Task { @MainActor in self.currentHeartRate = bpm }
    }

    // MARK: - Sleep analysis history

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
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: (samples as? [HKCategorySample]) ?? []) }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Steps & Weight

    func fetchStepsAndWeight(for date: Date = Date()) async {
        guard isAuthorized else { return }
        let start = Calendar.current.startOfDay(for: date)
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? date

        // Steps
        if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let steps = (try? await withCheckedThrowingContinuation { cont in
                let q = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                    cont.resume(returning: Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0))
                }
                healthStore.execute(q)
            }) ?? 0
            await MainActor.run { self.todayStepCount = steps }
        }

        // Weight (most recent)
        if let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            let samples = (try? await querySamples(type: weightType, start: start.addingTimeInterval(-90*86400), end: end)) ?? []
            if let latest = (samples as? [HKQuantitySample])?.first {
                let kg = latest.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                await MainActor.run { self.latestWeight = kg }
            }
        }
    }

    // MARK: - Private

    private func querySamples(type: HKSampleType, start: Date, end: Date) async throws -> [HKSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 500,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples ?? []) }
            }
            healthStore.execute(query)
        }
    }
}

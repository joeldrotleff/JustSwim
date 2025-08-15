import HealthKit
import WatchKit

class HealthKitManager: NSObject, HealthKitProtocol {
    @Published var isAuthorized = false
    @Published var activeWorkout: HKWorkout?
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var totalDistance: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var manualSets: [ManualSet] = []
    @Published var autoLapCount: Int = 0

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var workoutTimer: Timer?
    private var workoutStartTime: Date?

    // Types we need to read and write
    private var typesToShare: Set<HKSampleType> {
        [
            HKWorkoutType.workoutType(),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.swimmingStrokeCount),
        ]
    }

    private var typesToRead: Set<HKObjectType> {
        [
            HKWorkoutType.workoutType(),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.swimmingStrokeCount),
        ]
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)

        isAuthorized = true
    }

    func startWorkout(
        activityType: HKWorkoutActivityType,
        locationType: HKWorkoutSwimmingLocationType,
        poolLength: HKQuantity?
    ) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.swimmingLocationType = locationType
        configuration.lapLength = poolLength

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()

        session.delegate = self
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

        self.session = session
        self.builder = builder

        let startDate = Date()

        // Begin collection with completion handler
        await withCheckedContinuation { continuation in
            builder.beginCollection(withStart: startDate) { _, _ in
                continuation.resume()
            }
        }

        session.startActivity(with: startDate)

        // Track workout start time
        workoutStartTime = startDate

        // Start timer to update elapsed time
        await MainActor.run {
            self.startElapsedTimeTimer()
            // Enable water lock for swimming using the new API
            WKInterfaceDevice.current().enableWaterLock()
        }
    }

    func markSetTransition(isSwimming: Bool) {
        let set = ManualSet(timestamp: Date(), isSwimming: isSwimming)
        manualSets.append(set)

        // Haptic feedback
        WKInterfaceDevice.current().play(.click)
    }

    func pauseWorkout() {
        session?.pause()
    }

    func resumeWorkout() {
        session?.resume()
    }

    func endWorkout() async throws {
        // Add manual sets to workout metadata
        if !manualSets.isEmpty {
            let setsData = try JSONEncoder().encode(manualSets)
            do {
                try await builder?.addMetadata([
                    "manual_sets": setsData,
                ])
            } catch {
                print("Error adding metadata: \(error.localizedDescription)")
            }
        }

        session?.end()

        let endDate = Date()

        // End collection with completion handler
        await withCheckedContinuation { continuation in
            builder?.endCollection(withEnd: endDate) { _, _ in
                continuation.resume()
            }
        }

        activeWorkout = try await builder?.finishWorkout()

        // Clean up
        stopElapsedTimeTimer()
        session = nil
        builder = nil
        manualSets.removeAll()
        elapsedTime = 0
        workoutStartTime = nil
        autoLapCount = 0
    }

    func discardWorkout() {
        session?.end()
        builder?.discardWorkout()

        // Clean up
        stopElapsedTimeTimer()
        session = nil
        builder = nil
        manualSets.removeAll()
        activeWorkout = nil
        elapsedTime = 0
        workoutStartTime = nil
        autoLapCount = 0
    }

    // MARK: - Timer Management

    private func startElapsedTimeTimer() {
        stopElapsedTimeTimer() // Ensure no duplicate timers
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.workoutStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(startTime)
        }
    }

    private func stopElapsedTimeTimer() {
        workoutTimer?.invalidate()
        workoutTimer = nil
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from _: HKWorkoutSessionState,
        date _: Date
    ) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                print("Workout session running")
            case .paused:
                print("Workout session paused")
            case .ended:
                print("Workout session ended")
            default:
                break
            }
        }
    }

    func workoutSession(_: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }

    func workoutSession(_: HKWorkoutSession, didGenerate event: HKWorkoutEvent) {
        // Handle automatic lap detection if available
        if event.type == .lap {
            DispatchQueue.main.async {
                // Auto-detected lap - increment counter
                self.autoLapCount += 1
                print("Automatic lap detected: \(self.autoLapCount)")
            }
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HealthKitManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            let statistics = workoutBuilder.statistics(for: quantityType)

            DispatchQueue.main.async {
                switch quantityType {
                case HKQuantityType(.heartRate):
                    if let heartRate = statistics?.mostRecentQuantity()?
                        .doubleValue(for: .count().unitDivided(by: .minute()))
                    {
                        self.heartRate = heartRate
                    }

                case HKQuantityType(.activeEnergyBurned):
                    if let calories = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        self.activeCalories = calories
                    }

                case HKQuantityType(.distanceSwimming):
                    if let distance = statistics?.sumQuantity()?.doubleValue(for: .meter()) {
                        self.totalDistance = distance
                    }

                default:
                    break
                }
            }
        }
    }

    func workoutBuilderDidCollectEvent(_: HKLiveWorkoutBuilder) {
        // Handle workout events
    }
}

// MARK: - Error Types

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        }
    }
}

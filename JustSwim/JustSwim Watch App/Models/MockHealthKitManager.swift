import Combine
import Foundation
import HealthKit

// Mock implementation for simulator testing
@MainActor
class MockHealthKitManager: @preconcurrency HealthKitProtocol {
    @Published var isAuthorized: Bool = true
    @Published var activeWorkout: HKWorkout?
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var totalDistance: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var manualSets: [ManualSet] = []
    @Published var autoLapCount: Int = 0

    private var cancellables = Set<AnyCancellable>()
    private var workoutStartTime: Date?
    private var isPaused = false
    private var pausedTime: TimeInterval = 0
    private var pauseStartTime: Date?

    // Swim-specific parameters
    private var poolLength: Double = 25 // meters
    private var currentLapCount = 0
    private var isSwimming = false
    private var lastLapTime: Date?
    private var baseHeartRate: Double = 120
    private var currentSet = 1
    private var lapsInCurrentSet = 0

    init() {
        // Simulator always authorized
        isAuthorized = true
    }

    func requestAuthorization() async throws {
        // Always authorized in simulator
        isAuthorized = true
    }

    func startWorkout(
        activityType _: HKWorkoutActivityType,
        locationType _: HKWorkoutSwimmingLocationType,
        poolLength: HKQuantity?
    ) async throws {
        // Store pool length if provided
        if let poolLength = poolLength {
            self.poolLength = poolLength.doubleValue(for: .meter())
        }

        workoutStartTime = Date()
        currentLapCount = 0
        activeCalories = 0
        totalDistance = 0
        manualSets = []
        currentSet = 1
        lapsInCurrentSet = 0
        autoLapCount = 0

        // For mock implementation, we don't create actual HKWorkout objects
        // This avoids the deprecated initializer warning
        // activeWorkout remains nil during mock sessions

        // Start timers
        startTimers()
    }

    func pauseWorkout() {
        isPaused = true
        pauseStartTime = Date()
        stopTimers()
    }

    func resumeWorkout() {
        if let pauseStart = pauseStartTime {
            pausedTime += Date().timeIntervalSince(pauseStart)
        }
        isPaused = false
        pauseStartTime = nil
        startTimers()
    }

    func endWorkout() async throws {
        stopTimers()

        if workoutStartTime != nil {
            // For mock implementation, we just simulate workout completion
            // In real implementation, HKWorkoutBuilder would be used
            print("Mock workout ended:")
            print("- Duration: \(elapsedTime)s")
            print("- Calories: \(activeCalories)")
            print("- Distance: \(totalDistance)m")
            print("- Manual sets: \(manualSets.count)")
            print("- Auto laps: \(autoLapCount)")

            // Clear the active workout since we're just mocking
            activeWorkout = nil
        }
    }

    func discardWorkout() {
        stopTimers()
        resetWorkout()
    }

    func markSetTransition(isSwimming: Bool) {
        let set = ManualSet(timestamp: Date(), isSwimming: isSwimming)
        manualSets.append(set)

        if isSwimming {
            currentLapCount += 1
            lapsInCurrentSet += 1
            totalDistance += poolLength

            // Auto-set detection: new set every 4 laps
            if lapsInCurrentSet >= 4 {
                currentSet += 1
                lapsInCurrentSet = 0
                // Brief rest between sets affects heart rate
                baseHeartRate = max(110, baseHeartRate - 5)
            }
        } else {
            // Rest period - heart rate decreases
            baseHeartRate = max(100, baseHeartRate - 10)
        }

        self.isSwimming = isSwimming
        lastLapTime = Date()
    }

    // MARK: - Private Methods

    private func startTimers() {
        // Update elapsed time every second
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateElapsedTime()
            }
            .store(in: &cancellables)

        // Update heart rate every 2 seconds
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateHeartRate()
            }
            .store(in: &cancellables)

        // Auto-lap detection every 10 seconds
        Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.simulateAutoLap()
            }
            .store(in: &cancellables)
    }

    private func updateElapsedTime() {
        guard let startTime = workoutStartTime, !isPaused else { return }
        elapsedTime = Date().timeIntervalSince(startTime) - pausedTime

        // Update calories (approximately 10 cal/min for swimming)
        let minutes = elapsedTime / 60
        activeCalories = minutes * 10 * (isSwimming ? 1.2 : 0.3)
    }

    private func updateHeartRate() {
        guard !isPaused else { return }

        // Simulate realistic heart rate variations
        if isSwimming {
            // Swimming: higher heart rate with variations
            baseHeartRate = min(165, baseHeartRate + 2)
            let variation = Double.random(in: -5 ... 5)
            heartRate = baseHeartRate + variation
        } else {
            // Resting: lower heart rate
            let variation = Double.random(in: -3 ... 3)
            heartRate = baseHeartRate + variation
        }

        // Ensure heart rate stays in reasonable bounds
        heartRate = max(90, min(180, heartRate))
    }

    private func simulateAutoLap() {
        // Simply increment the auto lap count
        // No automatic rest periods - user controls swimming/resting state
        autoLapCount += 1
        print("Auto lap detected: \(autoLapCount)")
    }

    private func stopTimers() {
        cancellables.removeAll()
    }

    private func resetWorkout() {
        activeWorkout = nil
        heartRate = 0
        activeCalories = 0
        totalDistance = 0
        elapsedTime = 0
        manualSets = []
        workoutStartTime = nil
        isPaused = false
        pausedTime = 0
        pauseStartTime = nil
        currentLapCount = 0
        isSwimming = false
        lastLapTime = nil
        baseHeartRate = 120
        currentSet = 1
        lapsInCurrentSet = 0
        autoLapCount = 0
    }
}

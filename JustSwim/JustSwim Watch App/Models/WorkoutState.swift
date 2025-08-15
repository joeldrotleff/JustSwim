//
//  WorkoutState.swift
//  TimeLaps Watch App
//
//  Created by Joel Drotleff on 7/18/25.
//

import Combine
import CoreMotion
import Foundation
import HealthKit

enum WorkoutPhase: Equatable {
    case preWorkout
    case poolSelection
    case countdown(Int)
    case active
    case paused
    case completed
}

enum SwimState: Equatable {
    case swimming // In a set
    case resting // Between sets
    case countdown(Int) // Counting down before swimming
}

@MainActor class WorkoutState: ObservableObject {
    @Published var phase: WorkoutPhase = .preWorkout
    @Published var swimState: SwimState = .resting
    @Published var workoutStartTime: Date?
    @Published var elapsedTime: TimeInterval = 0
    @Published var setCount: Int = 0
    @Published var currentSetStartTime: Date?
    @Published var lastSetTime: TimeInterval?
    @Published var lastSetLapCount: Int = 0 // Laps in the last completed set
    @Published var currentSetLapCount: Int = 0 // Laps in current set
    @Published var autoLapCount: Int = 0 // Total automatic lap detection from HealthKit
    private var lapCountAtSetStart: Int = 0 // Track laps at start of set
    @Published var poolLengthYards: Double = 25.0 // Default to 25 yards
    @Published var poolUnit: String = "y" // "y" for yards, "m" for meters
    @Published var poolDisplayValue: Double = 25.0 // Display value (25, 50, etc.)
    private var hasStartedFirstSet = false // Track if workout timer has started

    // Wall tap detection
    let wallTapDetector = WallTapDetector()
    @Published var lastSetAdjustedEndTime: Date? // Adjusted end time if wall tap detected

    // HealthKit integration
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0

    // Use mock for simulator, real HealthKit for device
    #if targetEnvironment(simulator)
        private let healthKitManager = MockHealthKitManager()
    #else
        private let healthKitManager = HealthKitManager()
    #endif

    private var cancellables = Set<AnyCancellable>()
    private var buttonCountdownCancellable: AnyCancellable?
    private var elapsedTimeCancellable: AnyCancellable?

    init() {
        // Set up Combine subscriptions for HealthKit updates
        setupHealthKitSubscriptions()
    }

    private func setupHealthKitSubscriptions() {
        // Subscribe to HealthKit updates using Combine
        healthKitManager.$heartRate
            .sink { [weak self] rate in
                self?.heartRate = rate
            }
            .store(in: &cancellables)

        healthKitManager.$activeCalories
            .sink { [weak self] calories in
                self?.activeCalories = calories
            }
            .store(in: &cancellables)

        healthKitManager.$manualSets
            .sink { [weak self] sets in
                self?.setCount = sets.filter { $0.isSwimming }.count
            }
            .store(in: &cancellables)

        healthKitManager.$autoLapCount
            .sink { [weak self] count in
                guard let self = self else { return }
                self.autoLapCount = count
                // Update current set lap count
                if self.swimState == .swimming {
                    self.currentSetLapCount = count - self.lapCountAtSetStart
                }
            }
            .store(in: &cancellables)
    }

    func startWorkout() {
        phase = .poolSelection
    }

    func requestHealthKitAuthorization() async throws {
        try await healthKitManager.requestAuthorization()
    }

    func selectPoolSize(_ lengthInYards: Double, unit: String, displayValue: Double) {
        poolLengthYards = lengthInYards
        poolUnit = unit
        poolDisplayValue = displayValue
        beginWorkout()
    }

    private func beginWorkout() {
        phase = .active
        // Don't set workoutStartTime or start timer yet - wait for first set

        // Start wall tap detection
        wallTapDetector.startMonitoring()

        // Start HealthKit workout session
        Task {
            do {
                let unit: HKUnit = poolUnit == "m" ? .meter() : .yard()
                let poolLength = HKQuantity(unit: unit, doubleValue: poolDisplayValue)
                try await healthKitManager.startWorkout(
                    activityType: .swimming,
                    locationType: .pool,
                    poolLength: poolLength
                )
            } catch {
                print("Failed to start HealthKit workout: \(error)")
            }
        }
    }

    private func startTimer() {
        elapsedTimeCancellable?.cancel() // Cancel any existing timer

        elapsedTimeCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let startTime = self.workoutStartTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)
            }
    }

    func toggleSwimState() {
        switch swimState {
        case .resting:
            // Start countdown when going from resting to swimming
            startButtonCountdown()
        case .swimming:
            // Immediately switch to resting
            swimState = .resting
            let buttonTapTime = Date()

            // Look for wall tap within last 5 seconds
            if let wallTap = wallTapDetector.findWallTapBefore(date: buttonTapTime, within: 5.0) {
                // Use wall tap time as the actual end time
                lastSetAdjustedEndTime = wallTap.timestamp
                if let setStart = currentSetStartTime {
                    lastSetTime = wallTap.timestamp.timeIntervalSince(setStart)
                    lastSetLapCount = currentSetLapCount
                }
                print("Set end adjusted to wall tap at \(wallTap.timestamp)")
            } else {
                // No wall tap found, use button tap time
                lastSetAdjustedEndTime = nil
                if let setStart = currentSetStartTime {
                    lastSetTime = buttonTapTime.timeIntervalSince(setStart)
                    lastSetLapCount = currentSetLapCount
                }
            }

            currentSetStartTime = nil
            healthKitManager.markSetTransition(isSwimming: false)
        case .countdown:
            // Cancel countdown if button is pressed during countdown
            buttonCountdownCancellable?.cancel()
            swimState = .resting
        }
    }

    private func startButtonCountdown() {
        buttonCountdownCancellable?.cancel() // Cancel any existing countdown
        swimState = .countdown(3)

        buttonCountdownCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .scan(3) { count, _ in count - 1 }
            .sink { [weak self] count in
                guard let self = self else { return }
                if count >= 0 {
                    self.swimState = .countdown(count)
                }
                if count < 0 {
                    self.buttonCountdownCancellable?.cancel()
                    self.beginSwimming()
                }
            }
    }

    private func beginSwimming() {
        swimState = .swimming

        // If this is the first set, start the workout timer
        if !hasStartedFirstSet {
            hasStartedFirstSet = true
            workoutStartTime = Date()
            startTimer()
        }

        currentSetStartTime = Date()
        lapCountAtSetStart = autoLapCount
        currentSetLapCount = 0
        healthKitManager.markSetTransition(isSwimming: true)
    }

    func pauseWorkout() {
        phase = .paused
        elapsedTimeCancellable?.cancel()
        healthKitManager.pauseWorkout()
    }

    func resumeWorkout() {
        phase = .active
        startTimer()
        healthKitManager.resumeWorkout()
    }

    func endWorkout() {
        phase = .completed
        elapsedTimeCancellable?.cancel()
        wallTapDetector.stopMonitoring()

        Task {
            do {
                try await healthKitManager.endWorkout()
                print("Workout saved successfully")
            } catch {
                print("Failed to save workout: \(error)")
            }
        }
    }

    func resetWorkout() {
        phase = .preWorkout
        swimState = .resting
        workoutStartTime = nil
        elapsedTime = 0
        setCount = 0
        currentSetStartTime = nil
        lastSetTime = nil
        lastSetAdjustedEndTime = nil
        lastSetLapCount = 0
        currentSetLapCount = 0
        autoLapCount = 0
        lapCountAtSetStart = 0
        hasStartedFirstSet = false
        elapsedTimeCancellable?.cancel()
        buttonCountdownCancellable?.cancel()
    }

    var poolSizeString: String {
        return "\(Int(poolDisplayValue))\(poolUnit)"
    }
}

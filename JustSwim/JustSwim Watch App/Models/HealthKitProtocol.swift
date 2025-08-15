import Foundation
import HealthKit

// Protocol defining the interface for health data operations
protocol HealthKitProtocol: ObservableObject {
    // Published properties for UI binding
    var isAuthorized: Bool { get }
    var activeWorkout: HKWorkout? { get }
    var heartRate: Double { get }
    var activeCalories: Double { get }
    var totalDistance: Double { get }
    var elapsedTime: TimeInterval { get }
    var manualSets: [ManualSet] { get }
    var autoLapCount: Int { get } // Automatic lap detection from HealthKit

    // Authorization
    func requestAuthorization() async throws

    // Workout control
    func startWorkout(
        activityType: HKWorkoutActivityType,
        locationType: HKWorkoutSwimmingLocationType,
        poolLength: HKQuantity?
    ) async throws
    func pauseWorkout()
    func resumeWorkout()
    func endWorkout() async throws
    func discardWorkout()

    // Set tracking
    func markSetTransition(isSwimming: Bool)
}

// Struct to represent manual set transition data
struct ManualSet: Codable {
    let timestamp: Date
    let isSwimming: Bool
}

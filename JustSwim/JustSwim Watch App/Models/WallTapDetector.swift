//
//  WallTapDetector.swift
//  TimeLaps Watch App
//
//  Created by Joel Drotleff on 7/22/25.
//

import Combine
import CoreMotion
import Foundation

struct WallTap {
    let timestamp: Date
    let magnitude: Double
}

struct AccelerationSample {
    let timestamp: Date
    let x: Double
    let y: Double
    let z: Double
    let magnitude: Double
}

@MainActor
class WallTapDetector: ObservableObject {
    @Published private(set) var recentWallTaps: [WallTap] = []
    @Published var showTapIndicator: Bool = false

    private let motionManager = CMMotionManager()

    // Detection thresholds
    private let tapThreshold: Double = 1.3 // G-force threshold for initial detection (lowered)
    private let jerkThreshold: Double = 8.0 // G/s threshold for rate of change (lowered)
    private let restThreshold: Double = 1.15 // G-force threshold for "at rest" (accounting for ~1g gravity)
    private let restDuration: TimeInterval = 0.1 // Required rest time before next detection (shortened)
    private let cooldownPeriod: TimeInterval = 0.3 // Minimum time between detections (shortened)

    // History tracking
    private var accelerationHistory: [AccelerationSample] = []
    private let historySize = 10 // Keep last 10 samples for analysis
    private var lastTapTime: Date = .distantPast
    private var isInRestPeriod: Bool = true // Start as true to allow initial detection
    private var restStartTime: Date?

    private let tapRetentionDuration: TimeInterval = 10.0 // Keep taps for 10 seconds
    private var cleanupTimer: Timer?
    private var tapIndicatorTimer: Timer?

    init() {
        setupAccelerometer()
        startCleanupTimer()
    }

    deinit {
        motionManager.stopAccelerometerUpdates()
        cleanupTimer?.invalidate()
        tapIndicatorTimer?.invalidate()
    }

    private func setupAccelerometer() {
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer not available")
            return
        }

        motionManager.accelerometerUpdateInterval = 0.05 // 20 Hz sampling rate
    }

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self,
                  let data = data,
                  error == nil else { return }

            let now = Date()
            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            let magnitude = sqrt(x * x + y * y + z * z)

            // Create new sample
            let sample = AccelerationSample(
                timestamp: now,
                x: x,
                y: y,
                z: z,
                magnitude: magnitude
            )

            // Add to history and maintain size limit
            self.accelerationHistory.append(sample)
            if self.accelerationHistory.count > self.historySize {
                self.accelerationHistory.removeFirst()
            }

            // Check for rest period
            self.updateRestPeriod(magnitude: magnitude, timestamp: now)

            // Debug logging for high accelerations
            // if magnitude > 1.0 {
            //     print("Accel: \(String(format: "%.2f", magnitude))g, Rest: \(self.isInRestPeriod), Cooldown: \(now.timeIntervalSince(self.lastTapTime) >= self.cooldownPeriod)")
            // }

            // Only attempt detection if we have enough history and rest period is satisfied
            guard self.accelerationHistory.count >= 3,
                  self.isInRestPeriod,
                  now.timeIntervalSince(self.lastTapTime) >= self.cooldownPeriod
            else {
                // if magnitude > self.tapThreshold {
                //     print("Blocked: history=\(self.accelerationHistory.count), rest=\(self.isInRestPeriod), cooldown=\(now.timeIntervalSince(self.lastTapTime))")
                // }
                return
            }

            // Calculate jerk (rate of change of acceleration)
            if let jerk = self.calculateJerk() {
                // Debug high jerk values
                // if jerk > 5.0 {
                //     print("Jerk: \(String(format: "%.2f", jerk))g/s, Magnitude: \(String(format: "%.2f", magnitude))g")
                // }

                // Check for wall tap pattern: high acceleration + high jerk
                if magnitude > self.tapThreshold, jerk > self.jerkThreshold {
                    // Additional pattern check: look for impact signature
                    if self.hasImpactPattern() {
                        let wallTap = WallTap(timestamp: now, magnitude: magnitude)
                        self.recentWallTaps.append(wallTap)
                        self.lastTapTime = now
                        self.isInRestPeriod = false
                        self.restStartTime = nil

                        // print("✅ Wall tap detected: magnitude \(String(format: "%.2f", magnitude))g, jerk \(String(format: "%.2f", jerk))g/s")

                        // Show tap indicator
                        self.showTapIndicator = true
                        self.startTapIndicatorTimer()
                    } // else {
                    //     print("Pattern check failed despite magnitude \(String(format: "%.2f", magnitude))g and jerk \(String(format: "%.2f", jerk))g/s")
                    // }
                }
            }
        }
    }

    private func updateRestPeriod(magnitude: Double, timestamp: Date) {
        if magnitude < restThreshold {
            // Low acceleration detected
            if restStartTime == nil {
                restStartTime = timestamp
                // print("Rest period started at magnitude \(String(format: "%.2f", magnitude))g")
            } else if let start = restStartTime,
                      timestamp.timeIntervalSince(start) >= restDuration
            {
                // Been at rest long enough
                if !isInRestPeriod {
                    // print("Rest period satisfied after \(String(format: "%.3f", timestamp.timeIntervalSince(start)))s")
                    isInRestPeriod = true
                }
            }
        } else {
            // High acceleration - only reset if we're not already in rest period
            // This prevents resetting during the actual tap
            if restStartTime != nil, !isInRestPeriod {
                // print("Rest period interrupted at magnitude \(String(format: "%.2f", magnitude))g")
                restStartTime = nil
            }
        }
    }

    private func calculateJerk() -> Double? {
        guard accelerationHistory.count >= 2 else { return nil }

        let current = accelerationHistory[accelerationHistory.count - 1]
        let previous = accelerationHistory[accelerationHistory.count - 2]

        let timeDelta = current.timestamp.timeIntervalSince(previous.timestamp)
        guard timeDelta > 0 else { return nil }

        let magnitudeDelta = current.magnitude - previous.magnitude
        return abs(magnitudeDelta / timeDelta)
    }

    private func hasImpactPattern() -> Bool {
        guard accelerationHistory.count >= 4 else { return false }

        let recent = Array(accelerationHistory.suffix(4))

        // Look for pattern: acceleration building up then sudden spike
        // Check if most recent sample is significantly higher than previous ones
        let currentMagnitude = recent.last?.magnitude ?? 0
        let previousAverage = recent.dropLast().map { $0.magnitude }.reduce(0, +) / 3

        // Current should be at least 30% higher than recent average (lowered from 50%)
        let passes = currentMagnitude > previousAverage * 1.3
        // if !passes {
        //     print("Impact pattern check: current=\(String(format: "%.2f", currentMagnitude))g, avg=\(String(format: "%.2f", previousAverage))g, ratio=\(String(format: "%.2f", currentMagnitude / previousAverage))")
        // }
        return passes
    }

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        cleanupTimer?.invalidate()
        tapIndicatorTimer?.invalidate()
    }

    private func startTapIndicatorTimer() {
        tapIndicatorTimer?.invalidate()
        tapIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.showTapIndicator = false
            }
        }
    }

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupOldTaps()
            }
        }
    }

    private func cleanupOldTaps() {
        let cutoffTime = Date().addingTimeInterval(-tapRetentionDuration)
        recentWallTaps.removeAll { $0.timestamp < cutoffTime }
    }

    func findWallTapBefore(date: Date, within timeWindow: TimeInterval = 5.0) -> WallTap? {
        let earliestAcceptableTime = date.addingTimeInterval(-timeWindow)

        // Find the most recent wall tap within the time window
        return recentWallTaps
            .filter { tap in
                tap.timestamp >= earliestAcceptableTime && tap.timestamp <= date
            }
            .max(by: { $0.timestamp < $1.timestamp })
    }
}

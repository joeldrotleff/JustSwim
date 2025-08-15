//
//  LastLapView.swift
//  TimeLaps Watch App
//
//  Created by Joel Drotleff on 7/19/25.
//

import SwiftUI

struct LastLapView: View {
    @EnvironmentObject var workoutState: WorkoutState

    var body: some View {
        VStack(spacing: 16) {
            Text("Last Set")
                .font(.title3)
                .foregroundColor(.gray)
                .padding(.top)

            if let lastSetTime = workoutState.lastSetTime {
                // Total time
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        if workoutState.lastSetAdjustedEndTime != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    Text(timeString(from: lastSetTime))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }

                // Lap count
                HStack(spacing: 30) {
                    VStack(spacing: 4) {
                        Text("Laps")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(workoutState.lastSetLapCount)")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    // Pace per 100y
                    VStack(spacing: 4) {
                        Text("Pace/100y")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(paceString(time: lastSetTime, laps: workoutState.lastSetLapCount))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 8)
            } else {
                Text("--:--")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.gray)
                    .padding(.top, 20)
            }

            Spacer()
        }
    }

    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let hundredths = Int((interval.truncatingRemainder(dividingBy: 1)) * 100)

        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
        } else {
            return String(format: "%d.%02d", seconds, hundredths)
        }
    }

    private func paceString(time: TimeInterval, laps: Int) -> String {
        guard laps > 0 else { return "--:--" }

        // Calculate yards swum based on pool size
        let yardsPerLap = workoutState.poolUnit == "m" ? workoutState.poolDisplayValue * 1.09361 : workoutState
            .poolDisplayValue
        let totalYards = Double(laps) * yardsPerLap

        // Calculate time per 100 yards
        let timePer100y = (time / totalYards) * 100

        let minutes = Int(timePer100y) / 60
        let seconds = Int(timePer100y) % 60

        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    LastLapView()
        .environmentObject(WorkoutState())
}

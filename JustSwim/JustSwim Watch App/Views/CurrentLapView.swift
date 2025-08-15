//
//  CurrentLapView.swift
//  TimeLaps Watch App
//
//  Created by Joel Drotleff on 7/18/25.
//

import SwiftUI
import WatchKit

struct CurrentLapView: View {
    @EnvironmentObject var workoutState: WorkoutState

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Spacer()

                // Set timer and lap count
                HStack {
                    // Set timer (shown when swimming) - left aligned
                    if case .swimming = workoutState.swimState, let setStart = workoutState.currentSetStartTime {
                        TimelineView(.periodic(from: setStart, by: 0.05)) { timeline in
                            Text(timeString(from: timeline.date.timeIntervalSince(setStart)))
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(" ")
                            .font(.footnote)
                    }

                    Spacer()

                    // Lap count in current set - right aligned
                    if case .swimming = workoutState.swimState {
                        Text("Lap \(workoutState.currentSetLapCount)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        Text(" ")
                            .font(.footnote)
                    }
                }
                .padding(.horizontal)

                // Swimming state button
                Button(action: {
                    workoutState.toggleSwimState()
                    WKInterfaceDevice.current().play(.click)
                }) {
                    Text(workoutState.swimState == .swimming ? "SWIMMING" : "RESTING")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(workoutState.swimState == .swimming ? Color.blue : Color(white: 0.2))
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .handGestureShortcut(.primaryAction)

                // Overall workout timer
                ZStack {
                    // Hidden text to maintain consistent width
                    Text("00:00.00")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .opacity(0)

                    Text(timeString(from: workoutState.elapsedTime))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }

                // Set count
                Text("Set \(workoutState.setCount)")
                    .font(.headline)
                    .foregroundColor(.gray)

                Spacer()
            }

            // Fullscreen countdown overlay
            if case let .countdown(count) = workoutState.swimState {
                CountdownOverlay(count: count)
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Wall tap indicator overlay
            if workoutState.wallTapDetector.showTapIndicator {
                WallTapOverlay()
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
            }
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
}

struct CountdownOverlay: View {
    var count: Int

    var displayText: String {
        count > 0 ? "\(count)" : "GO!"
    }

    var body: some View {
        Text(displayText)
            .font(.system(size: 100, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
    }
}

struct WallTapOverlay: View {
    var body: some View {
        Text("TAP!")
            .font(.system(size: 80, weight: .bold, design: .rounded))
            .foregroundColor(.green)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.8))
    }
}

#Preview {
    CurrentLapView()
        .environmentObject(WorkoutState())
}

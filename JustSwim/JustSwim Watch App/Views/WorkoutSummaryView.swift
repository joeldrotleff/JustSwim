//
//  WorkoutSummaryView.swift
//  TimeLaps Watch App
//
//  Created by Joel Drotleff on 7/19/25.
//

import SwiftUI

struct WorkoutSummaryView: View {
    @EnvironmentObject var workoutState: WorkoutState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Workout Complete")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)

                VStack(spacing: 16) {
                    // Total time
                    HStack {
                        Label("Total Time", systemImage: "timer")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(timeString(from: workoutState.elapsedTime))
                            .font(.headline)
                            .monospacedDigit()
                    }

                    Divider()

                    // Sets
                    HStack {
                        Label("Sets", systemImage: "arrow.triangle.turn.up.right.circle")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(workoutState.setCount)")
                            .font(.headline)
                    }

                    Divider()

                    // Heart rate
                    HStack {
                        Label("Avg Heart Rate", systemImage: "heart.fill")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(workoutState.heartRate)) BPM")
                            .font(.headline)
                    }

                    Divider()

                    // Calories
                    HStack {
                        Label("Active Calories", systemImage: "flame.fill")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(workoutState.activeCalories))")
                            .font(.headline)
                    }

                    Divider()

                    // Pool size
                    HStack {
                        Label("Pool Size", systemImage: "ruler")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(workoutState.poolSizeString)
                            .font(.headline)
                    }
                }
                .padding()

                Button(action: {
                    workoutState.resetWorkout()
                }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .padding()
            }
        }
    }

    private func timeString(from interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    WorkoutSummaryView()
        .environmentObject(WorkoutState())
}

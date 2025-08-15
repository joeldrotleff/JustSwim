//
//  EndWorkoutView.swift
//  TimeLaps Watch App
//
//  Created by Joel Drotleff on 7/19/25.
//

import SwiftUI

struct EndWorkoutView: View {
    @EnvironmentObject var workoutState: WorkoutState

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Button(action: {
                if workoutState.phase == .paused {
                    workoutState.resumeWorkout()
                } else {
                    workoutState.pauseWorkout()
                }
            }) {
                VStack(spacing: 8) {
                    Image(systemName: workoutState.phase == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    Text(workoutState.phase == .paused ? "Resume" : "Pause")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                workoutState.endWorkout()
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text("End")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
    }
}

#Preview {
    EndWorkoutView()
        .environmentObject(WorkoutState())
}

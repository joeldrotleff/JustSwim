//
//  WorkoutView.swift
//  TimeLaps Watch App
//
//  Created by Joel Drotleff on 7/18/25.
//

import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var workoutState: WorkoutState
    @Binding var showWorkout: Bool

    var body: some View {
        Group {
            switch workoutState.phase {
            case .poolSelection:
                PoolSizeSelector(workoutState: workoutState)
            case .countdown:
                // Countdown is no longer used at workout start
                EmptyView()
            case .active:
                ActiveWorkoutView()
                    .navigationBarBackButtonHidden(true)
            case .paused:
                ActiveWorkoutView()
                    .navigationBarBackButtonHidden(true)
            case .completed:
                WorkoutSummaryView()
            case .preWorkout:
                EmptyView()
            }
        }
        .environmentObject(workoutState)
    }
}

#Preview {
    WorkoutView(showWorkout: .constant(true))
        .environmentObject(WorkoutState())
}

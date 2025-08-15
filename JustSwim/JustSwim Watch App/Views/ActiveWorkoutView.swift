//
//  ActiveWorkoutView.swift
//  TimeLaps Watch App
//
//  Created by Joel Drotleff on 7/18/25.
//

import SwiftUI
import WatchKit

struct ActiveWorkoutView: View {
    @EnvironmentObject var workoutState: WorkoutState
    @State private var currentPage = 1 // Start on middle page (CurrentLapView)

    var body: some View {
        TabView(selection: $currentPage) {
            LastLapView()
                .tag(0)

            CurrentLapView()
                .tag(1)

            EndWorkoutView()
                .tag(2)
        }
        .tabViewStyle(.page)
        .background(Color.black)
    }
}

#Preview {
    ActiveWorkoutView()
        .environmentObject(WorkoutState())
}

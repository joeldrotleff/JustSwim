//
//  MainView.swift
//  TimeLaps Watch App
//
//  Created by Joel Drotleff on 7/18/25.
//

import SwiftUI

struct MainView: View {
    @StateObject private var workoutState = WorkoutState()
    @State private var showWorkout = false
    @State private var showingHealthKitError = false
    @State private var healthKitErrorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "figure.pool.swim")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("TimeLaps")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: {
                    Task {
                        do {
                            try await workoutState.requestHealthKitAuthorization()
                            workoutState.startWorkout()
                            showWorkout = true
                        } catch {
                            healthKitErrorMessage = error.localizedDescription
                            showingHealthKitError = true
                        }
                    }
                }) {
                    Text("Start Workout")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .navigationDestination(isPresented: $showWorkout) {
                WorkoutView(showWorkout: $showWorkout)
                    .environmentObject(workoutState)
            }
            .alert("HealthKit Access Required", isPresented: $showingHealthKitError) {
                Button("OK") {}
            } message: {
                Text(healthKitErrorMessage)
            }
        }
        .onChange(of: workoutState.phase) {
            if workoutState.phase == .completed {
                showWorkout = false
                // Reset workout state after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    workoutState.resetWorkout()
                }
            }
        }
    }
}

#Preview {
    MainView()
}

//
//  PoolSizeSelector.swift
//  TimeLaps Watch App
//
//  Created by Assistant on 7/19/25.
//

import SwiftUI

struct PoolSize {
    let value: Double
    let unit: String
    let displayName: String

    var inYards: Double {
        switch unit {
        case "m":
            return value * 1.09361
        default:
            return value
        }
    }
}

struct PoolSizeSelector: View {
    @ObservedObject var workoutState: WorkoutState
    @State private var selectedPoolIndex = 0

    let poolSizes = [
        PoolSize(value: 25, unit: "y", displayName: "25 Yards"),
        PoolSize(value: 50, unit: "y", displayName: "50 Yards"),
        PoolSize(value: 25, unit: "m", displayName: "25 Meters"),
        PoolSize(value: 50, unit: "m", displayName: "50 Meters"),
    ]

    var body: some View {
        VStack {
            Spacer()

            Picker(selection: $selectedPoolIndex, label: EmptyView()) {
                ForEach(0 ..< poolSizes.count, id: \.self) { index in
                    Text(poolSizes[index].displayName)
                        .tag(index)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 80)

            Spacer()

            Button(action: {
                let selected = poolSizes[selectedPoolIndex]
                workoutState.selectPoolSize(selected.inYards, unit: selected.unit, displayValue: selected.value)
            }) {
                Text("Start")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle(Text("Pool Size").foregroundColor(.green))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PoolSizeSelector(workoutState: WorkoutState())
    }
}

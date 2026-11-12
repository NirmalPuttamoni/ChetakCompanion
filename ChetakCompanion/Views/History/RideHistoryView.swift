//
//  RideHistoryView.swift
//  ChetakCompanion
//
//  List of past rides with swipe-to-delete and empty state.
//

import SwiftUI

struct RideHistoryView: View {
    @StateObject private var historyManager = RideHistoryManager.shared

    private let darkBg = Color(hex: "1A1A2E")
    private let accentGreen = Color(hex: "00A651")

    var body: some View {
        NavigationStack {
            Group {
                if historyManager.rides.isEmpty {
                    emptyState
                } else {
                    rideList
                }
            }
            .background(darkBg.ignoresSafeArea())
            .navigationTitle("Ride History")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Ride List

    private var rideList: some View {
        List {
            ForEach(historyManager.rides) { ride in
                NavigationLink(destination: RideDetailView(ride: ride)) {
                    RideHistoryRow(ride: ride)
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .onDelete { offsets in
                historyManager.delete(at: offsets)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "road.lanes")
                .font(.system(size: 60))
                .foregroundStyle(accentGreen.opacity(0.5))

            Text("No Rides Yet")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Your ride history will appear here once\nyou complete your first ride with Chetak.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Ride Row

struct RideHistoryRow: View {
    let ride: RideRecord

    private let accentGreen = Color(hex: "00A651")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ride.startTime, style: .date)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: ride.rideMode == .eco ? "leaf.fill" : "bolt.fill")
                    .foregroundStyle(ride.rideMode == .eco ? accentGreen : .orange)
            }

            HStack(spacing: 16) {
                Label(String(format: "%.1f km", ride.distance), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(ride.formattedDuration, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Label(String(format: "%.0f km/h", ride.avgSpeed), systemImage: "speedometer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Battery used
            HStack(spacing: 4) {
                Image(systemName: "battery.25")
                    .foregroundStyle(.secondary)
                Text("\(ride.batteryUsed)% used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("With Rides") {
    let mockRides = [
        RideRecord(
            id: UUID(),
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-1200),
            distance: 18.4,
            avgSpeed: 28.5,
            maxSpeed: 52.0,
            startBattery: 92,
            endBattery: 74,
            rideMode: .eco
        ),
        RideRecord(
            id: UUID(),
            startTime: Date().addingTimeInterval(-86400),
            endTime: Date().addingTimeInterval(-84000),
            distance: 11.2,
            avgSpeed: 34.0,
            maxSpeed: 61.5,
            startBattery: 65,
            endBattery: 49,
            rideMode: .sport
        )
    ]

    return NavigationStack {
        List(mockRides) { ride in
            NavigationLink(destination: RideDetailView(ride: ride)) {
                RideHistoryRow(ride: ride)
            }
            .listRowBackground(Color.white.opacity(0.05))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(hex: "1A1A2E").ignoresSafeArea())
        .navigationTitle("Ride History")
    }
}

#Preview("Empty") {
    RideHistoryView()
}

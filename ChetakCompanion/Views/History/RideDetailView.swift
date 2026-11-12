//
//  RideDetailView.swift
//  ChetakCompanion
//
//  Detailed view for a single ride with stats grid.
//

import SwiftUI

struct RideDetailView: View {
    let ride: RideRecord

    private let darkBg = Color(hex: "1A1A2E")
    private let accentGreen = Color(hex: "00A651")

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Stats Grid
                statsGrid

                // Ride Mode
                rideModeSection
            }
            .padding()
        }
        .background(darkBg.ignoresSafeArea())
        .navigationTitle("Ride Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(ride.startTime, style: .date)
                .font(.title2.bold())
                .foregroundStyle(.white)

            HStack(spacing: 4) {
                Text(ride.startTime, style: .time)
                Text("–")
                Text(ride.endTime, style: .time)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                title: "Distance",
                value: String(format: "%.1f km", ride.distance),
                color: accentGreen
            )

            StatCard(
                icon: "clock.fill",
                title: "Duration",
                value: formattedDuration,
                color: .blue
            )

            StatCard(
                icon: "speedometer",
                title: "Avg Speed",
                value: String(format: "%.1f km/h", ride.avgSpeed),
                color: .orange
            )

            StatCard(
                icon: "gauge.with.dots.needle.33percent",
                title: "Max Speed",
                value: String(format: "%.1f km/h", ride.maxSpeed),
                color: .red
            )

            StatCard(
                icon: "battery.75",
                title: "Battery Used",
                value: "\(ride.startBattery - ride.endBattery)%",
                color: .yellow
            )

            StatCard(
                icon: "bolt.fill",
                title: "Start → End",
                value: "\(ride.startBattery)% → \(ride.endBattery)%",
                color: accentGreen
            )
        }
    }

    // MARK: - Ride Mode Section

    private var rideModeSection: some View {
        HStack {
            Image(systemName: ride.rideMode == .eco ? "leaf.fill" : "bolt.fill")
                .font(.title2)
                .foregroundStyle(ride.rideMode == .eco ? accentGreen : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Ride Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(ride.rideMode == .eco ? "Eco" : "Sport")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        let interval = ride.endTime.timeIntervalSince(ride.startTime)
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(remainingMinutes)m"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RideDetailView(ride: RideRecord(
            id: UUID(),
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            distance: 24.5,
            avgSpeed: 32.4,
            maxSpeed: 55.0,
            startBattery: 95,
            endBattery: 68,
            rideMode: .eco
        ))
    }
}

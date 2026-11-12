//
//  DashboardView.swift
//  ChetakCompanion
//
//  Main dashboard displaying scooter status, battery, speed, and ride mode.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var scooterData: ScooterData

    @State private var animatePulse = false

    private let darkBg = Color(hex: "1A1A2E")
    private let accentGreen = Color(hex: "00A651")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status Banner
                    ConnectionStatusBanner()

                    // Battery & Range Section
                    HStack(spacing: 24) {
                        BatteryGaugeView(percentage: scooterData.batteryLevel)
                            .frame(width: 150, height: 150)

                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Range")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(String(format: "%.0f", scooterData.range))
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("km")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Trip")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(String(format: "%.1f", scooterData.tripDistance))
                                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("km")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Speed Gauge
                    SpeedGaugeView(speed: scooterData.speed)
                        .frame(height: 200)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Ride Mode Toggle
                    rideModeSection

                    // Quick Connect Button (when disconnected)
                    if !(bluetoothManager.isConnected || scooterData.isConnected) {
                        quickConnectButton
                    }
                }
                .padding()
            }
            .background(darkBg.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Ride Mode Section

    private var rideModeSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ride Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(scooterData.rideMode == .eco ? "Eco" : "Sport")
                    .font(.title2.bold())
                    .foregroundStyle(scooterData.rideMode == .eco ? accentGreen : .orange)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.4)) {
                    let newMode: RideMode = scooterData.rideMode == .eco ? .sport : .eco
                    scooterData.rideMode = newMode
                    if bluetoothManager.isConnected {
                        bluetoothManager.sendCommand(.setRideMode(newMode))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: scooterData.rideMode == .eco ? "leaf.fill" : "bolt.fill")
                    Text(scooterData.rideMode == .eco ? "Switch to Sport" : "Switch to Eco")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    scooterData.rideMode == .eco
                        ? Color.orange.opacity(0.2)
                        : accentGreen.opacity(0.2)
                )
                .foregroundStyle(scooterData.rideMode == .eco ? .orange : accentGreen)
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quick Connect Button

    private var quickConnectButton: some View {
        Button {
            bluetoothManager.startScanning()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title3)
                Text("Connect to Chetak")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(accentGreen)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Preview

#Preview {
    let data = ScooterData()
    data.batteryLevel = 82
    data.range = 98
    data.speed = 42
    data.tripDistance = 14.6
    data.rideMode = .eco
    data.isConnected = true

    let ble = BluetoothManager()
    ble.connectionState = .connected
    ble.isConnected = true

    return DashboardView()
        .environmentObject(ble)
        .environmentObject(data)
}

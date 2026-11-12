//
//  SettingsView.swift
//  ChetakCompanion
//
//  App settings: connection, navigation preferences, background activity, and about.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var scooterData: ScooterData

    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @AppStorage("autoConnect") private var autoConnect = true

    private let darkBg = Color(hex: "1A1A2E")
    private let accentGreen = Color(hex: "00A651")

    var body: some View {
        NavigationStack {
            List {
                // Scooter Connection Section
                Section {
                    HStack {
                        Label("Paired Scooter", systemImage: "bicycle")
                        Spacer()
                        Text(isScooterConnected
                             ? (bluetoothManager.connectedPeripheral?.name ?? "Chetak 3501")
                             : "Not Connected")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Status", systemImage: "circle.fill")
                            .foregroundStyle(connectionColor)
                        Spacer()
                        Text(connectionStatusText)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        if isScooterConnected {
                            bluetoothManager.disconnect()
                        } else {
                            bluetoothManager.startScanning()
                        }
                    } label: {
                        Label(
                            isScooterConnected ? "Disconnect" : "Reconnect",
                            systemImage: isScooterConnected ? "link.badge.minus" : "link.badge.plus"
                        )
                        .foregroundStyle(isScooterConnected ? .red : accentGreen)
                    }
                } header: {
                    Text("Scooter Connection")
                }
                .listRowBackground(Color.white.opacity(0.05))

                // Navigation Section
                Section {
                    Toggle(isOn: $keepScreenOn) {
                        Label("Keep Screen On", systemImage: "sun.max.fill")
                    }
                    .tint(accentGreen)

                    Toggle(isOn: $autoConnect) {
                        Label("Auto-Connect", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .tint(accentGreen)
                } header: {
                    Text("Navigation")
                }
                .listRowBackground(Color.white.opacity(0.05))

                // Background Activity Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How It Works", systemImage: "info.circle")
                            .font(.subheadline.weight(.medium))

                        Text("ChetakCompanion uses Background Location and Bluetooth to keep navigation active on your Chetak's dashboard even when your iPhone screen is locked.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("This uses minimal battery thanks to BLE low-energy and optimized location updates.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open iOS Settings", systemImage: "gear")
                            .foregroundStyle(accentGreen)
                    }
                } header: {
                    Text("Background Activity")
                }
                .listRowBackground(Color.white.opacity(0.05))

                // About Section
                Section {
                    HStack {
                        Label("App Version", systemImage: "app.badge")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Scooter Model", systemImage: "bicycle")
                        Spacer()
                        Text("Bajaj Chetak 3501")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Build", systemImage: "hammer")
                        Spacer()
                        Text("2024.1")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(darkBg.ignoresSafeArea())
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Helpers

    private var isScooterConnected: Bool {
        bluetoothManager.isConnected || scooterData.isConnected
    }

    private var connectionColor: Color {
        switch bluetoothManager.connectionState {
        case .connected: return accentGreen
        case .reconnecting, .connecting, .scanning: return .orange
        case .disconnected: return .red
        }
    }

    private var connectionStatusText: String {
        switch bluetoothManager.connectionState {
        case .connected: return "Connected"
        case .scanning: return "Scanning..."
        case .connecting: return "Connecting..."
        case .reconnecting: return "Reconnecting..."
        case .disconnected: return "Disconnected"
        }
    }
}

// MARK: - Preview

#Preview {
    let data = ScooterData()
    data.isConnected = true

    let ble = BluetoothManager()
    ble.connectionState = .connected
    ble.isConnected = true

    return SettingsView()
        .environmentObject(ble)
        .environmentObject(data)
}

//
//  ConnectionStatusBanner.swift
//  ChetakCompanion
//
//  Horizontal status banner displaying the current BLE connection state.
//

import SwiftUI

struct ConnectionStatusBanner: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    @State private var isPulsing = false

    private let accentGreen = Color(hex: "00A651")

    var body: some View {
        HStack(spacing: 12) {
            // Animated status dot
            ZStack {
                if bluetoothManager.connectionState == .connected {
                    Circle()
                        .fill(statusColor.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .scaleEffect(isPulsing ? 1.4 : 0.8)
                        .opacity(isPulsing ? 0.0 : 0.8)
                }

                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
            }
            .frame(width: 22, height: 22)

            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Connection icon
            Image(systemName: statusIcon)
                .font(.subheadline)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(statusColor.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(statusColor.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .animation(.easeInOut(duration: 0.35), value: bluetoothManager.connectionState)
        .onAppear {
            updatePulseAnimation()
        }
        .onChange(of: bluetoothManager.connectionState) { _, _ in
            updatePulseAnimation()
        }
    }

    // MARK: - Helpers

    private func updatePulseAnimation() {
        if bluetoothManager.connectionState == .connected {
            isPulsing = false
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        } else {
            isPulsing = false
        }
    }

    private var statusColor: Color {
        switch bluetoothManager.connectionState {
        case .connected:
            return accentGreen
        case .reconnecting, .connecting, .scanning:
            return .orange
        case .disconnected:
            return .red
        }
    }

    private var statusTitle: String {
        switch bluetoothManager.connectionState {
        case .connected:
            return bluetoothManager.connectedPeripheral?.name ?? "Chetak 3501 Connected"
        case .reconnecting:
            return "Reconnecting to Chetak..."
        case .connecting:
            return "Connecting..."
        case .scanning:
            return "Scanning for Chetak..."
        case .disconnected:
            return "Scooter Disconnected"
        }
    }

    private var statusSubtitle: String {
        switch bluetoothManager.connectionState {
        case .connected:
            return "Live telemetry & dashboard sync active"
        case .reconnecting:
            return "Waiting for scooter to come in range"
        case .connecting:
            return "Establishing BLE link"
        case .scanning:
            return "Searching nearby Bluetooth devices"
        case .disconnected:
            return "Tap connect to pair with your scooter"
        }
    }

    private var statusIcon: String {
        switch bluetoothManager.connectionState {
        case .connected:
            return "checkmark.circle.fill"
        case .reconnecting, .connecting, .scanning:
            return "arrow.triangle.2.circlepath"
        case .disconnected:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Preview

#Preview("Connected") {
    let manager = BluetoothManager()
    manager.connectionState = .connected
    manager.isConnected = true
    return ConnectionStatusBanner()
        .environmentObject(manager)
        .padding()
        .background(Color(hex: "1A1A2E"))
}

#Preview("Reconnecting") {
    let manager = BluetoothManager()
    manager.connectionState = .reconnecting
    return ConnectionStatusBanner()
        .environmentObject(manager)
        .padding()
        .background(Color(hex: "1A1A2E"))
}

#Preview("Disconnected") {
    ConnectionStatusBanner()
        .environmentObject(BluetoothManager())
        .padding()
        .background(Color(hex: "1A1A2E"))
}

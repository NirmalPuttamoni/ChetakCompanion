import Foundation
import CoreBluetooth
import SwiftUI

// MARK: - BLE Service & Characteristic UUIDs

/// Bluetooth Low Energy identifiers for the Bajaj Chetak 3501 dashboard.
enum ChetakBLE {
    /// Primary GATT service exposed by the Chetak dashboard module.
    static let chetakServiceUUID      = CBUUID(string: "B7E30001-1B3F-4C07-A6A0-3ECDA80C7E00")

    /// Characteristic for sending navigation instructions (phone → scooter).
    static let navigationCharUUID     = CBUUID(string: "B7E30002-1B3F-4C07-A6A0-3ECDA80C7E00")

    /// Characteristic for receiving telemetry data (scooter → phone).
    static let telemetryCharUUID      = CBUUID(string: "B7E30003-1B3F-4C07-A6A0-3ECDA80C7E00")

    /// Characteristic for sending control commands (phone → scooter).
    static let commandCharUUID        = CBUUID(string: "B7E30004-1B3F-4C07-A6A0-3ECDA80C7E00")
}

// MARK: - App Constants

enum AppConstants {
    /// Seconds to wait before attempting a BLE reconnection.
    static let reconnectDelay: TimeInterval = 3.0

    /// Maximum consecutive reconnection attempts before giving up.
    static let maxReconnectAttempts: Int = 5

    /// Minimum interval (seconds) between location updates sent to the dashboard.
    static let locationUpdateInterval: TimeInterval = 1.0

    /// Distance filter (meters) for CLLocationManager.
    static let locationDistanceFilter: Double = 5.0

    /// BLE state restoration identifier.
    static let bleRestorationID = "com.chetak.companion.central"

    /// UserDefaults suite name.
    static let appGroupID = "group.com.chetak.companion"
}

// MARK: - Chetak Brand Colors

extension Color {
    /// Chetak brand green (#00A651).
    static let chetakGreen = Color(hex: "00A651")

    /// Dark background used in the Chetak UI (#1A1A2E).
    static let chetakDark  = Color(hex: "1A1A2E")

    /// Accent light variant.
    static let chetakLightGreen = Color(hex: "4CD787")

    /// Secondary dark shade.
    static let chetakCharcoal = Color(hex: "2D2D44")
}

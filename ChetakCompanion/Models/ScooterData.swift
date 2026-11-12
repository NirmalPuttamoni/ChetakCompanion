import Foundation
import Combine

// MARK: - Ride Mode

/// The active ride mode on the Chetak 3501.
enum RideMode: String, CaseIterable, Codable, Identifiable {
    case eco
    case sport

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eco:   return "Eco"
        case .sport: return "Sport"
        }
    }

    var iconName: String {
        switch self {
        case .eco:   return "leaf.fill"
        case .sport: return "bolt.fill"
        }
    }
}

// MARK: - Navigation Direction

/// Turn-by-turn direction types sent to the scooter dashboard.
enum NavigationDirection: String, Codable {
    case left
    case right
    case straight
    case uTurn
    case arrive
}

// MARK: - Navigation Instruction

/// A single navigation instruction to be displayed on the Chetak dashboard.
struct NavigationInstruction: Identifiable, Equatable {
    let id = UUID()
    let direction: NavigationDirection
    let streetName: String
    let distanceMeters: Double

    /// SF Symbol name matching the direction.
    var iconName: String {
        switch direction {
        case .left:     return "arrow.turn.up.left"
        case .right:    return "arrow.turn.up.right"
        case .straight: return "arrow.up"
        case .uTurn:    return "arrow.uturn.left"
        case .arrive:   return "mappin.and.ellipse"
        }
    }

    /// Human-readable distance string.
    var formattedDistance: String {
        if distanceMeters >= 1000 {
            return String(format: "%.1f km", distanceMeters / 1000)
        } else {
            return String(format: "%.0f m", distanceMeters)
        }
    }
}

// MARK: - Scooter Data

/// Observable model that holds the live telemetry state of the connected
/// Bajaj Chetak 3501 scooter.
class ScooterData: ObservableObject {

    // MARK: Battery & Range
    @Published var batteryLevel: Int = 0          // 0-100 %
    @Published var range: Double = 0.0            // remaining range in km

    // MARK: Speed & Ride
    @Published var speed: Double = 0.0            // current speed in km/h
    @Published var rideMode: RideMode = .eco

    // MARK: Connection
    @Published var isConnected: Bool = false
    @Published var lastConnected: Date? = nil

    // MARK: Trip
    @Published var tripDistance: Double = 0.0     // trip distance in km
    @Published var odometer: Double = 0.0        // total odometer in km

    // MARK: Navigation
    @Published var currentInstruction: NavigationInstruction? = nil
    @Published var isNavigating: Bool = false

    // MARK: - Methods

    /// Reset trip-level counters (e.g. when the user starts a new ride).
    func resetTrip() {
        tripDistance = 0.0
    }

    /// Update state from a raw BLE telemetry payload.
    /// Called by BluetoothManager when a telemetry characteristic updates.
    func update(from payload: Data) {
        guard payload.count >= 16 else { return }

        let applyUpdate = {
            self.batteryLevel = Int(payload[0])
            self.range        = Double(payload[1]) + Double(payload[2]) / 10.0
            self.speed        = Double(payload[3]) + Double(payload[4]) / 10.0
            self.rideMode     = payload[5] == 0x01 ? .sport : .eco
            self.tripDistance = Double((UInt16(payload[6]) << 8) | UInt16(payload[7])) / 10.0
            self.odometer     = Double(
                (UInt32(payload[8])  << 24) |
                (UInt32(payload[9])  << 16) |
                (UInt32(payload[10]) << 8)  |
                 UInt32(payload[11])
            ) / 10.0
            self.lastConnected = Date()
        }

        if Thread.isMainThread {
            applyUpdate()
        } else {
            DispatchQueue.main.async(execute: applyUpdate)
        }
    }
}

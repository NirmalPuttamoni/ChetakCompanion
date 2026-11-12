import Foundation

// MARK: - Ride Record

/// A single completed ride session recorded for the history log.
struct RideRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let distance: Double       // km
    let avgSpeed: Double       // km/h
    let maxSpeed: Double       // km/h
    let startBattery: Int      // 0-100 %
    let endBattery: Int        // 0-100 %
    let rideMode: RideMode

    /// Duration of the ride in seconds.
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Formatted duration string (e.g. "1h 23m").
    var formattedDuration: String {
        let hours   = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Battery consumed during this ride.
    var batteryUsed: Int {
        max(0, startBattery - endBattery)
    }
}

// MARK: - Ride History Manager

/// Persists ride records to UserDefaults and provides CRUD helpers.
class RideHistoryManager: ObservableObject {

    static let shared = RideHistoryManager()

    private let storageKey = "com.chetak.companion.rideHistory"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    @Published private(set) var rides: [RideRecord] = []

    init() {
        rides = fetchAll()
    }

    // MARK: - Public API

    /// Append a new ride and persist.
    func add(_ ride: RideRecord) {
        rides.insert(ride, at: 0)           // newest first
        save(rides)
    }

    /// Fetch all persisted rides, newest first.
    func fetchAll() -> [RideRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        do {
            let records = try decoder.decode([RideRecord].self, from: data)
            return records.sorted { $0.startTime > $1.startTime }
        } catch {
            print("[RideHistoryManager] Decode error: \(error)")
            return []
        }
    }

    /// Delete a single ride by id.
    func delete(id: UUID) {
        rides.removeAll { $0.id == id }
        save(rides)
    }

    /// Delete rides at the given index set (for SwiftUI List).
    func delete(at offsets: IndexSet) {
        rides.remove(atOffsets: offsets)
        save(rides)
    }

    /// Remove all ride history.
    func deleteAll() {
        rides.removeAll()
        save(rides)
    }

    // MARK: - Persistence

    private func save(_ records: [RideRecord]) {
        do {
            let data = try encoder.encode(records)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[RideHistoryManager] Encode error: \(error)")
        }
    }
}

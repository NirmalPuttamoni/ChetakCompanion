import Foundation
import CoreLocation

// MARK: - NavigationEngine

/// A lightweight on-device navigation engine that generates simplified
/// turn-by-turn instructions and encodes them into a compact binary format
/// suitable for BLE transmission to the Chetak scooter dashboard.
struct NavigationEngine {

    // MARK: - Route Calculation

    /// Build a very simplified route (list of waypoints) between two points.
    /// In a production app this would call a routing API; here we generate
    /// intermediate waypoints along a straight line.
    func calculateRoute(from start: CLLocationCoordinate2D,
                        to end: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {

        var route: [CLLocationCoordinate2D] = [start]

        // Generate intermediate waypoints to simulate a realistic route.
        let steps = max(Int(distance(from: start, to: end) / 200), 2) // ~one point per 200 m
        for i in 1..<steps {
            let fraction = Double(i) / Double(steps)
            let lat = start.latitude  + (end.latitude  - start.latitude)  * fraction
            let lon = start.longitude + (end.longitude - start.longitude) * fraction
            // Add a slight jitter to simulate street-level turns.
            let jitter = (Double(i % 3) - 1.0) * 0.0003
            route.append(CLLocationCoordinate2D(latitude: lat + jitter, longitude: lon - jitter))
        }

        route.append(end)
        return route
    }

    // MARK: - Instruction Generation

    /// Generate turn-by-turn instructions along `route` toward `destination`.
    func generateInstructions(
        along route: [CLLocationCoordinate2D],
        destination: CLLocationCoordinate2D,
        currentLocation: CLLocationCoordinate2D? = nil
    ) -> [NavigationInstruction] {

        guard route.count >= 2 else { return [] }

        // Find the segment closest to the rider's current location.
        let startIndex: Int
        if let current = currentLocation {
            startIndex = closestSegmentIndex(for: current, in: route)
        } else {
            startIndex = 0
        }

        var instructions: [NavigationInstruction] = []

        for i in startIndex..<(route.count - 1) {
            let from = route[i]
            let to   = route[i + 1]
            let next: CLLocationCoordinate2D? = (i + 2 < route.count) ? route[i + 2] : nil

            let dist = distance(from: from, to: to)
            let direction = turnDirection(from: from, through: to, to: next)
            let streetName = syntheticStreetName(segmentIndex: i)

            instructions.append(
                NavigationInstruction(
                    direction: direction,
                    streetName: streetName,
                    distanceMeters: dist
                )
            )
        }

        // Final "arrive" instruction.
        if let last = route.last {
            let distToEnd = distance(from: last, to: destination)
            instructions.append(
                NavigationInstruction(
                    direction: .arrive,
                    streetName: "Destination",
                    distanceMeters: distToEnd
                )
            )
        }

        return instructions
    }

    // MARK: - BLE Encoding / Decoding

    /// Compact binary format:
    /// ```
    /// Byte 0        : UInt8  direction enum (0=left,1=right,2=straight,3=uTurn,4=arrive)
    /// Bytes 1…4     : Float32 (little-endian) distance in meters
    /// Bytes 5…(n)   : UTF-8 encoded street name (variable length)
    /// ```
    static func encodeForBLE(_ instruction: NavigationInstruction) -> Data {
        var data = Data()

        // 1 byte — direction mapped to UInt8
        data.append(directionToByte(instruction.direction))

        // 4 bytes — distance (Float32 LE)
        var dist = Float(instruction.distanceMeters)
        withUnsafeBytes(of: &dist) { data.append(contentsOf: $0) }

        // Variable — street name UTF-8
        if let nameData = instruction.streetName.data(using: .utf8) {
            data.append(nameData)
        }

        return data
    }

    /// Decode a BLE payload back into a `NavigationInstruction`.
    /// Returns `nil` if the data is too short or contains an unknown direction.
    static func decodeFromBLE(_ data: Data) -> NavigationInstruction? {
        // Minimum: 1 (direction) + 4 (float) = 5 bytes
        guard data.count >= 5 else { return nil }

        guard let direction = byteToDirection(data[0]) else { return nil }

        let distance: Float = data.subdata(in: 1..<5).withUnsafeBytes { $0.load(as: Float.self) }

        let streetName: String
        if data.count > 5 {
            streetName = String(data: data.subdata(in: 5..<data.count), encoding: .utf8) ?? ""
        } else {
            streetName = ""
        }

        return NavigationInstruction(
            direction: direction,
            streetName: streetName,
            distanceMeters: Double(distance)
        )
    }

    // MARK: - Private Helpers

    /// Haversine distance in meters between two coordinates.
    private func distance(from a: CLLocationCoordinate2D,
                          to b: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let loc2 = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return loc1.distance(from: loc2)
    }

    /// Return the index of the route segment closest to `point`.
    private func closestSegmentIndex(for point: CLLocationCoordinate2D,
                                     in route: [CLLocationCoordinate2D]) -> Int {
        var bestIndex = 0
        var bestDist = Double.greatestFiniteMagnitude

        for i in 0..<route.count {
            let d = distance(from: point, to: route[i])
            if d < bestDist {
                bestDist = d
                bestIndex = i
            }
        }

        return max(bestIndex, 0)
    }

    /// Determine the turn direction at a three-point bend.
    private func turnDirection(from a: CLLocationCoordinate2D,
                               through b: CLLocationCoordinate2D,
                               to c: CLLocationCoordinate2D?) -> NavigationDirection {

        guard let c = c else { return .straight }

        let bearing1 = bearing(from: a, to: b)
        let bearing2 = bearing(from: b, to: c)

        var angle = bearing2 - bearing1
        if angle < -180 { angle += 360 }
        if angle >  180 { angle -= 360 }

        switch angle {
        case -180 ..< -45:  return .right
        case  -45 ..<  45:  return .straight
        case   45 ..< 170:  return .left
        default:            return .uTurn
        }
    }

    /// Initial bearing (degrees, 0 = north) from `a` to `b`.
    private func bearing(from a: CLLocationCoordinate2D,
                         to b: CLLocationCoordinate2D) -> Double {
        let dLon = (b.longitude - a.longitude) * .pi / 180.0
        let lat1 = a.latitude * .pi / 180.0
        let lat2 = b.latitude * .pi / 180.0

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        return atan2(y, x) * 180.0 / .pi
    }

    /// Generate a plausible street name for a route segment (placeholder).
    private func syntheticStreetName(segmentIndex: Int) -> String {
        let names = [
            "MG Road", "FC Road", "JM Road", "University Road",
            "Baner Road", "SB Road", "Law College Road",
            "Karve Road", "Tilak Road", "Laxmi Road"
        ]
        return names[segmentIndex % names.count]
    }

    // MARK: - Direction ↔ Byte Mapping

    /// NavigationDirection has String raw values, so we map to UInt8 manually
    /// for the compact BLE wire format.
    private static func directionToByte(_ dir: NavigationDirection) -> UInt8 {
        switch dir {
        case .left:     return 0x00
        case .right:    return 0x01
        case .straight: return 0x02
        case .uTurn:    return 0x03
        case .arrive:   return 0x04
        }
    }

    private static func byteToDirection(_ byte: UInt8) -> NavigationDirection? {
        switch byte {
        case 0x00: return .left
        case 0x01: return .right
        case 0x02: return .straight
        case 0x03: return .uTurn
        case 0x04: return .arrive
        default:   return nil
        }
    }
}

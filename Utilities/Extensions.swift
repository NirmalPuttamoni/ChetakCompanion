import SwiftUI

// MARK: - Color + Hex

extension Color {
    /// Initialize a `Color` from a hex string (e.g. "00A651" or "#00A651").
    init(hex: String) {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >>  8) & 0xFF) / 255.0
        let b = Double( rgb        & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Date Formatting

extension Date {
    /// e.g. "Nov 12, 2026"
    var shortDateString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: self)
    }

    /// e.g. "11:30 AM"
    var shortTimeString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .short
        return fmt.string(from: self)
    }

    /// e.g. "Nov 12, 2026 at 11:30 AM"
    var dateTimeString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: self)
    }

    /// Relative description, e.g. "2 hours ago".
    var relativeString: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .full
        return fmt.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Double Formatting

extension Double {
    /// Format as distance, e.g. "12.3 km" or "850 m".
    var formattedDistance: String {
        if self >= 1.0 {
            return String(format: "%.1f km", self)
        } else {
            return String(format: "%.0f m", self * 1000)
        }
    }

    /// Format as speed, e.g. "45 km/h".
    var formattedSpeed: String {
        String(format: "%.0f km/h", self)
    }

    /// Format with one decimal place, e.g. "3.7".
    var oneDecimal: String {
        String(format: "%.1f", self)
    }
}

// MARK: - Data + Hex String (BLE Debugging)

extension Data {
    /// Convert raw bytes to a hex-encoded string for BLE packet debugging.
    /// e.g. `Data([0x4A, 0xFF])` → `"4AFF"`.
    var hexString: String {
        map { String(format: "%02X", $0) }.joined()
    }

    /// Hex string with spaces between bytes, e.g. "4A FF".
    var hexStringSpaced: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

// MARK: - Int Formatting

extension Int {
    /// Format battery percentage, e.g. "85%".
    var batteryString: String {
        "\(self)%"
    }
}

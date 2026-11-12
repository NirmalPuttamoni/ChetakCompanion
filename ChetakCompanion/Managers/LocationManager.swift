import Foundation
import CoreLocation
import Combine

// MARK: - LocationManager

/// Manages GPS location tracking and turn-by-turn navigation for
/// ChetakCompanion.
///
/// **Background-operation contract**:
/// - `allowsBackgroundLocationUpdates = true` while navigating.
/// - `pausesLocationUpdatesAutomatically = false` during active navigation.
/// - `showsBackgroundLocationIndicator = true` (blue status-bar pill).
/// - When navigation stops, background updates are disabled and accuracy is
///   downgraded to save battery.
final class LocationManager: NSObject, ObservableObject {

    // MARK: Published State

    @Published var currentLocation: CLLocation?
    @Published var currentHeading: CLHeading?
    @Published var isNavigating: Bool = false
    @Published var currentRoute: [CLLocationCoordinate2D] = []
    @Published var navigationInstructions: [NavigationInstruction] = []
    @Published var currentInstruction: NavigationInstruction?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var destination: CLLocationCoordinate2D?

    // MARK: Dependencies

    /// Injected after init so the location manager can push nav data to the
    /// BLE dashboard. Weak to avoid a retain cycle.
    weak var bluetoothManager: BluetoothManager?

    // MARK: Private

    private let locationManager = CLLocationManager()
    private let navigationEngine = NavigationEngine()

    /// Timer-free simulation state.
    private var simulationLocations: [CLLocation] = []
    private var simulationIndex: Int = 0
    private var isSimulating: Bool = false

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.showsBackgroundLocationIndicator = true
        // Background updates start disabled; enabled when navigation begins.
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
    }

    // MARK: - Permissions

    /// Request "Always" authorization so the app can keep tracking in the
    /// background (required when the screen is locked).
    func requestPermissions() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Navigation Lifecycle

    /// Begin turn-by-turn navigation to `destination`.
    func startNavigation(to dest: CLLocationCoordinate2D) {
        destination = dest
        isNavigating = true

        // Enable background location.
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation

        // Build the initial route.
        if let current = currentLocation?.coordinate {
            let route = navigationEngine.calculateRoute(from: current, to: dest)
            currentRoute = route
            navigationInstructions = navigationEngine.generateInstructions(
                along: route, destination: dest
            )
            currentInstruction = navigationInstructions.first
        }

        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    /// Stop navigation and downgrade location accuracy to save battery.
    func stopNavigation() {
        isNavigating = false
        destination = nil
        currentRoute = []
        navigationInstructions = []
        currentInstruction = nil

        // Downgrade to save battery.
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        locationManager.stopUpdatingHeading()
        // Keep location updates at reduced accuracy for the dashboard widget,
        // or stop entirely:
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Simulation (testing only)

    /// Generate a set of mock locations and instructions for UI development
    /// when no real GPS signal or BLE peripheral is available.
    func simulateNavigation() {
        isSimulating = true
        isNavigating = true

        // A short simulated route (straight line with turns).
        let startCoord = CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567) // Pune
        let endCoord   = CLLocationCoordinate2D(latitude: 18.5314, longitude: 73.8446)

        destination = endCoord

        let steps = 20
        var locations: [CLLocation] = []
        for i in 0...steps {
            let fraction = Double(i) / Double(steps)
            let lat = startCoord.latitude  + (endCoord.latitude  - startCoord.latitude)  * fraction
            let lon = startCoord.longitude + (endCoord.longitude - startCoord.longitude) * fraction
            locations.append(CLLocation(latitude: lat, longitude: lon))
        }

        simulationLocations = locations
        simulationIndex = 0
        currentRoute = locations.map(\.coordinate)

        navigationInstructions = [
            NavigationInstruction(direction: .straight, streetName: "MG Road", distanceMeters: 500),
            NavigationInstruction(direction: .left,     streetName: "FC Road", distanceMeters: 300),
            NavigationInstruction(direction: .right,    streetName: "JM Road", distanceMeters: 200),
            NavigationInstruction(direction: .straight, streetName: "University Rd", distanceMeters: 400),
            NavigationInstruction(direction: .arrive,   streetName: "Destination", distanceMeters: 0),
        ]
        currentInstruction = navigationInstructions.first

        // Feed the first simulated location.
        advanceSimulation()
    }

    /// Advance to the next simulated location. Call from a test harness or
    /// UI button — no internal timer is used.
    func advanceSimulation() {
        guard isSimulating,
              simulationIndex < simulationLocations.count else {
            isSimulating = false
            return
        }

        let location = simulationLocations[simulationIndex]
        simulationIndex += 1

        currentLocation = location
        processLocationUpdate(location)
    }

    // MARK: - Location Processing

    private func processLocationUpdate(_ location: CLLocation) {
        guard isNavigating, let dest = destination else { return }

        // Recalculate instructions based on current position.
        let updatedInstructions = navigationEngine.generateInstructions(
            along: currentRoute, destination: dest, currentLocation: location.coordinate
        )
        navigationInstructions = updatedInstructions

        if let next = updatedInstructions.first {
            currentInstruction = next
            // Push to the scooter dashboard via BLE.
            bluetoothManager?.sendNavigationData(next)
        }

        // Check if arrived (within 15 m of destination).
        let destLocation = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
        if location.distance(from: destLocation) < 15 {
            let arriveInstruction = NavigationInstruction(
                direction: .arrive,
                streetName: "Destination",
                distanceMeters: 0
            )
            currentInstruction = arriveInstruction
            bluetoothManager?.sendNavigationData(arriveInstruction)
            stopNavigation()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }

        currentLocation = latest

        if isNavigating {
            processLocationUpdate(latest)
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateHeading newHeading: CLHeading) {
        currentHeading = newHeading
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedAlways:
            // Full background access — start updates if navigating.
            if isNavigating {
                manager.startUpdatingLocation()
                manager.startUpdatingHeading()
            }
        case .authorizedWhenInUse:
            // Prompt upgrade to Always.
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            isNavigating = false
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print("[Location] Error: \(error.localizedDescription)")
    }
}

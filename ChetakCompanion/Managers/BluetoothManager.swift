import Foundation
import CoreBluetooth
import Combine

// MARK: - BLE Service & Characteristic UUIDs

let chetakServiceUUID     = CBUUID(string: "4E530000-B5A3-F393-E0A9-E50E24DCCA9E")
let navigationCharUUID    = CBUUID(string: "4E530001-B5A3-F393-E0A9-E50E24DCCA9E")
let telemetryCharUUID     = CBUUID(string: "4E530002-B5A3-F393-E0A9-E50E24DCCA9E")
let commandCharUUID       = CBUUID(string: "4E530003-B5A3-F393-E0A9-E50E24DCCA9E")

// MARK: - Connection State

enum ConnectionState: String, Equatable {
    case disconnected
    case scanning
    case connecting
    case connected
    case reconnecting
}

// MARK: - Scooter Commands

enum ScooterCommand {
    case requestTelemetry
    case setRideMode(RideMode)
    case ping

    /// Encode the command into a Data payload for BLE write.
    func encode() -> Data {
        switch self {
        case .requestTelemetry:
            return Data([0x01])
        case .setRideMode(let mode):
            let modeByte: UInt8 = mode == .eco ? 0x00 : 0x01
            return Data([0x02, modeByte])
        case .ping:
            return Data([0x03])
        }
    }
}

// MARK: - BluetoothManager

/// Manages the BLE connection to a Bajaj Chetak 3501 scooter dashboard.
///
/// **Background-operation contract**:
/// - CBCentralManager is created at app startup (NOT lazily) with a
///   restoration identifier so iOS can re-launch the app in the background.
/// - Scanning always uses explicit service UUIDs (never nil).
/// - Auto-reconnect on every disconnect — iOS queues the connect request and
///   fulfils it when the peripheral is back in range (no timer needed).
/// - State preservation / restoration is fully implemented via
///   `centralManager(_:willRestoreState:)`.
final class BluetoothManager: NSObject, ObservableObject {

    // MARK: Published State

    @Published var connectionState: ConnectionState = .disconnected
    @Published var isScanning: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectedPeripheral: CBPeripheral?

    /// Shared telemetry model — updated on every BLE notification.
    @Published var scooterData = ScooterData()

    // MARK: Private

    /// Created eagerly in `init()` with a restoration identifier.
    private var centralManager: CBCentralManager!

    /// Characteristics cached after service discovery.
    private var navigationCharacteristic: CBCharacteristic?
    private var telemetryCharacteristic: CBCharacteristic?
    private var commandCharacteristic: CBCharacteristic?

    /// Peripherals discovered during a scan (kept alive to avoid ARC release).
    private var discoveredPeripherals: [CBPeripheral] = []

    /// Tracks the current target or connected peripheral so `disconnect()` can
    /// cancel pending connections as well as active ones.
    private var activePeripheral: CBPeripheral?

    /// Peripheral IDs explicitly disconnected by the user, which must not
    /// trigger auto-reconnect in `didDisconnectPeripheral`.
    private var suppressedReconnectIDs: Set<UUID> = []

    // MARK: - Restoration identifier (must be stable across app launches)

    private static let restorationIdentifier = "com.chetakcompanion.bluetooth-central"

    // MARK: - Init

    override init() {
        super.init()

        // CRITICAL: create the central manager immediately so that iOS can
        // restore it after a background termination.
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil, // main queue
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: BluetoothManager.restorationIdentifier
            ]
        )
    }

    // MARK: - Public API

    /// Start scanning for Chetak peripherals.
    /// Uses explicit service UUIDs so that scanning works in the background.
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        guard !isScanning else { return }

        isScanning = true
        connectionState = .scanning
        discoveredPeripherals.removeAll()

        centralManager.scanForPeripherals(
            withServices: [chetakServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    /// Stop an active scan.
    func stopScanning() {
        guard isScanning else { return }
        centralManager.stopScan()
        isScanning = false

        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    /// Initiate a connection to the given peripheral.
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        suppressedReconnectIDs.remove(peripheral.identifier)
        activePeripheral = peripheral
        connectionState = .connecting
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    /// Explicitly disconnect from the current peripheral without triggering
    /// auto-reconnect.
    func disconnect() {
        stopScanning()

        if let peripheral = activePeripheral ?? connectedPeripheral {
            suppressedReconnectIDs.insert(peripheral.identifier)
            centralManager.cancelPeripheralConnection(peripheral)
        }

        activePeripheral = nil
        connectedPeripheral = nil
        isConnected = false
        connectionState = .disconnected
        scooterData.isConnected = false
        resetCharacteristics()
    }

    /// Encode and write a `NavigationInstruction` to the navigation
    /// characteristic on the connected peripheral.
    func sendNavigationData(_ instruction: NavigationInstruction) {
        guard let peripheral = connectedPeripheral,
              let characteristic = navigationCharacteristic else {
            return
        }

        let payload = NavigationEngine.encodeForBLE(instruction)
        peripheral.writeValue(payload, for: characteristic, type: .withResponse)
    }

    /// Encode and write a `ScooterCommand` to the command characteristic.
    func sendCommand(_ command: ScooterCommand) {
        guard let peripheral = connectedPeripheral,
              let characteristic = commandCharacteristic else {
            return
        }

        let payload = command.encode()
        peripheral.writeValue(payload, for: characteristic, type: .withResponse)
    }

    // MARK: - Helpers

    private func resetCharacteristics() {
        navigationCharacteristic = nil
        telemetryCharacteristic = nil
        commandCharacteristic = nil
    }

    private func autoReconnect(_ peripheral: CBPeripheral) {
        connectionState = .reconnecting
        isConnected = false
        // iOS queues the connect and fulfils it when the peripheral
        // re-enters range — no timer required.
        centralManager.connect(peripheral, options: nil)
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    // MARK: State Changes

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // If we were scanning before a state change, resume.
            if connectionState == .scanning {
                startScanning()
            }
        case .poweredOff, .unauthorized, .unsupported:
            isScanning = false
            isConnected = false
            connectionState = .disconnected
            connectedPeripheral = nil
            resetCharacteristics()
        default:
            break
        }
    }

    // MARK: State Restoration

    /// Called when iOS relaunches the app in the background and hands back the
    /// central manager's previous state (connected peripherals, pending
    /// connections, scan services).
    func centralManager(_ central: CBCentralManager,
                        willRestoreState dict: [String: Any]) {

        // Re-attach to peripherals that were connected before the app was
        // terminated by the system.
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                peripheral.delegate = self
                activePeripheral = peripheral
                if peripheral.state == .connected {
                    connectedPeripheral = peripheral
                    isConnected = true
                    connectionState = .connected
                    // Re-discover services in case characteristics were lost.
                    peripheral.discoverServices([chetakServiceUUID])
                } else {
                    // The peripheral was being connected — retry.
                    autoReconnect(peripheral)
                }
            }
        }

        // If a scan was active, the scan service UUIDs are returned so we know
        // scanning will resume automatically once Bluetooth is powered on.
        if let scanServices = dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID],
           !scanServices.isEmpty {
            isScanning = true
            connectionState = .scanning
        }
    }

    // MARK: Discovery

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {

        // Filter by name containing "Chetak" OR by advertised service UUID.
        let nameMatch: Bool = {
            if let name = peripheral.name, name.localizedCaseInsensitiveContains("Chetak") {
                return true
            }
            if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String,
               localName.localizedCaseInsensitiveContains("Chetak") {
                return true
            }
            return false
        }()

        let serviceMatch: Bool = {
            if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                return services.contains(chetakServiceUUID)
            }
            return false
        }()

        guard nameMatch || serviceMatch else { return }

        // Hold a strong reference so ARC doesn't release the peripheral.
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }

        // Auto-connect to the first matching peripheral.
        connect(to: peripheral)
    }

    // MARK: Connection

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        activePeripheral = peripheral
        connectedPeripheral = peripheral
        isConnected = true
        connectionState = .connected
        scooterData.isConnected = true

        // Discover only the Chetak service.
        peripheral.discoverServices([chetakServiceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        if suppressedReconnectIDs.remove(peripheral.identifier) != nil {
            return
        }
        // Retry immediately — no timer needed.
        autoReconnect(peripheral)
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        resetCharacteristics()
        scooterData.isConnected = false

        if suppressedReconnectIDs.remove(peripheral.identifier) != nil {
            if activePeripheral?.identifier == peripheral.identifier {
                activePeripheral = nil
            }
            if connectedPeripheral?.identifier == peripheral.identifier {
                connectedPeripheral = nil
            }
            isConnected = false
            connectionState = .disconnected
            return
        }

        // Auto-reconnect immediately. iOS BLE connect requests don't time
        // out — the system will complete the connection whenever the
        // peripheral comes back in range.
        autoReconnect(peripheral)
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {

    // MARK: Service Discovery

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services where service.uuid == chetakServiceUUID {
            peripheral.discoverCharacteristics(
                [navigationCharUUID, telemetryCharUUID, commandCharUUID],
                for: service
            )
        }
    }

    // MARK: Characteristic Discovery

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case navigationCharUUID:
                navigationCharacteristic = characteristic
            case telemetryCharUUID:
                telemetryCharacteristic = characteristic
                // Subscribe for telemetry notifications.
                peripheral.setNotifyValue(true, for: characteristic)
            case commandCharUUID:
                commandCharacteristic = characteristic
            default:
                break
            }
        }
    }

    // MARK: Incoming Data

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, let data = characteristic.value else { return }

        switch characteristic.uuid {
        case telemetryCharUUID:
            parseTelemetry(data)
        case navigationCharUUID:
            // ACK or response from dashboard — ignored for now.
            break
        default:
            break
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("[BLE] Write failed for \(characteristic.uuid): \(error.localizedDescription)")
        }
    }

    // MARK: Telemetry Parsing

    /// Expected payload layout (20 bytes):
    /// ```
    /// [0]      UInt8   — battery level (0-100)
    /// [1...4]  Float32 — speed km/h (little-endian)
    /// [5...8]  Float32 — range km   (little-endian)
    /// [9]      UInt8   — ride mode (0 = eco, 1 = sport)
    /// [10..13] Float32 — trip distance km
    /// [14..17] Float32 — odometer km
    /// ```
    private func parseTelemetry(_ data: Data) {
        guard data.count >= 18 else { return }

        let battery = Int(data[0])

        let speed: Double = {
            let raw: Float = data.subdata(in: 1..<5).withUnsafeBytes { $0.load(as: Float.self) }
            return Double(raw)
        }()

        let range: Double = {
            let raw: Float = data.subdata(in: 5..<9).withUnsafeBytes { $0.load(as: Float.self) }
            return Double(raw)
        }()

        let mode: RideMode = data[9] == 0x01 ? .sport : .eco

        let tripDistance: Double = {
            let raw: Float = data.subdata(in: 10..<14).withUnsafeBytes { $0.load(as: Float.self) }
            return Double(raw)
        }()

        let odometer: Double = {
            let raw: Float = data.subdata(in: 14..<18).withUnsafeBytes { $0.load(as: Float.self) }
            return Double(raw)
        }()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.scooterData.batteryLevel = battery
            self.scooterData.speed = speed
            self.scooterData.range = range
            self.scooterData.rideMode = mode
            self.scooterData.tripDistance = tripDistance
            self.scooterData.odometer = odometer
            self.scooterData.lastConnected = Date()
        }
    }
}

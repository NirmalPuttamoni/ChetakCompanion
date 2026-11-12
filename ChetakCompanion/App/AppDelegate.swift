import UIKit
import CoreBluetooth

class AppDelegate: NSObject, UIApplicationDelegate {

    /// Central manager initialized with state restoration to maintain BLE
    /// connections across background launches and app terminations.
    var centralManager: CBCentralManager?

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize CBCentralManager with a restoration identifier so iOS
        // can relaunch the app in the background when a BLE event occurs.
        centralManager = CBCentralManager(
            delegate: nil, // BluetoothManager will set itself as delegate
            queue: DispatchQueue(label: "com.chetak.companion.ble", qos: .userInitiated),
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: "com.chetak.companion.central",
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )

        // Check if we were launched due to a Bluetooth state restoration event
        if let bluetoothCentrals = launchOptions?[.bluetoothCentrals] as? [String] {
            print("[AppDelegate] Launched for BLE restoration: \(bluetoothCentrals)")
        }

        return true
    }

    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    // MARK: - Background Handling

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Allow BLE connections to persist in the background
        print("[AppDelegate] Entered background — BLE connections maintained via restoration.")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("[AppDelegate] Terminating — BLE state will be restored on next launch.")
    }
}

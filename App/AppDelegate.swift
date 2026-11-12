import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Check if we were launched due to a Bluetooth state restoration event.
        // BluetoothManager owns the single CBCentralManager with restoration ID.
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

import SwiftUI
import BackgroundTasks

@main
struct ChetakCompanionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var bluetoothManager: BluetoothManager
    @StateObject private var locationManager: LocationManager

    init() {
        let bt = BluetoothManager()
        let loc = LocationManager()
        loc.bluetoothManager = bt
        _bluetoothManager = StateObject(wrappedValue: bt)
        _locationManager = StateObject(wrappedValue: loc)
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetoothManager)
                .environmentObject(locationManager)
                .environmentObject(bluetoothManager.scooterData)
        }
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.chetak.companion.refresh",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleAppRefresh(task: refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.chetak.companion.telemetry",
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            handleTelemetrySync(task: processingTask)
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Attempt to reconnect to the scooter in the background
        task.setTaskCompleted(success: true)
    }

    private func handleTelemetrySync(task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Sync any pending telemetry data
        task.setTaskCompleted(success: true)
    }

    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.chetak.companion.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
}

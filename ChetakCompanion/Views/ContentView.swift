//
//  ContentView.swift
//  ChetakCompanion
//
//  Main tab-based navigation for the Chetak Companion app.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var scooterData: ScooterData

    @State private var selectedTab: Tab = .dashboard

    enum Tab: String {
        case dashboard, navigation, history, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
                .tag(Tab.dashboard)

            ChetakNavigationView()
                .tabItem {
                    Label("Navigation", systemImage: "location.fill")
                }
                .tag(Tab.navigation)

            RideHistoryView()
                .tabItem {
                    Label("Ride History", systemImage: "clock.fill")
                }
                .tag(Tab.history)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(Color(hex: "00A651"))
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(BluetoothManager())
        .environmentObject(LocationManager())
        .environmentObject(ScooterData())
}

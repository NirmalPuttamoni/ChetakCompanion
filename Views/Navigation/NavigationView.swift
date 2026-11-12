//
//  NavigationView.swift
//  ChetakCompanion
//
//  Map-based navigation view with turn-by-turn instructions
//  and background activity indicator.
//

import SwiftUI
import MapKit

struct ChetakNavigationView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var scooterData: ScooterData

    @State private var searchText = ""
    @State private var destination: CLLocationCoordinate2D?
    @State private var destinationName: String = "Destination"
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    private let accentGreen = Color(hex: "00A651")
    private let darkBg = Color(hex: "1A1A2E")

    private var activeInstruction: NavigationInstruction? {
        locationManager.currentInstruction ?? scooterData.currentInstruction
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Map (iOS 17+ MapKit or MKMapViewRepresentable fallback)
                mapContent
                    .ignoresSafeArea(edges: .bottom)

                // Overlays
                VStack(spacing: 0) {
                    // Search bar
                    searchBar

                    // Navigation instruction card
                    if locationManager.isNavigating, let instruction = activeInstruction {
                        NavigationInstructionCard(instruction: instruction)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }

                    Spacer()

                    // Background active indicator
                    if locationManager.isNavigating {
                        backgroundActiveIndicator
                            .padding(.bottom, 8)
                    }

                    // Navigation control button
                    navigationButton
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
            }
            .background(darkBg.ignoresSafeArea())
            .navigationTitle("Navigation")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let loc = locationManager.currentLocation?.coordinate {
                    mapRegion.center = loc
                }
            }
        }
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContent: some View {
        if #available(iOS 17.0, *) {
            IOS17MapView(
                destination: destination ?? locationManager.destination,
                destinationName: destinationName,
                routeCoordinates: locationManager.currentRoute,
                accentGreen: accentGreen,
                fallbackCenter: mapRegion.center
            )
        } else {
            MKMapViewRepresentable(
                region: $mapRegion,
                destination: destination ?? locationManager.destination,
                routeCoordinates: locationManager.currentRoute,
                accentColor: UIColor(red: 0, green: 166 / 255, blue: 81 / 255, alpha: 1)
            )
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search destination...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .onSubmit {
                    searchDestination()
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    destination = nil
                    if locationManager.isNavigating {
                        stopNavigation()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Navigation Button

    private var navigationButton: some View {
        Button {
            withAnimation(.spring(response: 0.4)) {
                if locationManager.isNavigating {
                    stopNavigation()
                } else {
                    startNavigation()
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: locationManager.isNavigating ? "stop.fill" : "location.fill")
                    .font(.title3)
                Text(locationManager.isNavigating ? "Stop Navigation" : "Start Navigation")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(locationManager.isNavigating ? Color.red : accentGreen)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
                color: (locationManager.isNavigating ? Color.red : accentGreen).opacity(0.4),
                radius: 8,
                y: 4
            )
        }
        .disabled(destination == nil && !locationManager.isNavigating)
        .opacity(destination == nil && !locationManager.isNavigating ? 0.5 : 1)
    }

    // MARK: - Background Active Indicator

    private var backgroundActiveIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.caption2)
            Text("Background active — navigation continues when locked")
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .foregroundStyle(accentGreen)
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func searchDestination() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let coord = locationManager.currentLocation?.coordinate {
            request.region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        }

        Task {
            let search = MKLocalSearch(request: request)
            if let response = try? await search.start(),
               let item = response.mapItems.first {
                await MainActor.run {
                    let coord = item.placemark.coordinate
                    destination = coord
                    destinationName = item.name ?? query
                    mapRegion = MKCoordinateRegion(
                        center: coord,
                        latitudinalMeters: 5_000,
                        longitudinalMeters: 5_000
                    )
                }
            }
        }
    }

    private func startNavigation() {
        locationManager.requestPermissions()
        if let dest = destination {
            locationManager.startNavigation(to: dest)
        } else {
            locationManager.simulateNavigation()
        }

        if let instruction = locationManager.currentInstruction {
            scooterData.currentInstruction = instruction
            scooterData.isNavigating = true
            if bluetoothManager.isConnected {
                bluetoothManager.sendNavigationData(instruction)
            }
        }
    }

    private func stopNavigation() {
        locationManager.stopNavigation()
        scooterData.currentInstruction = nil
        scooterData.isNavigating = false
    }
}

// MARK: - iOS 17+ Map Wrapper

@available(iOS 17.0, *)
private struct IOS17MapView: View {
    let destination: CLLocationCoordinate2D?
    let destinationName: String
    let routeCoordinates: [CLLocationCoordinate2D]
    let accentGreen: Color
    let fallbackCenter: CLLocationCoordinate2D

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            if let dest = destination {
                Annotation(destinationName, coordinate: dest) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                }
            }

            if !routeCoordinates.isEmpty {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(accentGreen, lineWidth: 5)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onChange(of: destination?.latitude) { _, _ in
            if let dest = destination {
                cameraPosition = .region(MKCoordinateRegion(
                    center: dest,
                    latitudinalMeters: 5_000,
                    longitudinalMeters: 5_000
                ))
            }
        }
    }
}

// MARK: - UIKit MKMapView Fallback (iOS 16)

struct MKMapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let destination: CLLocationCoordinate2D?
    let routeCoordinates: [CLLocationCoordinate2D]
    let accentColor: UIColor

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.setRegion(region, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)

        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        if let dest = destination {
            let annotation = MKPointAnnotation()
            annotation.coordinate = dest
            annotation.title = "Destination"
            mapView.addAnnotation(annotation)
        }

        mapView.removeOverlays(mapView.overlays)
        if routeCoordinates.count >= 2 {
            let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
            mapView.addOverlay(polyline)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(accentColor: accentColor)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let accentColor: UIColor

        init(accentColor: UIColor) {
            self.accentColor = accentColor
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = accentColor
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview

#Preview {
    let locManager = LocationManager()
    locManager.simulateNavigation()

    return ChetakNavigationView()
        .environmentObject(locManager)
        .environmentObject(BluetoothManager())
        .environmentObject(ScooterData())
}

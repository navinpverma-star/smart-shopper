//
//  LocationService.swift
//  Smart Shopper
//
//  CoreLocation wrapper published with @Observable so SwiftUI views react
//  to permission changes and location updates without Combine.
//
//  Requires NSLocationWhenInUseUsageDescription in Info.plist.
//

import Foundation
import CoreLocation

@Observable
@MainActor
final class LocationService: NSObject {

    static let shared = LocationService()

    // MARK: - Published state

    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var currentLocation: CLLocation?
    private(set) var locationError: Error?

    // MARK: - Private

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Public interface

    /// Requests permission when undetermined; triggers a one-shot location
    /// fix once permission is granted or already held.
    func requestLocationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            #if os(macOS)
            // macOS doesn't require explicit authorization request
            manager.requestLocation()
            #else
            manager.requestWhenInUseAuthorization()
            #endif
        case .authorizedAlways:
            manager.requestLocation()
        #if !os(macOS)
        case .authorizedWhenInUse:
            manager.requestLocation()
        #endif
        default:
            break
        }
    }

    /// True when the user has explicitly denied location access.
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            self.locationError = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in
            self.locationError = error
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            #if os(macOS)
            if manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
            #else
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
            #endif
        }
    }
}

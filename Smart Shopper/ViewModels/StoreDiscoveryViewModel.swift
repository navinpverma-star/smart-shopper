//
//  StoreDiscoveryViewModel.swift
//  Smart Shopper
//
//  Loads the retailer list and optionally sorts it by proximity once
//  CoreLocation delivers a fix.  Falls back to alphabetical order
//  when location is unavailable or denied.
//

import Foundation
import CoreLocation

@Observable
@MainActor
final class StoreDiscoveryViewModel {

    // MARK: - State

    private(set) var stores: [Store] = Store.mvpRetailers
    private(set) var isLoading = false
    private(set) var locationDenied = false

    // MARK: - Dependencies

    private let locationService = LocationService.shared

    // MARK: - Load

    func loadStores() async {
        isLoading = true
        defer { isLoading = false }

        locationService.requestLocationIfNeeded()

        // Wait briefly for a location fix; show retailers regardless.
        try? await Task.sleep(for: .seconds(1.5))

        locationDenied = locationService.isDenied

        guard let userLocation = locationService.currentLocation else { return }

        // Sort retailers by distance when real coordinates are available.
        // (mvpRetailers have nil coordinates, so order stays unchanged
        //  until replaced by real Instacart retailer data in a later phase.)
        stores = Store.mvpRetailers
            .map { store -> Store in
                var s = store
                if let coord = store.coordinate {
                    let loc = CLLocation(latitude: coord.latitude,
                                        longitude: coord.longitude)
                    s.distanceMetres = userLocation.distance(from: loc)
                }
                return s
            }
            .sorted {
                ($0.distanceMetres ?? .greatestFiniteMagnitude)
                    < ($1.distanceMetres ?? .greatestFiniteMagnitude)
            }
    }
}

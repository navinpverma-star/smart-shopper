//
//  Store.swift
//  Smart Shopper
//
//  Represents a nearby grocery retailer discovered via CoreLocation
//  and matched against Instacart's supported retailer list.
//

import Foundation
import CoreLocation

struct Store: Identifiable, Hashable {

    // MARK: - Identity
    let id: UUID
    let name: String

    /// Instacart retailer slug, e.g. "walmart", "kroger", "whole-foods".
    let instacartRetailerId: String

    // MARK: - Location
    let address: String?
    let coordinate: CLLocationCoordinate2D?

    /// Distance from the user in metres (populated after location fix).
    var distanceMetres: Double?

    // MARK: - Presentation
    let logoURL: URL?
    let supportsInstacartCheckout: Bool

    // MARK: - Init
    init(
        id: UUID = UUID(),
        name: String,
        instacartRetailerId: String,
        address: String? = nil,
        coordinate: CLLocationCoordinate2D? = nil,
        logoURL: URL? = nil,
        supportsInstacartCheckout: Bool = true
    ) {
        self.id = id
        self.name = name
        self.instacartRetailerId = instacartRetailerId
        self.address = address
        self.coordinate = coordinate
        self.distanceMetres = nil
        self.logoURL = logoURL
        self.supportsInstacartCheckout = supportsInstacartCheckout
    }
}

// MARK: - CLLocationCoordinate2D Hashable conformance
// Required because Store conforms to Hashable.
extension CLLocationCoordinate2D: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }

    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - Formatted distance
extension Store {

    var formattedDistance: String? {
        guard let metres = distanceMetres else { return nil }
        let measurement = Measurement(value: metres, unit: UnitLength.meters)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: measurement)
    }
}

// MARK: - Stores
extension Store {
    /// Walmart — primary store for MVP.
    static let walmart = Store(
        name: "Walmart",
        instacartRetailerId: "walmart"
    )

    /// Full retailer list (used by StoreSelectionView if re-enabled later).
    static let mvpRetailers: [Store] = [
        .walmart,
        Store(name: "Target",           instacartRetailerId: "target"),
        Store(name: "Kroger",           instacartRetailerId: "kroger"),
        Store(name: "Whole Foods Market", instacartRetailerId: "whole-foods"),
        Store(name: "Costco",           instacartRetailerId: "costco"),
        Store(name: "Safeway",          instacartRetailerId: "safeway"),
    ]
}

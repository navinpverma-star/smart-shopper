//
//  GroceryList.swift
//  Smart Shopper
//
//  A named collection of GroceryItems assembled during an import session.
//

import Foundation

struct GroceryList: Identifiable, Codable {

    var id: UUID
    var name: String
    var createdAt: Date
    var items: [GroceryItem]

    // MARK: - Init
    init(
        id: UUID = UUID(),
        name: String = "My List",
        items: [GroceryItem] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.items = items
    }
}

// MARK: - Derived properties
extension GroceryList {

    var matchedItemCount: Int {
        items.filter(\.isMatched).count
    }

    var totalEstimatedCost: Decimal {
        items.compactMap(\.matchedProductPrice).reduce(0, +)
    }

    var isReadyForCheckout: Bool {
        !items.isEmpty && items.allSatisfy(\.isMatched)
    }
}

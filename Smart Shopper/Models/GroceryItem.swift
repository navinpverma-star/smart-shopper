//
//  GroceryItem.swift
//  Smart Shopper
//
//  A value-type model representing a single item on a grocery list.
//  Kept as a plain struct so it can live purely in-memory during the
//  import / cart-building flow.  Persist to SwiftData only when saving
//  a completed list.
//

import Foundation

struct GroceryItem: Identifiable, Codable, Hashable {

    // MARK: - Core identity
    var id: UUID
    var name: String

    // MARK: - Quantity
    var quantity: Double
    var unit: String          // e.g. "lbs", "oz", "count"

    // MARK: - Instacart match (populated by InstacartService)
    var isMatched: Bool
    var matchedProductId: String?
    var matchedProductName: String?
    var matchedProductImageURL: String?
    var matchedProductPrice: Decimal?

    // MARK: - Provenance
    var sourceType: SourceType
    var addedAt: Date

    // MARK: - Init
    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double = 1.0,
        unit: String = "",
        sourceType: SourceType = .manual
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.isMatched = false
        self.matchedProductId = nil
        self.matchedProductName = nil
        self.matchedProductImageURL = nil
        self.matchedProductPrice = nil
        self.sourceType = sourceType
        self.addedAt = Date()
    }
}

// MARK: - SourceType
extension GroceryItem {
    enum SourceType: String, Codable, CaseIterable {
        case ocr          = "Camera / OCR"
        case notes        = "Notes"
        case manual       = "Manual"
        case googleTasks  = "Google Tasks"

        var systemImage: String {
            switch self {
            case .ocr:         return "camera.fill"
            case .notes:       return "note.text"
            case .manual:      return "pencil"
            case .googleTasks: return "checkmark.circle.fill"
            }
        }
    }
}

// MARK: - Formatted helpers
extension GroceryItem {

    /// Human-readable quantity string, e.g. "2 lbs" or "1".
    var quantityLabel: String {
        let qtyStr = quantity == quantity.rounded()
            ? String(Int(quantity))
            : String(format: "%.1f", quantity)
        return unit.isEmpty ? qtyStr : "\(qtyStr) \(unit)"
    }
}

//
//  ProductServiceProtocol.swift
//  Smart Shopper
//
//  Shared abstraction for any product-search backend.
//  Current implementations:
//    • OpenFoodFactsService  — no API key, live product data (default)
//    • InstacartService      — real prices + cart creation (needs token)
//
//  Swap the active service in CartReviewViewModel.init(productService:).
//

import Foundation

// MARK: - Shared domain models

/// A product returned by any product-search backend.
struct MatchedProduct: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let price: Decimal?        // nil = price unknown (e.g. Open Food Facts)
    let imageURL: URL?
    let sizeText: String?

    /// Human-readable price, e.g. "$3.49" or "Price varies".
    var formattedPrice: String {
        guard let price else { return "Price varies" }
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        return fmt.string(from: NSDecimalNumber(decimal: price)) ?? "$\(price)"
    }
}

/// Result of a cart-creation request.
struct ProductCart {
    /// Deep-link into the retailer's app or website.
    /// `nil` when the backend doesn't support cart links (e.g. Open Food Facts).
    let cartURL: URL?
    let totalItems: Int
}

// MARK: - Protocol

/// Any async product-search + cart-creation service.
protocol ProductService: Sendable {
    /// Returns up to `limit` products matching `query` for the given retailer.
    func searchProducts(query: String,
                        retailerId: String,
                        limit: Int) async throws -> [MatchedProduct]

    /// Creates a cart from the given items and returns a link to open it.
    func createCart(items: [(productId: String, quantity: Int)],
                    retailerId: String) async throws -> ProductCart
}

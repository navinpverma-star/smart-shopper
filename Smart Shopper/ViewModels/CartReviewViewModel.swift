//
//  CartReviewViewModel.swift
//  Smart Shopper
//
//  Searches for each GroceryItem concurrently, holds the user's product
//  selections, and builds the final cart request.
//
//  Defaults to OpenFoodFactsService (no API key).
//  Swap to InstacartService.shared when a token is available.
//

import Foundation

@Observable
@MainActor
final class CartReviewViewModel {

    // MARK: - Input

    let groceryList: GroceryList
    let store: Store

    // MARK: - Search state
    //   nil  → not yet searched
    //   []   → searched, nothing found
    //   [..] → results available

    private(set) var searchResults: [UUID: [MatchedProduct]] = [:]

    // User's chosen product per grocery item.
    var selectedProducts: [UUID: MatchedProduct] = [:]

    private(set) var isSearching = false
    var errorMessage: String?

    // MARK: - Service

    private let productService: any ProductService

    init(groceryList: GroceryList,
         store: Store,
         productService: (any ProductService)? = nil) {
        self.groceryList = groceryList
        self.store       = store
        // Service priority:
        //  1. Explicitly injected service (tests / previews)
        //  2. WalmartService when store is Walmart and API key is stored
        //  3. OpenFoodFactsService — always works, no key required
        if let injected = productService {
            self.productService = injected
        } else if store.instacartRetailerId == "walmart",
                  WalmartService.shared.hasApiKey() {
            self.productService = WalmartService.shared
        } else {
            self.productService = OpenFoodFactsService.shared
        }
    }

    // MARK: - Search

    /// Launches concurrent searches for every item in the list.
    func searchAllProducts() async {
        isSearching  = true
        errorMessage = nil
        defer { isSearching = false }

        await withTaskGroup(of: Void.self) { group in
            for item in groceryList.items {
                group.addTask { [weak self] in
                    await self?.search(for: item)
                }
            }
        }
    }

    private func search(for item: GroceryItem) async {
        do {
            let results = try await productService.searchProducts(
                query:      item.name,
                retailerId: store.instacartRetailerId,
                limit:      5
            )
            searchResults[item.id] = results
            // Auto-select the first result.
            if selectedProducts[item.id] == nil, let first = results.first {
                selectedProducts[item.id] = first
            }
        } catch {
            errorMessage = error.localizedDescription
            searchResults[item.id] = []
        }
    }

    // MARK: - Cart

    var selectedItemCount: Int { selectedProducts.count }

    var estimatedTotal: Decimal {
        selectedProducts.values.compactMap(\.price).reduce(0, +)
    }

    /// True when at least one matched product has a real price.
    var hasPrices: Bool {
        selectedProducts.values.contains { $0.price != nil }
    }

    func buildCartItems() -> [(productId: String, quantity: Int)] {
        groceryList.items.compactMap { item in
            guard let product = selectedProducts[item.id] else { return nil }
            return (product.id, max(1, Int(item.quantity)))
        }
    }

    func createCart() async throws -> ProductCart {
        let items = buildCartItems()
        return try await productService.createCart(
            items:      items,
            retailerId: store.instacartRetailerId
        )
    }
}

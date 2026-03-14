//
//  WalmartService.swift
//  Smart Shopper
//
//  ProductService backed by the Walmart Open API.
//  Returns real Walmart products with prices and builds a cart deep-link.
//
//  Setup (one-time):
//    1. Get a free API key at https://developer.walmart.com
//    2. Store it once (e.g. in onboarding or Settings):
//         try? KeychainService.shared.save("YOUR_KEY",
//              forKey: KeychainService.TokenKey.walmartApiKey)
//
//  Without a key the service throws WalmartError.missingApiKey and
//  CartReviewViewModel falls back to OpenFoodFactsService automatically.
//
//  API reference: https://developer.walmart.com/doc/us/mp/us-mp-items/
//

import Foundation

actor WalmartService: ProductService {

    static let shared = WalmartService()
    private init() {}

    private let baseURL = URL(string: "https://api.walmartlabs.com/v1")!

    // MARK: - ProductService

    func searchProducts(query: String,
                        retailerId: String,  // unused — always Walmart
                        limit: Int = 5) async throws -> [MatchedProduct] {
        let apiKey = try storedApiKey()

        var components = URLComponents(
            url: baseURL.appendingPathComponent("/search"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "query",    value: query),
            URLQueryItem(name: "apiKey",   value: apiKey),
            URLQueryItem(name: "numItems", value: "\(limit)"),
            URLQueryItem(name: "format",   value: "json"),
        ]
        guard let url = components.url else { throw WalmartError.badURL }

        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad,
                                 timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw WalmartError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.items?.compactMap(\.asMatchedProduct) ?? []
    }

    /// Builds a Walmart cart deep-link URL — no server call needed.
    func createCart(items: [(productId: String, quantity: Int)],
                    retailerId: String) async throws -> ProductCart {
        let itemsParam = items
            .map { "\($0.productId):\($0.quantity)" }
            .joined(separator: ",")

        let url = URL(string: "https://www.walmart.com/cart/add?items=\(itemsParam)")
        return ProductCart(cartURL: url, totalItems: items.count)
    }

    // MARK: - Helpers

    nonisolated func hasApiKey() -> Bool {
        (try? KeychainService.shared.read(
            key: KeychainService.TokenKey.walmartApiKey
        ))?.isEmpty == false
    }

    private func storedApiKey() throws -> String {
        guard let key = try? KeychainService.shared.read(
            key: KeychainService.TokenKey.walmartApiKey
        ), !key.isEmpty else {
            throw WalmartError.missingApiKey
        }
        return key
    }
}

// MARK: - JSON models

private extension WalmartService {

    struct SearchResponse: Codable {
        let items: [Item]?
    }

    struct Item: Codable {
        let itemId: Int
        let name: String
        let salePrice: Double?
        let brandName: String?
        let thumbnailImage: String?
        let shortDescription: String?

        var asMatchedProduct: MatchedProduct? {
            guard !name.isEmpty else { return nil }
            let price = salePrice.map { Decimal($0) }
            return MatchedProduct(
                id:       "\(itemId)",
                name:     name,
                brand:    brandName,
                price:    price,
                imageURL: thumbnailImage.flatMap(URL.init),
                sizeText: nil
            )
        }
    }
}

// MARK: - Errors

extension WalmartService {
    enum WalmartError: LocalizedError {
        case missingApiKey
        case badURL
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .missingApiKey:
                return "Walmart API key not set. Get a free key at developer.walmart.com."
            case .badURL:
                return "Could not construct the Walmart search URL."
            case .httpError(let code):
                return "Walmart API error (HTTP \(code))."
            }
        }
    }
}

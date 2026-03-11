//
//  OpenFoodFactsService.swift
//  Smart Shopper
//
//  ProductService backed by the Open Food Facts API.
//  ✅  No API key required — completely free and open.
//  ⚠️  Prices not available (OFF is a nutrition database, not a price feed).
//      CheckoutView falls back to opening the retailer's website directly.
//
//  API docs: https://wiki.openfoodfacts.org/API
//

import Foundation

actor OpenFoodFactsService: ProductService {

    static let shared = OpenFoodFactsService()
    private init() {}

    private let baseURL = URL(string: "https://world.openfoodfacts.org")!

    // MARK: - ProductService

    func searchProducts(query: String,
                        retailerId: String,
                        limit: Int = 5) async throws -> [MatchedProduct] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/cgi/search.pl"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "search_terms",  value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action",        value: "process"),
            URLQueryItem(name: "json",          value: "1"),
            URLQueryItem(name: "page_size",     value: "\(limit)"),
            URLQueryItem(name: "fields",        value: "code,product_name,brands,image_front_small_url,quantity"),
        ]
        guard let url = components.url else { throw URLError(.badURL) }

        // OFF API guidelines require a descriptive User-Agent.
        var request = URLRequest(url: url,
                                 cachePolicy: .returnCacheDataElseLoad,
                                 timeoutInterval: 12)
        request.setValue("SmartCart/1.0 (iOS; grocery helper app)",
                         forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response  = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        return response.products.compactMap(\.asMatchedProduct)
    }

    /// Open Food Facts has no cart API — returns a cart with no URL.
    /// CheckoutView handles this by opening the retailer website instead.
    func createCart(items: [(productId: String, quantity: Int)],
                    retailerId: String) async throws -> ProductCart {
        ProductCart(cartURL: nil, totalItems: items.count)
    }
}

// MARK: - Private response models

private struct OFFSearchResponse: Codable {
    let products: [OFFProduct]
}

private struct OFFProduct: Codable {
    let code: String?
    let productName: String?
    let brands: String?
    let imageFrontSmallUrl: String?
    let quantity: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName        = "product_name"
        case brands
        case imageFrontSmallUrl = "image_front_small_url"
        case quantity
    }

    var asMatchedProduct: MatchedProduct? {
        guard let name = productName, !name.isEmpty else { return nil }
        // Combine product name + brand into a single display name.
        let display = [name, brands].compactMap { $0 }.joined(separator: " · ")
        return MatchedProduct(
            id:       code ?? UUID().uuidString,
            name:     display,
            brand:    brands,
            price:    nil,           // OFF has no retail price data
            imageURL: imageFrontSmallUrl.flatMap(URL.init),
            sizeText: quantity
        )
    }
}

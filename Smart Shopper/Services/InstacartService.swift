//
//  InstacartService.swift
//  Smart Shopper
//
//  ProductService backed by the Instacart Connect REST API.
//  Provides real prices and cart-creation — activate by storing your token:
//
//      try? KeychainService.shared.save("YOUR_TOKEN",
//               forKey: KeychainService.TokenKey.instacartAccessToken)
//
//  Without a token the service throws InstacartError.missingToken;
//  CartReviewViewModel falls back to OpenFoodFactsService by default.
//
//  API reference: https://docs.instacart.com/connect/
//

import Foundation

actor InstacartService: ProductService {

    static let shared = InstacartService()
    private init() {}

    // TODO: Update if your account uses a custom domain.
    private let baseURL = URL(string: "https://connect.instacart.com")!

    // MARK: - ProductService

    func searchProducts(query: String,
                        retailerId: String,
                        limit: Int = 5) async throws -> [MatchedProduct] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/idp/v1/retailers/\(retailerId)/items"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "search_query", value: query),
            URLQueryItem(name: "per_page",     value: "\(limit)"),
        ]
        guard let url = components.url else { throw InstacartError.badURL }

        let (data, response) = try await URLSession.shared.data(for: makeRequest(url: url))
        try validate(response)

        let decoded = try JSONDecoder.instacart.decode(SearchResponse.self, from: data)
        return decoded.data.items.map(\.asMatchedProduct)
    }

    func createCart(items: [(productId: String, quantity: Int)],
                    retailerId: String) async throws -> ProductCart {
        let url = baseURL.appendingPathComponent("/idp/v1/carts")
        var request = makeRequest(url: url, method: "POST")
        let body = CartRequest(
            retailerKey: retailerId,
            items: items.map { CartRequest.Item(id: $0.productId, quantity: $0.quantity) }
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)

        let decoded = try JSONDecoder.instacart.decode(CartResponse.self, from: data)
        return ProductCart(cartURL: decoded.data.cartURL, totalItems: items.count)
    }

    // MARK: - Helpers

    private var accessToken: String? {
        try? KeychainService.shared.read(key: KeychainService.TokenKey.instacartAccessToken)
    }

    private func makeRequest(url: URL, method: String = "GET") throws -> URLRequest {
        guard let token = accessToken, !token.isEmpty else {
            throw InstacartError.missingToken
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        return req
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw InstacartError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw InstacartError.httpError(http.statusCode)
        }
    }
}

// MARK: - Private JSON models

private extension InstacartService {

    struct SearchResponse: Codable {
        let data: Payload
        struct Payload: Codable { let items: [RemoteItem] }
    }

    struct RemoteItem: Codable {
        let id: String
        let name: String
        let displayPrice: String?
        let imageUrl: String?
        let size: String?

        var asMatchedProduct: MatchedProduct {
            // Strip leading "$" / currency symbols before parsing.
            let price = displayPrice.flatMap {
                Decimal(string: $0.filter { $0.isNumber || $0 == "." })
            }
            return MatchedProduct(
                id:       id,
                name:     name,
                brand:    nil,
                price:    price,
                imageURL: imageUrl.flatMap(URL.init),
                sizeText: size
            )
        }
    }

    struct CartRequest: Codable {
        let retailerKey: String
        let items: [Item]
        struct Item: Codable { let id: String; let quantity: Int }
        enum CodingKeys: String, CodingKey {
            case retailerKey = "retailer_key"; case items
        }
    }

    struct CartResponse: Codable {
        let data: Payload
        struct Payload: Codable {
            let cartURL: URL
            enum CodingKeys: String, CodingKey { case cartURL = "cart_url" }
        }
    }
}

// MARK: - Errors

extension InstacartService {
    enum InstacartError: LocalizedError {
        case missingToken
        case badURL
        case invalidResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .missingToken:
                return "Instacart API token not found. Add your token in Settings."
            case .badURL:
                return "Could not construct the request URL."
            case .invalidResponse:
                return "Received an unexpected response from Instacart."
            case .httpError(let code):
                return "Instacart API error (HTTP \(code))."
            }
        }
    }
}

private extension JSONDecoder {
    static let instacart: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}

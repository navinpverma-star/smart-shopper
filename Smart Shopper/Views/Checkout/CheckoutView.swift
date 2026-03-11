//
//  CheckoutView.swift
//  Smart Shopper
//
//  Order-review screen.  The primary action opens the selected retailer's
//  website (or Instacart cart URL when a token is configured).
//
//  Apple Pay integration is scoped to Phase 3 (requires a merchant ID and
//  payment-processing certificate from Apple).
//

import SwiftUI

struct CheckoutView: View {

    let viewModel: CartReviewViewModel

    @State private var isPlacingOrder = false
    @State private var orderError: String?
    @Environment(\.openURL) private var openURL

    // MARK: - Body

    var body: some View {
        List {
            storeSection
            itemsSection
            totalSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Review Order")
#if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .safeAreaInset(edge: .bottom) { actionBar }
        .alert("Order Error", isPresented: Binding(
            get: { orderError != nil },
            set: { if !$0 { orderError = nil } }
        )) {
            Button("OK") { orderError = nil }
        } message: {
            Text(orderError ?? "")
        }
    }

    // MARK: - List sections

    private var storeSection: some View {
        Section("Store") {
            Label(viewModel.store.name, systemImage: "storefront.fill")
                .font(.body.weight(.medium))
        }
    }

    private var itemsSection: some View {
        Section("Your Order  (\(viewModel.selectedItemCount) items)") {
            ForEach(viewModel.groceryList.items) { item in
                if let product = viewModel.selectedProducts[item.id] {
                    HStack(alignment: .top, spacing: 10) {
                        AsyncImage(url: product.imageURL) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color.secondary.opacity(0.08)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text("Qty: \(item.quantityLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(product.formattedPrice)
                            .font(.subheadline)
                            .foregroundStyle(product.price != nil ? .primary : .secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var totalSection: some View {
        Section {
            HStack {
                Text("Estimated Total")
                    .font(.body.weight(.medium))
                Spacer()
                if viewModel.hasPrices {
                    let total = NSDecimalNumber(decimal: viewModel.estimatedTotal).doubleValue
                    Text(String(format: "$%.2f", total))
                        .font(.body.weight(.semibold))
                } else {
                    Text("Price varies by store")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Apple Pay placeholder — Phase 3
            HStack {
                Image(systemName: "apple.logo")
                Text("Apple Pay")
                Spacer()
                Text("Phase 3")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                Button {
                    Task { await openInStore() }
                } label: {
                    Group {
                        if isPlacingOrder {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("Building your cart…")
                            }
                        } else {
                            Text("Open in \(viewModel.store.name)")
                                .bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isPlacingOrder)

                Text("You'll complete payment in the store's app or website.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }

    // MARK: - Action

    private func openInStore() async {
        isPlacingOrder = true
        defer { isPlacingOrder = false }

        do {
            let cart = try await viewModel.createCart()

            if let url = cart.cartURL {
                // Instacart or retailer deep-link — open directly.
                openURL(url)
            } else {
                // Open Food Facts mode: open the retailer's own search page.
                openURL(retailerSearchURL)
            }
        } catch {
            orderError = error.localizedDescription
        }
    }

    /// Builds a search URL for the selected retailer using the first few item names.
    private var retailerSearchURL: URL {
        let queries: [String: String] = [
            "walmart":     "https://www.walmart.com/search?q=",
            "target":      "https://www.target.com/s?searchTerm=",
            "kroger":      "https://www.kroger.com/search?query=",
            "whole-foods": "https://www.wholefoodsmarket.com/search?text=",
            "costco":      "https://www.costco.com/CatalogSearch?keyword=",
            "safeway":     "https://www.safeway.com/shop/search-results.html?q=",
        ]

        let query = viewModel.groceryList.items
            .prefix(3)
            .map(\.name)
            .joined(separator: " ")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let base = queries[viewModel.store.instacartRetailerId] ?? "https://www.google.com/search?q="
        return URL(string: base + query) ?? URL(string: "https://www.instacart.com")!
    }
}

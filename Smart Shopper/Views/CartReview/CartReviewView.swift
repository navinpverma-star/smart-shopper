//
//  CartReviewView.swift
//  Smart Shopper
//
//  Shows each grocery item next to its best-matched product.
//  Tap any row to swap the matched product from search alternatives.
//  Bottom bar shows an estimated total and the "Review Order" CTA.
//

import SwiftUI

struct CartReviewView: View {

    let groceryList: GroceryList
    let store: Store

    @State private var viewModel: CartReviewViewModel
    @State private var showCheckout  = false
    @State private var swappingItem: GroceryItem?

    init(groceryList: GroceryList, store: Store) {
        self.groceryList = groceryList
        self.store       = store
        _viewModel = State(wrappedValue: CartReviewViewModel(groceryList: groceryList, store: store))
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isSearching {
                searchingView
            } else {
                reviewList
            }
        }
        .navigationTitle(store.name)
#if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .safeAreaInset(edge: .bottom) {
            if !viewModel.isSearching { checkoutBar }
        }
        .navigationDestination(isPresented: $showCheckout) {
            CheckoutView(viewModel: viewModel)
        }
        .sheet(item: $swappingItem) { item in
            ProductPickerSheet(item: item, viewModel: viewModel)
        }
        .alert("Search Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Retry")  { Task { await viewModel.searchAllProducts() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task { await viewModel.searchAllProducts() }
    }

    // MARK: - Searching state

    private var searchingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Searching for \(groceryList.items.count) items…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Review list

    private var reviewList: some View {
        List(groceryList.items) { item in
            CartItemRow(
                item:        item,
                matched:     viewModel.selectedProducts[item.id],
                resultCount: viewModel.searchResults[item.id]?.count ?? 0
            ) {
                swappingItem = item
            }
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.selectedProducts.count)
    }

    // MARK: - Checkout bar

    private var checkoutBar: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 10) {
                // Total row
                HStack {
                    Text("Estimated Total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if viewModel.hasPrices {
                        let total = NSDecimalNumber(decimal: viewModel.estimatedTotal).doubleValue
                        Text(String(format: "$%.2f", total))
                            .font(.headline)
                    } else {
                        Text("Price varies by store")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // CTA button
                Button { showCheckout = true } label: {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("Review Order  (\(viewModel.selectedItemCount) items)")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.selectedProducts.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }
}

// MARK: - CartItemRow

private struct CartItemRow: View {

    let item: GroceryItem
    let matched: MatchedProduct?
    let resultCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Product thumbnail
                AsyncImage(url: matched?.imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "photo")
                        .foregroundStyle(.quaternary)
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .background(
                    Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8)
                )

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let product = matched {
                        Text(product.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(product.formattedPrice)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(product.price != nil ? .green : .secondary)

                            if let size = product.sizeText {
                                Text("· \(size)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("No match found")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Spacer()

                // Swap chevrons (shown when alternatives exist)
                if resultCount > 1 {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .tint(.primary)
    }
}

// MARK: - ProductPickerSheet

private struct ProductPickerSheet: View {

    let item: GroceryItem
    @Bindable var viewModel: CartReviewViewModel
    @Environment(\.dismiss) private var dismiss

    private var results: [MatchedProduct] {
        viewModel.searchResults[item.id] ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty {
                    ContentUnavailableView(
                        "No Products Found",
                        systemImage: "magnifyingglass",
                        description: Text("No results for "\(item.name)". Try editing the item name.")
                    )
                } else {
                    List(results) { product in
                        Button {
                            viewModel.selectedProducts[item.id] = product
                            dismiss()
                        } label: {
                            ProductAlternativeRow(
                                product:    product,
                                isSelected: viewModel.selectedProducts[item.id] == product
                            )
                        }
                        .tint(.primary)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Swap "\(item.name)"")
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - ProductAlternativeRow

private struct ProductAlternativeRow: View {

    let product: MatchedProduct
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: product.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "photo")
                    .foregroundStyle(.quaternary)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .background(Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(product.formattedPrice)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(product.price != nil ? .green : .secondary)
                    if let size = product.sizeText {
                        Text("· \(size)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }
}

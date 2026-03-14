//
//  StoreSelectionView.swift
//  Smart Shopper
//
//  Displays available retailers sorted by distance (when location is granted).
//  Tapping a store navigates to CartReviewView.
//

import SwiftUI
import CoreLocation

struct StoreSelectionView: View {

    let groceryList: GroceryList

    @State private var viewModel    = StoreDiscoveryViewModel()
    @State private var selectedStore: Store?

    var body: some View {
        List(viewModel.stores) { store in
            Button { selectedStore = store } label: {
                StoreRow(store: store)
            }
            .tint(.primary)
        }
        .listStyle(.plain)
        .navigationTitle("Choose a Store")
#if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .overlay { loadingOverlay }
        .safeAreaInset(edge: .bottom) {
            if viewModel.locationDenied { locationBanner }
        }
        .navigationDestination(item: $selectedStore) { store in
            CartReviewView(groceryList: groceryList, store: store)
        }
        .task { await viewModel.loadStores() }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Finding stores near you…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var locationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(.orange)
            Text("Enable location in Settings to sort stores by distance.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

// MARK: - StoreRow

private struct StoreRow: View {

    let store: Store

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "storefront.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(store.name)
                    .font(.body.weight(.medium))

                if let dist = store.formattedDistance {
                    Text(dist + " away")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap to shop")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StoreSelectionView(groceryList: GroceryList(items: [
            GroceryItem(name: "Whole milk"),
            GroceryItem(name: "Sourdough bread"),
        ]))
    }
}

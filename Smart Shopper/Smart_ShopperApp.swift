//
//  Smart_ShopperApp.swift
//  Smart Shopper
//
//  Created by Navin Verma on 3/9/26.
//
//  Entry point for SmartCart.
//  Uses SwiftData for persistence (requires iOS 17+).
//  Root navigation lands on ListImportView.
//

import SwiftUI
import SwiftData

@main
struct Smart_ShopperApp: App {

    // MARK: - SwiftData container
    // Add @Model types here as the app grows.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            // Future: PersistedGroceryList.self, PersistedOrder.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - Scene
    var body: some Scene {
        WindowGroup {
            ListImportView()
        }
        .modelContainer(sharedModelContainer)
    }
}

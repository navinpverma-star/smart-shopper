//
//  ListImportView.swift
//  Smart Shopper
//
//  Main screen for building a grocery list from multiple sources:
//    • Camera → OCR
//    • Photo library → OCR
//    • Clipboard (paste from Notes)
//    • Manual entry
//
//  After the list is assembled the user taps "Find Stores" to advance to
//  StoreSelectionView (Phase 2 – navigation placeholder wired here).
//

import SwiftUI
import PhotosUI

struct ListImportView: View {

    @State private var viewModel = ListImportViewModel()

    // Camera
    @State private var showingCamera     = false
    @State private var cameraImage: UIImage?

    // Photo library
    @State private var photoPickerItem: PhotosPickerItem?

    // Manual entry sheet
    @State private var showingAddItem  = false
    @State private var newItemText     = ""

    // Error banner
    @State private var showingError    = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                importSourceBar
                Divider()

                if viewModel.importedItems.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    itemList
                }

                if !viewModel.importedItems.isEmpty {
                    findStoresButton
                }
            }
            .navigationTitle("SmartCart")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { navToolbar }
            // Camera sheet
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(capturedImage: $cameraImage)
                    .ignoresSafeArea()
            }
            // Error alert
            .alert("Import Error", isPresented: $showingError) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            // Add item sheet
            .sheet(isPresented: $showingAddItem) {
                addItemSheet
            }
            // Trigger OCR when camera returns image
            .onChange(of: cameraImage) { _, image in
                guard let image else { return }
                Task {
                    await viewModel.importFromImage(image)
                    cameraImage = nil
                }
            }
            // Trigger OCR when photo is selected
            .onChange(of: photoPickerItem) { _, item in
                guard let item else { return }
                Task {
                    await viewModel.importFromPhotosPickerItem(item)
                    photoPickerItem = nil
                }
            }
            // Show error alert whenever message is set
            .onChange(of: viewModel.errorMessage) { _, msg in
                showingError = msg != nil
            }
        }
    }

    // MARK: - Import source bar

    private var importSourceBar: some View {
        HStack(spacing: 0) {
            // Camera OCR
            ImportSourceButton(
                title: "Scan",
                systemImage: "camera.fill",
                color: .blue,
                isLoading: viewModel.isLoadingOCR
            ) {
                showingCamera = true
            }

            Divider().frame(height: 44)

            // Photo library OCR
            PhotosPicker(
                selection: $photoPickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ImportSourceButtonLabel(
                    title: "Photo",
                    systemImage: "photo.on.rectangle",
                    color: .indigo,
                    isLoading: false
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            Divider().frame(height: 44)

            // Clipboard / Notes paste
            ImportSourceButton(
                title: "Paste List",
                systemImage: "doc.on.clipboard",
                color: .orange,
                isLoading: viewModel.isLoadingNotes
            ) {
                Task { await viewModel.importFromClipboard() }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Build Your List")
                .font(.title2.bold())

            Text("Scan a handwritten list, pick a photo, paste from Notes, or add items manually.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingAddItem = true
            } label: {
                Label("Add Item Manually", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: - Item list

    private var itemList: some View {
        List {
            ForEach(viewModel.importedItems) { item in
                GroceryItemRow(item: item)
            }
            .onDelete(perform: viewModel.removeItems)
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.importedItems)
    }

    // MARK: - Find Stores button

    private var findStoresButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                // TODO: Push StoreSelectionView(list: viewModel.buildGroceryList())
            } label: {
                HStack {
                    Image(systemName: "storefront.fill")
                    Text("Find Stores  (\(viewModel.importedItems.count) items)")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var navToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddItem = true
            } label: {
                Image(systemName: "plus")
            }
        }

        if !viewModel.importedItems.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                Button("Clear", role: .destructive) {
                    withAnimation { viewModel.clearAll() }
                }
            }
        }
    }

    // MARK: - Add item sheet

    private var addItemSheet: some View {
        NavigationStack {
            Form {
                Section("Item name") {
                    TextField("e.g. Whole milk, organic eggs", text: $newItemText)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { commitManualItem() }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newItemText = ""
                        showingAddItem = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { commitManualItem() }
                        .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(220)])
    }

    private func commitManualItem() {
        viewModel.addManualItem(name: newItemText)
        newItemText = ""
        showingAddItem = false
    }
}

// MARK: - GroceryItemRow

private struct GroceryItemRow: View {

    let item: GroceryItem

    var body: some View {
        HStack(spacing: 12) {
            // Source icon
            Image(systemName: item.sourceType.systemImage)
                .font(.footnote)
                .foregroundStyle(sourceColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)

                Text("\(item.quantityLabel)  ·  \(item.sourceType.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Match badge (populated in Phase 2 by InstacartService)
            if item.isMatched {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var sourceColor: Color {
        switch item.sourceType {
        case .ocr:         return .blue
        case .notes:       return .orange
        case .manual:      return .gray
        case .googleTasks: return .green
        }
    }
}

// MARK: - ImportSourceButton

private struct ImportSourceButton: View {

    let title: String
    let systemImage: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ImportSourceButtonLabel(
                title: title,
                systemImage: systemImage,
                color: color,
                isLoading: isLoading
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .disabled(isLoading)
    }
}

private struct ImportSourceButtonLabel: View {

    let title: String
    let systemImage: String
    let color: Color
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 48, height: 48)

                if isLoading {
                    ProgressView()
                        .tint(color)
                } else {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Previews

#Preview("Empty") {
    ListImportView()
}

#Preview("With items") {
    let vm = ListImportViewModel()
    vm.importedItems = [
        GroceryItem(name: "Whole milk", quantity: 1, unit: "gal", sourceType: .notes),
        GroceryItem(name: "Sourdough bread", sourceType: .ocr),
        GroceryItem(name: "Organic eggs", quantity: 12, unit: "", sourceType: .manual),
    ]
    return ListImportView()
}

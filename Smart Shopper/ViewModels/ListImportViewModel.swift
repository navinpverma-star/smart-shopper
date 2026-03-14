//
//  ListImportViewModel.swift
//  Smart Shopper
//
//  Drives ListImportView.  Coordinates OCRService and NotesImportService,
//  manages the working list of GroceryItems, and provides the list to
//  downstream screens (StoreSelectionView → CartReviewView → Checkout).
//
//  Uses @Observable (iOS 17+) – no Combine needed for the MVP.
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

@Observable
@MainActor
final class ListImportViewModel {

    // MARK: - Published state

    var importedItems: [GroceryItem] = []
    var isLoadingOCR   = false
    var isLoadingNotes = false
    var errorMessage: String?

    // MARK: - Services

    private let ocrService   = OCRService.shared
    private let notesService = NotesImportService.shared

    // MARK: - OCR import

#if canImport(UIKit)
    /// Processes a UIImage captured from the camera or photo library.
    func importFromImage(_ image: UIImage) async {
        isLoadingOCR = true
        errorMessage = nil
        defer { isLoadingOCR = false }

        do {
            let lines    = try await ocrService.recognizeText(from: image)
            let newItems = await ocrService.parseGroceryItems(from: lines)
            if newItems.isEmpty {
                errorMessage = "No list items found in the image. Try a clearer photo."
            } else {
                mergeItems(newItems)
            }
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
        }
    }

    /// Loads a PhotosPickerItem, then runs OCR on it.
    func importFromPhotosPickerItem(_ item: PhotosPickerItem) async {
        isLoadingOCR = true
        errorMessage = nil
        defer { isLoadingOCR = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Could not load the selected photo."
                return
            }
            let lines    = try await ocrService.recognizeText(from: image)
            let newItems = await ocrService.parseGroceryItems(from: lines)
            if newItems.isEmpty {
                errorMessage = "No list items detected. Try a higher-contrast photo."
            } else {
                mergeItems(newItems)
            }
        } catch {
            errorMessage = "Image processing failed: \(error.localizedDescription)"
        }
    }
#endif // canImport(UIKit)

    // MARK: - Clipboard / Notes import

    /// Reads from UIPasteboard (user should copy their Notes list first).
    func importFromClipboard() async {
        isLoadingNotes = true
        errorMessage   = nil
        defer { isLoadingNotes = false }

        let newItems = notesService.importFromClipboard()
        if newItems.isEmpty {
            errorMessage = "Clipboard is empty. Open Notes, select all, copy, then tap Paste List."
        } else {
            mergeItems(newItems)
        }
    }

    /// Parses plain text from a document picker or share extension payload.
    func importFromText(_ text: String) async {
        isLoadingNotes = true
        defer { isLoadingNotes = false }

        let newItems = notesService.importFromText(text)
        mergeItems(newItems)
    }

    // MARK: - Manual item management

    /// Adds a single item typed by the user.
    func addManualItem(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = GroceryItem(name: trimmed, sourceType: .manual)
        importedItems.append(item)
    }

    /// Removes items at the given IndexSet (used by List .onDelete).
    func removeItems(at offsets: IndexSet) {
        importedItems.remove(atOffsets: offsets)
    }

    /// Removes a specific item by identity.
    func removeItem(_ item: GroceryItem) {
        importedItems.removeAll { $0.id == item.id }
    }

    /// Wipes the whole list.
    func clearAll() {
        importedItems = []
    }

    // MARK: - Snapshot for next screen

    /// Builds a GroceryList value to pass to StoreSelectionView.
    func buildGroceryList(named name: String = "My List") -> GroceryList {
        GroceryList(name: name, items: importedItems)
    }

    // MARK: - Private helpers

    /// Appends only items whose names aren't already in the list (case-insensitive).
    private func mergeItems(_ newItems: [GroceryItem]) {
        let existing = Set(importedItems.map { $0.name.lowercased() })
        let unique   = newItems.filter { !existing.contains($0.name.lowercased()) }
        importedItems.append(contentsOf: unique)
    }
}

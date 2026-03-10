//
//  NotesImportService.swift
//  Smart Shopper
//
//  Imports grocery lists from free-form text.
//
//  IMPORTANT – iOS Notes API:
//  Apple does not expose a public framework for reading the Notes app
//  (there is no CNNoteStore). The two practical MVP approaches are:
//
//    1. Clipboard import  – user copies their note, taps "Paste List".
//    2. Share extension   – user taps Share in Notes and targets SmartCart
//                           (a separate extension target, Phase 2).
//
//  This service handles approach 1 (and any plain-text document the user
//  picks via UIDocumentPickerViewController in the VM layer).
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

actor NotesImportService {

    static let shared = NotesImportService()
    private init() {}

    // MARK: - Clipboard import

    /// Reads from UIPasteboard and parses grocery items.
    /// Returns an empty array if the clipboard has no usable text.
    func importFromClipboard() -> [GroceryItem] {
#if canImport(UIKit)
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            return []
        }
        return parse(text: text, source: .notes)
#else
        return []
#endif
    }

    // MARK: - Plain-text import (document picker / share sheet)

    /// Parses raw text from any source (share sheet, document picker, paste).
    func importFromText(_ text: String, source: GroceryItem.SourceType = .notes) -> [GroceryItem] {
        parse(text: text, source: source)
    }

    // MARK: - Core parser

    /// Splits `text` into lines and converts each non-empty line into a
    /// GroceryItem, stripping common list decorators along the way.
    private func parse(text: String, source: GroceryItem.SourceType) -> [GroceryItem] {
        text
            .components(separatedBy: .newlines)
            .compactMap { parseLine($0, source: source) }
    }

    private func parseLine(_ raw: String, source: GroceryItem.SourceType) -> GroceryItem? {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }

        // Strip bullet markers
        let bullets = ["- ", "• ", "* ", "· ", "→ ", "> ", "– "]
        for b in bullets where line.hasPrefix(b) {
            line = String(line.dropFirst(b.count))
            break
        }

        // Strip numbered list prefixes: "1. ", "2) ", "3: "
        if let match = line.firstMatch(of: /^\d+[.):\s]\s*/) {
            line = String(line[match.range.upperBound...])
        }

        // Strip checkbox markers
        let checkboxes = ["[ ] ", "[x] ", "[X] ", "☐ ", "☑ ", "✓ ", "✗ "]
        for cb in checkboxes where line.hasPrefix(cb) {
            line = String(line.dropFirst(cb.count))
            break
        }

        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.count > 1, !line.allSatisfy(\.isNumber) else { return nil }

        let (name, quantity, unit) = extractQuantity(from: line)
        return GroceryItem(name: name, quantity: quantity, unit: unit, sourceType: source)
    }

    // MARK: - Quantity extraction

    /// Detects patterns like "2 lbs butter" or "1/2 cup flour".
    private func extractQuantity(from text: String) -> (name: String, qty: Double, unit: String) {
        // Decimal/integer quantity followed by optional unit then item name
        let decimalPattern = /^(\d+(?:[.,]\d+)?)\s*([a-zA-Z]{2,5})?\s+(.+)/

        if let m = text.firstMatch(of: decimalPattern) {
            let qty = Double(String(m.1).replacingOccurrences(of: ",", with: ".")) ?? 1.0
            let unit = m.2.map(String.init) ?? ""
            return (String(m.3), qty, unit)
        }

        // Simple vulgar fraction: "1/2 cup sugar"
        let fractionPattern = /^(\d+)\/(\d+)\s*([a-zA-Z]{2,5})?\s+(.+)/
        if let m = text.firstMatch(of: fractionPattern),
           let num = Double(String(m.1)),
           let den = Double(String(m.2)), den != 0 {
            let qty = num / den
            let unit = m.3.map(String.init) ?? ""
            return (String(m.4), qty, unit)
        }

        return (text, 1.0, "")
    }
}

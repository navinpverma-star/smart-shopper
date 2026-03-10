//
//  OCRService.swift
//  Smart Shopper
//
//  Wraps Apple Vision's VNRecognizeTextRequest to extract text from images,
//  then parses the raw lines into GroceryItem values.
//
//  Usage:
//      let lines = try await OCRService.shared.recognizeText(from: image)
//      let items = OCRService.shared.parseGroceryItems(from: lines)
//
//  Requires: NSCameraUsageDescription + NSPhotoLibraryUsageDescription in Info.plist.
//

import Vision
import UIKit

actor OCRService {

    static let shared = OCRService()
    private init() {}

    // MARK: - Text Recognition

    /// Runs VNRecognizeTextRequest on `image` and returns the recognised text lines.
    /// Throws on Vision errors; returns empty array if no text is found.
    func recognizeText(from image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Hint the recognizer towards grocery-list vocabulary if available.
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Parsing

    /// Converts raw OCR text lines into GroceryItem values.
    /// Strips common list decorators and skips noise lines.
    func parseGroceryItems(from lines: [String]) -> [GroceryItem] {
        lines
            .compactMap { parseLine($0) }
    }

    // MARK: - Private parsing helpers

    private func parseLine(_ raw: String) -> GroceryItem? {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }

        // Strip leading list markers: "- ", "• ", "* ", "· ", "→ "
        let bulletPrefixes = ["- ", "• ", "* ", "· ", "→ ", "> "]
        for prefix in bulletPrefixes {
            if line.hasPrefix(prefix) {
                line = String(line.dropFirst(prefix.count))
                break
            }
        }

        // Strip numbered prefixes: "1.", "2)", "3:"  followed by whitespace
        if let match = line.firstMatch(of: /^\d+[.):\s]\s*/) {
            line = String(line[match.range.upperBound...])
        }

        // Strip checkbox markers: "[ ] ", "[x] ", "☐ ", "☑ "
        let checkboxPrefixes = ["[ ] ", "[x] ", "[X] ", "☐ ", "☑ ", "✓ ", "✗ "]
        for prefix in checkboxPrefixes {
            if line.hasPrefix(prefix) {
                line = String(line.dropFirst(prefix.count))
                break
            }
        }

        line = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip very short noise or numeric-only lines
        guard line.count > 1, !line.allSatisfy(\.isNumber) else { return nil }

        // Attempt to extract leading quantity + unit
        let (name, quantity, unit) = extractQuantity(from: line)

        return GroceryItem(name: name, quantity: quantity, unit: unit, sourceType: .ocr)
    }

    /// Tries to peel a leading quantity and optional unit off the item string.
    /// Examples: "2 lbs butter" → ("butter", 2.0, "lbs")
    ///           "milk" → ("milk", 1.0, "")
    private func extractQuantity(from text: String) -> (name: String, quantity: Double, unit: String) {
        // Pattern: optional decimal/fraction number, optional unit word, then name
        let pattern = /^(\d+(?:[.,]\d+)?)\s*([a-zA-Z]{2,4}\b)?\s+(.+)/

        if let match = text.firstMatch(of: pattern) {
            let qtyStr = String(match.1).replacingOccurrences(of: ",", with: ".")
            let quantity = Double(qtyStr) ?? 1.0
            let unit = match.2.map(String.init) ?? ""
            let name = String(match.3)
            return (name, quantity, unit)
        }

        return (text, 1.0, "")
    }
}

// MARK: - OCRError
extension OCRService {
    enum OCRError: LocalizedError {
        case invalidImage

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "The image could not be processed. Please try a clearer photo."
            }
        }
    }
}

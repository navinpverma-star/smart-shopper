//
//  CameraView.swift
//  Smart Shopper
//
//  UIViewControllerRepresentable wrapping UIImagePickerController in camera mode.
//  Falls back gracefully with an alert on simulators (no camera hardware).
//
//  Requires NSCameraUsageDescription in Info.plist.
//

import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {

    /// Receives the captured image; set to nil by the caller after processing.
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return makeCameraUnavailableController()
        }

        let picker = UIImagePickerController()
        picker.sourceType         = .camera
        picker.cameraCaptureMode  = .photo
        picker.allowsEditing      = false
        picker.delegate           = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    final class Coordinator: NSObject,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate {

        private let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.editedImage] as? UIImage
                     ?? info[.originalImage] as? UIImage
            parent.capturedImage = image
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }

    // MARK: - Simulator fallback

    private func makeCameraUnavailableController() -> UIViewController {
        let alert = UIAlertController(
            title: "Camera Unavailable",
            message: "This device does not have a camera. Use the Photo Library instead.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
            alert?.dismiss(animated: true)
        })

        // Wrap in a plain VC so the representable has something valid to return.
        let host = UIViewController()
        host.view.backgroundColor = .black
        // Present the alert after the VC is in the hierarchy.
        DispatchQueue.main.async {
            host.present(alert, animated: true)
        }
        return host
    }
}

// MARK: - Preview

#Preview {
    // Preview shows the wrapper; actual camera requires a real device.
    Color.black
        .ignoresSafeArea()
        .overlay {
            Text("Camera Preview (device only)")
                .foregroundStyle(.white)
        }
}

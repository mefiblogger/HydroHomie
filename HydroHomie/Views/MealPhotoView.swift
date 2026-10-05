// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

/// Photograph a meal and let the on-device model name what is on the plate.
///
/// Image input arrived a release after text did, so this needs iOS 27 where
/// `DescribeFoodView` needs 26 — the entry point is hidden rather than shown broken
/// on everything older.
struct MealPhotoView: View {
    var loggingOn: Date
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picking = true
    @State private var thinking = false
    @State private var failure: String?
    @State private var recognised: RecognisedMeal?

    private var status: RecogniserStatus { FoodRecogniser.status }

    var body: some View {
        NavigationStack {
            Form {
                if !FoodRecogniser.supportsPhotos {
                    Section { UnavailableNotice(status: photoStatus) }
                } else if thinking {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Working out what's on the plate…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        Button {
                            picking = true
                        } label: {
                            Label("Take another photo", systemImage: "camera.fill")
                        }
                    } footer: {
                        Text("The photo is read on your phone and is not saved or sent anywhere.")
                    }
                }

                if let failure {
                    Section {
                        Label(failure, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Take photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $recognised) { meal in
                RecognisedMealView(foods: meal.foods, loggingOn: loggingOn) {
                    onDone()
                    dismiss()
                }
            }
            .sheet(isPresented: $picking) {
                CameraPicker { image in
                    picking = false
                    guard let image else { return }
                    Task { await recognise(image) }
                }
                .ignoresSafeArea()
            }
        }
    }

    /// A capable device on iOS 26 can still describe a meal — only the camera path
    /// is out of reach, and the notice should say which.
    private var photoStatus: RecogniserStatus {
        status.isReady ? .systemTooOld : status
    }

    private func recognise(_ image: UIImage) async {
        guard #available(iOS 27.0, *), let cgImage = image.cgImage else {
            failure = RecogniserError.unavailable(.systemTooOld).errorDescription
            return
        }
        thinking = true
        failure = nil
        defer { thinking = false }

        do {
            let foods = try await FoodRecogniser.recognise(photo: cgImage)
            guard !foods.isEmpty else { throw RecogniserError.nothingRecognised }
            recognised = RecognisedMeal(foods: foods)
        } catch {
            failure = (error as? RecogniserError)?.errorDescription
                ?? RecogniserError.failed.errorDescription
        }
    }
}

/// The camera, returning a still. Deliberately camera-only: the button says take a
/// photo, and reading the photo library would need a permission this app has never
/// asked for.
private struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // No camera — the simulator, mostly. Hand back nothing rather than
            // presenting a picker that cannot produce anything.
            DispatchQueue.main.async { onCapture(nil) }
            return UIViewController()
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (UIImage?) -> Void
        init(onCapture: @escaping (UIImage?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onCapture(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}

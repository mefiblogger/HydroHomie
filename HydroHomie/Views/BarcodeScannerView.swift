// HydroHomie — a hydration tracker for iOS
// Copyright (C) 2026 mefiblogger
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import VisionKit

/// Live barcode scanning via VisionKit.
///
/// There is no camera in the Simulator, so `DataScannerViewController.isSupported` is
/// false there and the unavailable state below is what you see — the scanner itself
/// can only be exercised on a device.
struct BarcodeScannerView: View {
    var onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private var available: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            Group {
                if available {
                    DataScanner { code in
                        onScan(code)
                        dismiss()
                    }
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView(
                        "Camera unavailable",
                        systemImage: "camera.fill",
                        description: Text("Scanning needs a device with a camera, and permission to use it. Search by name instead.")
                    )
                }
            }
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// Thin wrapper over `DataScannerViewController`, restricted to the retail
/// symbologies that appear on food packaging.
private struct DataScanner: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard !context.coordinator.hasScanned else { return }
        try? controller.startScanning()
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        /// A scanner fires repeatedly while the barcode stays in frame; only the
        /// first reading should count.
        private(set) var hasScanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            handle(items, in: scanner)
        }

        private func handle(_ items: [RecognizedItem], in scanner: DataScannerViewController) {
            guard !hasScanned else { return }
            for case .barcode(let barcode) in items {
                guard let value = barcode.payloadStringValue, !value.isEmpty else { continue }
                hasScanned = true
                scanner.stopScanning()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onScan(value)
                return
            }
        }
    }
}

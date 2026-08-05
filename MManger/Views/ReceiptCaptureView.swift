import SwiftUI
import VisionKit

struct ReceiptCaptureView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showScanner = false
    @State private var isProcessing = false
    @State private var error: String?
    var onCapture: (UIImage) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 24) {
                    Text(NSLocalizedString("Capture Receipt", comment: ""))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    VStack(spacing: 16) {
                        // Document Scanner Button
                        if DocumentScannerViewController.isAvailable {
                            Button {
                                showScanner = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.viewfinder")
                                        .font(.headline.weight(.semibold))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(NSLocalizedString("Scan Receipt", comment: ""))
                                            .font(.subheadline.weight(.semibold))
                                        Text(NSLocalizedString("Use device camera to scan", comment: ""))
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.muted)
                                    }
                                    Spacer()
                                }
                                .foregroundStyle(AppTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(AppTheme.controlSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.line, lineWidth: 1)
                                )
                            }
                        }
                    }

                    if let error = error {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(AppTheme.coral)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(AppTheme.coral)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    Spacer()
                }
                .padding(20)
                .adaptiveScreenContent(maxWidth: 600)

                if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(AppTheme.violet)
                        Text(NSLocalizedString("Processing receipt…", comment: ""))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.ink)
                    }
                    .frame(maxWidth: 220)
                    .padding(20)
                    .background(AppTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.violet)
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerViewController(onCapture: handleCapture)
            }
        }
    }

    private func handleCapture(_ image: UIImage) {
        isProcessing = true
        error = nil

        Task {
            // Validate image
            if image.cgImage != nil {
                // Image is valid, pass to parent
                await MainActor.run {
                    onCapture(image)
                    isProcessing = false
                    dismiss()
                }
            } else {
                await MainActor.run {
                    error = NSLocalizedString("Invalid image", comment: "")
                    isProcessing = false
                }
            }
        }
    }
}

#Preview {
    ReceiptCaptureView { _ in }
}

// MARK: - Document Scanner Wrapper

struct DocumentScannerViewController: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    static var isAvailable: Bool {
        if #available(iOS 16.0, *) {
            return VNDocumentCameraViewController.isSupported
        }
        return false
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Use the first page of the scan
            if scan.pageCount > 0 {
                let image = scan.imageOfPage(at: 0)
                onCapture(image)
            }
            DispatchQueue.main.async {
                controller.dismiss(animated: true)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            DispatchQueue.main.async {
                controller.dismiss(animated: true)
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            DispatchQueue.main.async {
                controller.dismiss(animated: true)
            }
        }
    }
}

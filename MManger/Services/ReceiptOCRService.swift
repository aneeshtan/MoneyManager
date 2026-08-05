import Foundation
import Vision
import UIKit

enum ReceiptOCRError: LocalizedError {
    case processingFailed
    case noTextFound
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .processingFailed:
            "Could not process the receipt. Try a clearer photo."
        case .noTextFound:
            "No text found in the image. Ensure the receipt is readable."
        case .imageProcessingFailed:
            "Failed to process the image."
        }
    }
}

struct ReceiptOCRService {
    /// Extracts text from a receipt image using Vision framework.
    /// Safe to call from any thread (Vision framework is thread-safe for this operation).
    static func extractText(from image: UIImage) throws -> String {
        // Preprocess the image for better OCR accuracy
        guard let processedImage = preprocessImage(image) else {
            throw ReceiptOCRError.imageProcessingFailed
        }

        guard let cgImage = processedImage.cgImage else {
            throw ReceiptOCRError.imageProcessingFailed
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        var recognizedText = ""
        var textRecognitionError: Error?

        let textRecognitionRequest = VNRecognizeTextRequest { request, error in
            if let error = error {
                textRecognitionError = error
                return
            }

            guard let results = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            recognizedText = results
                .compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                .joined(separator: "\n")
        }

        textRecognitionRequest.recognitionLanguages = ["en"]
        textRecognitionRequest.usesLanguageCorrection = true

        do {
            try requestHandler.perform([textRecognitionRequest])
        } catch {
            throw ReceiptOCRError.processingFailed
        }

        if let error = textRecognitionError {
            throw error
        }

        guard !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReceiptOCRError.noTextFound
        }

        return recognizedText
    }

    /// Preprocesses image for better OCR accuracy:
    /// - Converts to grayscale
    /// - Enhances contrast
    /// - Applies noise reduction
    private static func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        // Create a CIImage from the CGImage
        let ciImage = CIImage(cgImage: cgImage)

        let context = CIContext()

        // Apply grayscale filter
        var processedImage = ciImage
        if let grayFilter = CIFilter(name: "CIColorControls") {
            grayFilter.setValue(ciImage, forKey: kCIInputImageKey)
            grayFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            if let output = grayFilter.outputImage {
                processedImage = output
            }
        }

        // Enhance contrast
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.5, forKey: kCIInputContrastKey)
            if let output = contrastFilter.outputImage {
                processedImage = output
            }
        }

        // Convert back to UIImage
        if let cgImage = context.createCGImage(processedImage, from: processedImage.extent) {
            return UIImage(cgImage: cgImage)
        }

        return nil
    }
}

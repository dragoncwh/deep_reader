//
//  PDFService.swift
//  DeepReader
//
//  PDF document processing service
//

import Foundation
import PDFKit
import Vision

/// Configuration constants for PDF processing
enum PDFProcessingConfig {
    static let extractionBatchSize = 50
    static let progressReportInterval = 100
    static let extractionYieldInterval = 5
    static let searchResultsPerPage = 50
}

/// Service for PDF document operations
final class PDFService {
    
    static let shared = PDFService()
    
    private init() {}
    
    // MARK: - Document Loading
    
    /// Load a PDF document from URL
    func loadDocument(from url: URL) -> PDFDocument? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return PDFDocument(url: url)
    }
    
    /// Extract metadata from a PDF
    func extractMetadata(from document: PDFDocument) -> (title: String?, author: String?) {
        let attributes = document.documentAttributes
        let title = attributes?[PDFDocumentAttribute.titleAttribute] as? String
        let author = attributes?[PDFDocumentAttribute.authorAttribute] as? String
        return (title, author)
    }
    
    // MARK: - Text Extraction

    /// Extract all text from a PDF page
    func extractText(from page: PDFPage) -> String? {
        return page.string
    }

    /// Extract text from all pages (legacy method for compatibility)
    func extractAllText(from document: PDFDocument) async -> [(page: Int, text: String)] {
        await extractAllText(from: document, batchSize: PDFProcessingConfig.extractionBatchSize, progress: nil)
    }

    /// Extract text from all pages with batching and progress callback
    /// - Parameters:
    ///   - document: The PDF document to extract text from
    ///   - batchSize: Number of pages to process before yielding (default from PDFProcessingConfig)
    ///   - progress: Optional callback reporting (currentPage, totalPages)
    func extractAllText(
        from document: PDFDocument,
        batchSize: Int = PDFProcessingConfig.extractionBatchSize,
        progress: ((Int, Int) -> Void)?
    ) async -> [(page: Int, text: String)] {
        var results: [(page: Int, text: String)] = []
        let pageCount = document.pageCount

        for i in 0..<pageCount {
            if let page = document.page(at: i),
               let text = page.string,
               !text.isEmpty {
                results.append((page: i, text: text))
            }

            // Report progress and yield every batchSize pages
            if i % batchSize == 0 || i == pageCount - 1 {
                progress?(i + 1, pageCount)
                await Task.yield()
            }
        }

        return results
    }

    /// Extract text from specified page range (on-demand extraction)
    /// - Parameters:
    ///   - document: The PDF document to extract text from
    ///   - pageRange: Range of page indices to extract
    /// - Returns: Array of tuples containing page index and extracted text
    func extractTextOnDemand(
        from document: PDFDocument,
        for pageRange: Range<Int>
    ) async -> [(page: Int, text: String)] {
        var results: [(page: Int, text: String)] = []

        for i in pageRange {
            guard i < document.pageCount else { continue }
            if let page = document.page(at: i),
               let text = page.string,
               !text.isEmpty {
                results.append((page: i, text: text))
            }

            // Yield periodically to prevent blocking
            if (i - pageRange.lowerBound) % PDFProcessingConfig.extractionYieldInterval == 0 {
                await Task.yield()
            }
        }
        return results
    }
    
    // MARK: - OCR
    
    /// Perform OCR on a PDF page image
    func performOCR(on page: PDFPage, scale: CGFloat = 2.0) async throws -> String {
        let bounds = page.bounds(for: .mediaBox)
        let size = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        
        // Render page to image
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
        
        guard let cgImage = image.cgImage else {
            throw PDFServiceError.imageRenderingFailed
        }
        
        // Perform OCR
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        guard let observations = request.results else {
            return ""
        }
        
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        
        return text
    }
    
    // MARK: - Cover Generation
    
    /// Generate a cover image from the first page
    func generateCover(from document: PDFDocument, maxSize: CGSize = CGSize(width: 400, height: 600)) -> UIImage? {
        guard let page = document.page(at: 0) else { return nil }
        
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(maxSize.width / bounds.width, maxSize.height / bounds.height)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: size))
            
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
    }
    
    /// Save cover image to file
    func saveCover(_ image: UIImage, for bookId: Int64) throws -> String {
        let coversDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Covers", isDirectory: true)
        
        try FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)
        
        let coverPath = coversDir.appendingPathComponent("\(bookId).jpg")
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw PDFServiceError.coverSaveFailed
        }
        
        try data.write(to: coverPath)
        return coverPath.path
    }
    
    // MARK: - Search
    
    /// Search for text in document
    func search(query: String, in document: PDFDocument, options: NSString.CompareOptions = .caseInsensitive) -> [PDFSelection] {
        return document.findString(query, withOptions: options)
    }
}

// MARK: - Errors
enum PDFServiceError: LocalizedError {
    case imageRenderingFailed
    case coverSaveFailed
    case ocrFailed
    
    var errorDescription: String? {
        switch self {
        case .imageRenderingFailed:
            return "Failed to render PDF page to image"
        case .coverSaveFailed:
            return "Failed to save cover image"
        case .ocrFailed:
            return "OCR processing failed"
        }
    }
}

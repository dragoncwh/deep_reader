//
//  BookService.swift
//  DeepReader
//
//  Book import and management service
//

import Foundation
import PDFKit

/// Service for managing books in the library
final class BookService {
    
    static let shared = BookService()
    
    private let database = DatabaseService.shared
    private let pdfService = PDFService.shared
    private let fileManager = FileManager.default
    
    /// Directory for storing imported PDFs
    private var booksDirectory: URL {
        StorageManager.Directory.books.url
    }

    private init() {
        // Ensure books directory exists
        do {
            try StorageManager.ensureDirectoryExists(.books)
        } catch {
            Logger.shared.error("Failed to create books directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Import
    
    /// Import a PDF from an external URL
    func importPDF(from sourceURL: URL) async throws -> Book {
        // Start security scoped access
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw BookServiceError.accessDenied
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        
        // Copy to app's documents
        let fileName = sourceURL.lastPathComponent
        let destinationURL = StorageManager.url(for: .books, fileName: UUID().uuidString + "_" + fileName)
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        // Load and analyze PDF
        guard let document = PDFDocument(url: destinationURL) else {
            do {
                try fileManager.removeItem(at: destinationURL)
            } catch {
                Logger.shared.warning("Failed to cleanup invalid PDF: \(error.localizedDescription)")
            }
            throw BookServiceError.invalidPDF
        }
        
        // Extract metadata
        let (extractedTitle, author) = pdfService.extractMetadata(from: document)
        let title = extractedTitle ?? sourceURL.deletingPathExtension().lastPathComponent
        
        // Get file size
        let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Check if PDF needs OCR (is a scanned document)
        let needsOCR = pdfService.isScannedPDF(document)
        Logger.shared.info("PDF '\(title)' needsOCR: \(needsOCR)")

        // Create book record
        var book = Book(
            id: nil,
            title: title,
            author: author,
            filePath: destinationURL.path,
            fileSize: fileSize,
            pageCount: document.pageCount,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil,
            needsOCR: needsOCR
        )
        
        // Save to database
        try database.saveBook(&book)
        
        // Generate and save cover asynchronously
        Task {
            do {
                try await generateCover(for: book, document: document)
            } catch {
                Logger.shared.warning("Failed to generate cover for '\(book.title)': \(error.localizedDescription)")
            }
        }

        // Index text content asynchronously
        Task {
            do {
                try await indexTextContent(for: book, document: document)
            } catch {
                Logger.shared.warning("Failed to index text for '\(book.title)': \(error.localizedDescription)")
            }
        }
        
        return book
    }
    
    // MARK: - Cover Generation
    
    private func generateCover(for book: Book, document: PDFDocument) async throws {
        guard let bookId = book.id,
              let image = pdfService.generateCover(from: document) else { return }
        
        let coverPath = try pdfService.saveCover(image, for: bookId)
        
        var updatedBook = book
        updatedBook.coverImagePath = coverPath
        try database.saveBook(&updatedBook)
    }
    
    // MARK: - Text Indexing

    private func indexTextContent(for book: Book, document: PDFDocument) async throws {
        guard let bookId = book.id else { return }

        Logger.shared.info("Starting text extraction for '\(book.title)' (\(document.pageCount) pages)")

        let pages = await pdfService.extractAllText(from: document, batchSize: PDFProcessingConfig.extractionBatchSize) { current, total in
            if current % PDFProcessingConfig.progressReportInterval == 0 || current == total {
                Logger.shared.debug("Text extraction progress: \(current)/\(total) pages")
            }
        }

        Logger.shared.info("Extracted text from \(pages.count) pages, indexing...")

        // Batch insert all pages in a single transaction
        try database.storeTextContent(bookId: bookId, pages: pages)

        Logger.shared.info("Text indexing completed for '\(book.title)'")
    }
    
    // MARK: - Fetch
    
    /// Fetch all books from database
    func fetchAllBooks() throws -> [Book] {
        try database.fetchBooks()
    }
    
    /// Update reading progress
    func updateProgress(for book: Book, page: Int) throws {
        guard let bookId = book.id else { return }
        try database.updateReadingProgress(bookId: bookId, page: page)
    }
    
    // MARK: - Delete
    
    /// Delete a book and its files
    func deleteBook(_ book: Book) throws {
        // Delete file
        do {
            try fileManager.removeItem(atPath: book.filePath)
        } catch {
            Logger.shared.warning("Failed to delete PDF file for '\(book.title)': \(error.localizedDescription)")
        }

        // Delete cover
        if let coverPath = book.coverImagePath {
            do {
                try fileManager.removeItem(atPath: coverPath)
            } catch {
                Logger.shared.warning("Failed to delete cover for '\(book.title)': \(error.localizedDescription)")
            }
        }

        // Delete from database
        try database.deleteBook(book)
    }
}

// MARK: - Errors
enum BookServiceError: LocalizedError {
    case accessDenied
    case invalidPDF
    case importFailed
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Cannot access the selected file"
        case .invalidPDF:
            return "The file is not a valid PDF"
        case .importFailed:
            return "Failed to import the PDF"
        }
    }
}

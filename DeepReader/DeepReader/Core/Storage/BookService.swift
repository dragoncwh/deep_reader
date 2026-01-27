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
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Books", isDirectory: true)
    }
    
    private init() {
        // Ensure books directory exists
        try? fileManager.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
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
        let destinationURL = booksDirectory.appendingPathComponent(UUID().uuidString + "_" + fileName)
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        // Load and analyze PDF
        guard let document = PDFDocument(url: destinationURL) else {
            try? fileManager.removeItem(at: destinationURL)
            throw BookServiceError.invalidPDF
        }
        
        // Extract metadata
        let (extractedTitle, author) = pdfService.extractMetadata(from: document)
        let title = extractedTitle ?? sourceURL.deletingPathExtension().lastPathComponent
        
        // Get file size
        let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
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
            coverImagePath: nil
        )
        
        // Save to database
        try database.saveBook(&book)
        
        // Generate and save cover asynchronously
        Task {
            try? await generateCover(for: book, document: document)
        }
        
        // Index text content asynchronously
        Task {
            try? await indexTextContent(for: book, document: document)
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
        
        let pages = await pdfService.extractAllText(from: document)
        
        for page in pages {
            try database.storeTextContent(
                bookId: bookId,
                pageNumber: page.page,
                text: page.text
            )
        }
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
        try? fileManager.removeItem(atPath: book.filePath)
        
        // Delete cover
        if let coverPath = book.coverImagePath {
            try? fileManager.removeItem(atPath: coverPath)
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

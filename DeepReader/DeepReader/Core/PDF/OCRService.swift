//
//  OCRService.swift
//  DeepReader
//
//  Background OCR processing service for scanned PDFs
//

import Foundation
import PDFKit
import Combine

/// Service for managing background OCR processing of scanned PDFs
@MainActor
final class OCRService: ObservableObject {

    static let shared = OCRService()

    // MARK: - Published State

    /// Set of book IDs currently being processed
    @Published var processingBookIds: Set<Int64> = []

    /// OCR progress for each book (0.0 to 1.0)
    @Published var ocrProgress: [Int64: Double] = [:]

    /// Track failed pages for potential retry (bookId -> [pageNumbers])
    @Published var failedPages: [Int64: [Int]] = [:]

    /// Track overall OCR errors for user notification (bookId -> error message)
    @Published var ocrErrors: [Int64: String] = [:]

    // MARK: - Private Properties

    /// Active OCR tasks keyed by book ID
    private var activeTasks: [Int64: Task<Void, Never>] = [:]

    /// Services
    private let database = DatabaseService.shared
    private let pdfService = PDFService.shared

    private init() {}

    // MARK: - Public API

    /// Check if a book is currently being processed
    func isProcessing(_ bookId: Int64) -> Bool {
        processingBookIds.contains(bookId)
    }

    /// Get OCR progress for a book (0.0 to 1.0, nil if not processing)
    func progress(for bookId: Int64) -> Double? {
        ocrProgress[bookId]
    }

    /// Add a book to the OCR queue and start processing
    func processBook(_ book: Book) {
        guard let bookId = book.id else {
            Logger.shared.warning("Cannot process book without ID")
            return
        }

        // Don't start if already processing
        guard !isProcessing(bookId) else {
            Logger.shared.info("Book \(bookId) is already being OCR processed")
            return
        }

        // Mark as processing
        processingBookIds.insert(bookId)

        // Start background task
        let task = Task {
            await performOCR(for: book)
        }

        activeTasks[bookId] = task
    }

    /// Cancel OCR processing for a specific book
    func cancelOCR(for bookId: Int64) {
        guard let task = activeTasks[bookId] else {
            Logger.shared.debug("No active OCR task for book \(bookId)")
            return
        }

        Logger.shared.info("Cancelling OCR for book \(bookId)")
        task.cancel()

        // Cleanup will happen in performOCR when it detects cancellation
    }

    /// Get failed pages for a book (returns nil if no failures recorded)
    func failedPages(for bookId: Int64) -> [Int]? {
        let pages = failedPages[bookId]
        return pages?.isEmpty == true ? nil : pages
    }

    /// Get error message for a book (returns nil if no error)
    func error(for bookId: Int64) -> String? {
        ocrErrors[bookId]
    }

    /// Clear error state for a book
    func clearError(for bookId: Int64) {
        failedPages.removeValue(forKey: bookId)
        ocrErrors.removeValue(forKey: bookId)
        Logger.shared.debug("Cleared OCR error state for book \(bookId)")
    }

    /// Retry failed pages for a book
    func retryFailedPages(for book: Book) {
        guard let bookId = book.id else {
            Logger.shared.warning("Cannot retry OCR for book without ID")
            return
        }

        guard let pagesToRetry = failedPages[bookId], !pagesToRetry.isEmpty else {
            Logger.shared.info("No failed pages to retry for book \(bookId)")
            return
        }

        // Don't start if already processing
        guard !isProcessing(bookId) else {
            Logger.shared.info("Book \(bookId) is already being OCR processed")
            return
        }

        // Clear previous error state
        clearError(for: bookId)

        // Mark as processing
        processingBookIds.insert(bookId)

        // Start background task for retry
        let task = Task {
            await performOCRRetry(for: book, pages: pagesToRetry)
        }

        activeTasks[bookId] = task
    }

    // MARK: - Private Implementation

    /// Perform OCR processing for a book
    private func performOCR(for book: Book) async {
        guard let bookId = book.id else { return }

        defer {
            // Always cleanup when done (success, failure, or cancellation)
            processingBookIds.remove(bookId)
            activeTasks.removeValue(forKey: bookId)
            ocrProgress.removeValue(forKey: bookId)
        }

        // Initialize progress
        ocrProgress[bookId] = 0.0

        Logger.shared.info("Starting OCR for book '\(book.title)' (ID: \(bookId))")

        // Get file URL
        let fileURL = URL(fileURLWithPath: book.filePath)

        // Handle security-scoped resource access
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        // Load PDF document
        guard let document = PDFDocument(url: fileURL) else {
            let errorMessage = "Failed to load PDF file"
            Logger.shared.error("Failed to load PDF for OCR: \(book.filePath)")
            ocrErrors[bookId] = errorMessage
            return
        }

        let pageCount = document.pageCount
        Logger.shared.info("OCR processing \(pageCount) pages for '\(book.title)'")

        // Process pages and collect text
        var extractedPages: [(page: Int, text: String)] = []
        var failedPageNumbers: [Int] = []

        for pageIndex in 0..<pageCount {
            // Check for cancellation
            if Task.isCancelled {
                Logger.shared.info("OCR cancelled for book \(bookId) at page \(pageIndex + 1)/\(pageCount)")
                return
            }

            guard let page = document.page(at: pageIndex) else {
                Logger.shared.warning("OCR failed for page \(pageIndex) in book \(bookId): Could not load page")
                failedPageNumbers.append(pageIndex)
                continue
            }

            do {
                let text = try await pdfService.performOCR(on: page)

                if !text.isEmpty {
                    extractedPages.append((page: pageIndex, text: text))
                }

            } catch {
                Logger.shared.warning("OCR failed for page \(pageIndex) in book \(bookId): \(error.localizedDescription)")
                failedPageNumbers.append(pageIndex)
                // Continue with next page instead of failing entirely
            }

            // Update progress after each page
            ocrProgress[bookId] = Double(pageIndex + 1) / Double(pageCount)

            // Log progress periodically
            if (pageIndex + 1) % 10 == 0 || pageIndex == pageCount - 1 {
                Logger.shared.debug("OCR progress: \(pageIndex + 1)/\(pageCount) pages for '\(book.title)'")
            }

            // Yield to allow other tasks to run
            await Task.yield()
        }

        // Check for cancellation before storing
        if Task.isCancelled {
            Logger.shared.info("OCR cancelled for book \(bookId) before storing results")
            return
        }

        // Log completion summary
        let successCount = extractedPages.count
        let failCount = failedPageNumbers.count
        Logger.shared.info("OCR completed for book \(bookId): \(successCount) pages succeeded, \(failCount) pages failed")

        // Store failed pages if any
        if !failedPageNumbers.isEmpty {
            failedPages[bookId] = failedPageNumbers
            ocrErrors[bookId] = "OCR failed for \(failCount) of \(pageCount) pages"
        }

        // Store extracted text
        if !extractedPages.isEmpty {
            do {
                try database.storeTextContent(bookId: bookId, pages: extractedPages)
                Logger.shared.info("Stored OCR text from \(extractedPages.count) pages for '\(book.title)'")
            } catch {
                Logger.shared.error("Failed to store OCR text for '\(book.title)': \(error.localizedDescription)")
                ocrErrors[bookId] = "Failed to save OCR results"
                return
            }
        } else {
            Logger.shared.warning("No text extracted from OCR for '\(book.title)'")
            if failedPageNumbers.count == pageCount {
                ocrErrors[bookId] = "OCR failed for all pages"
            }
        }

        // Update book to mark OCR as complete (only if we have some success or no pages to process)
        // If all pages failed, don't mark as complete so user knows OCR didn't work
        let shouldMarkComplete = !extractedPages.isEmpty || pageCount == 0
        if shouldMarkComplete {
            do {
                var updatedBook = book
                updatedBook.needsOCR = false
                try database.saveBook(&updatedBook)
                Logger.shared.info("OCR completed for '\(book.title)'")
            } catch {
                Logger.shared.error("Failed to update book after OCR: \(error.localizedDescription)")
            }
        } else {
            Logger.shared.warning("OCR did not complete successfully for '\(book.title)' - book still marked as needing OCR")
        }
    }

    /// Perform OCR retry for specific pages
    private func performOCRRetry(for book: Book, pages pagesToRetry: [Int]) async {
        guard let bookId = book.id else { return }

        defer {
            // Always cleanup when done
            processingBookIds.remove(bookId)
            activeTasks.removeValue(forKey: bookId)
            ocrProgress.removeValue(forKey: bookId)
        }

        // Initialize progress
        ocrProgress[bookId] = 0.0

        Logger.shared.info("Retrying OCR for \(pagesToRetry.count) pages in book '\(book.title)' (ID: \(bookId))")

        // Get file URL
        let fileURL = URL(fileURLWithPath: book.filePath)

        // Handle security-scoped resource access
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        // Load PDF document
        guard let document = PDFDocument(url: fileURL) else {
            let errorMessage = "Failed to load PDF file"
            Logger.shared.error("Failed to load PDF for OCR retry: \(book.filePath)")
            ocrErrors[bookId] = errorMessage
            return
        }

        // Process only the failed pages
        var extractedPages: [(page: Int, text: String)] = []
        var stillFailedPages: [Int] = []
        let totalPages = pagesToRetry.count

        for (index, pageIndex) in pagesToRetry.enumerated() {
            // Check for cancellation
            if Task.isCancelled {
                Logger.shared.info("OCR retry cancelled for book \(bookId)")
                return
            }

            guard let page = document.page(at: pageIndex) else {
                Logger.shared.warning("OCR retry failed for page \(pageIndex) in book \(bookId): Could not load page")
                stillFailedPages.append(pageIndex)
                continue
            }

            do {
                let text = try await pdfService.performOCR(on: page)

                if !text.isEmpty {
                    extractedPages.append((page: pageIndex, text: text))
                }

            } catch {
                Logger.shared.warning("OCR retry failed for page \(pageIndex) in book \(bookId): \(error.localizedDescription)")
                stillFailedPages.append(pageIndex)
            }

            // Update progress
            ocrProgress[bookId] = Double(index + 1) / Double(totalPages)

            // Yield to allow other tasks to run
            await Task.yield()
        }

        // Check for cancellation before storing
        if Task.isCancelled {
            Logger.shared.info("OCR retry cancelled for book \(bookId) before storing results")
            return
        }

        // Log completion summary
        let successCount = extractedPages.count
        let failCount = stillFailedPages.count
        Logger.shared.info("OCR retry completed for book \(bookId): \(successCount) pages succeeded, \(failCount) pages still failed")

        // Update failed pages tracking
        if stillFailedPages.isEmpty {
            failedPages.removeValue(forKey: bookId)
            ocrErrors.removeValue(forKey: bookId)
        } else {
            failedPages[bookId] = stillFailedPages
            ocrErrors[bookId] = "OCR still failed for \(failCount) pages"
        }

        // Store extracted text
        if !extractedPages.isEmpty {
            do {
                try database.storeTextContent(bookId: bookId, pages: extractedPages)
                Logger.shared.info("Stored OCR retry text from \(extractedPages.count) pages for '\(book.title)'")
            } catch {
                Logger.shared.error("Failed to store OCR retry text for '\(book.title)': \(error.localizedDescription)")
                ocrErrors[bookId] = "Failed to save OCR results"
                return
            }
        }

        // Update book to mark OCR as complete if all pages now processed
        if stillFailedPages.isEmpty {
            do {
                var updatedBook = book
                updatedBook.needsOCR = false
                try database.saveBook(&updatedBook)
                Logger.shared.info("OCR retry completed successfully for '\(book.title)'")
            } catch {
                Logger.shared.error("Failed to update book after OCR retry: \(error.localizedDescription)")
            }
        }
    }
}

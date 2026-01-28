//
//  ReaderView.swift
//  DeepReader
//
//  PDF Reader view with PDFKit integration
//

import SwiftUI
import PDFKit
import Combine

struct ReaderView: View {
    let book: Book
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ReaderViewModel
    @State private var showingSearch = false
    @State private var showingOutline = false
    @State private var showingHighlights = false
    @State private var showHighlightSuccess = false
    @State private var selectedHighlight: Highlight?

    init(book: Book) {
        self.book = book
        _viewModel = StateObject(wrappedValue: ReaderViewModel(book: book))
    }

    var body: some View {
        ZStack {
            // PDF View
            PDFKitView(
                document: viewModel.document,
                currentPage: $viewModel.currentPage,
                onSelectionChanged: nil,
                onHighlightTapped: { tapInfo in
                    handleHighlightTapped(tapInfo)
                },
                onHighlightColorSelected: { color, selection in
                    createHighlight(color: color, selection: selection)
                }
            )
            .ignoresSafeArea(edges: .bottom)

            // Overlay controls
            VStack {
                Spacer()
                pageIndicator
            }

            // Success feedback overlay
            if showHighlightSuccess {
                highlightSuccessOverlay
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingHighlights.toggle()
                } label: {
                    Image(systemName: "highlighter")
                }

                Button {
                    showingOutline.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }

                Button {
                    showingSearch.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            SearchView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingOutline) {
            OutlineView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingHighlights) {
            HighlightListView(
                viewModel: viewModel,
                onNavigateToHighlight: { highlight in
                    navigateToHighlight(highlight)
                }
            )
        }
        .sheet(item: $selectedHighlight) { highlight in
            HighlightDetailView(
                highlight: highlight,
                onDelete: {
                    Task {
                        await viewModel.deleteHighlight(highlight)
                    }
                    selectedHighlight = nil
                },
                onUpdateColor: { newColor in
                    var updated = highlight
                    updated.color = newColor
                    Task {
                        await viewModel.updateHighlight(updated)
                        // Update selectedHighlight to refresh the sheet
                        if let refreshed = viewModel.highlights.first(where: { $0.id == highlight.id }) {
                            selectedHighlight = refreshed
                        }
                    }
                },
                onUpdateNote: { newNote in
                    var updated = highlight
                    updated.note = newNote.isEmpty ? nil : newNote
                    Task {
                        await viewModel.updateHighlight(updated)
                        // Update selectedHighlight to refresh the sheet
                        if let refreshed = viewModel.highlights.first(where: { $0.id == highlight.id }) {
                            selectedHighlight = refreshed
                        }
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .task {
            await viewModel.loadDocument()
            // Navigate to initial page if set (e.g., from search results)
            if let initialPage = appState.initialPage {
                viewModel.goToPage(initialPage)
                appState.initialPage = nil
            }
        }
        .onDisappear {
            viewModel.cleanup()
            Task {
                await viewModel.saveProgress()
            }
        }
    }
    
    private var pageIndicator: some View {
        Text("Page \(viewModel.currentPage + 1) of \(viewModel.pageCount)")
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 8)
    }

    private var highlightSuccessOverlay: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)
            Text("Highlighted")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Selection & Highlight Methods

    private func handleHighlightTapped(_ tapInfo: HighlightTapInfo) {
        // Find the highlight by ID - setting selectedHighlight triggers the sheet
        if let highlight = viewModel.highlights.first(where: { $0.id == tapInfo.highlightId }) {
            selectedHighlight = highlight
        }
    }

    private func navigateToHighlight(_ highlight: Highlight) {
        // Navigate to the page containing the highlight
        viewModel.goToPage(highlight.pageNumber)
    }

    private func createHighlight(color: HighlightColor, selection: PDFTextSelection) {
        guard let bookId = book.id else { return }

        Task {
            await viewModel.createHighlight(
                bookId: bookId,
                pageIndex: selection.pageIndex,
                text: selection.text,
                bounds: selection.bounds,
                color: color
            )

            // Show success feedback
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showHighlightSuccess = true
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Auto-dismiss success overlay
            try? await Task.sleep(nanoseconds: 800_000_000)
            withAnimation(.easeOut(duration: 0.2)) {
                showHighlightSuccess = false
            }
        }
    }
}

/// Represents a text selection in the PDF
struct PDFTextSelection {
    let text: String
    let page: PDFPage
    let pageIndex: Int
    let bounds: [CGRect]
}

/// Represents a tapped highlight annotation
struct HighlightTapInfo {
    let highlightId: Int64
    let pageIndex: Int
    let tapPosition: CGPoint
}

// MARK: - Custom PDFView with highlight options in system menu
class HighlightablePDFView: PDFView {
    var onHighlightColorSelected: ((HighlightColor) -> Void)?

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Enable highlight actions when there's a selection
        if action == #selector(highlightYellow) ||
           action == #selector(highlightGreen) ||
           action == #selector(highlightBlue) ||
           action == #selector(highlightPink) ||
           action == #selector(highlightPurple) {
            return currentSelection != nil && currentSelection?.string?.isEmpty == false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)

        // Add highlight submenu
        let highlightActions = [
            UIAction(title: "Yellow", image: UIImage(systemName: "circle.fill")?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal)) { [weak self] _ in
                self?.onHighlightColorSelected?(.yellow)
            },
            UIAction(title: "Green", image: UIImage(systemName: "circle.fill")?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)) { [weak self] _ in
                self?.onHighlightColorSelected?(.green)
            },
            UIAction(title: "Blue", image: UIImage(systemName: "circle.fill")?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal)) { [weak self] _ in
                self?.onHighlightColorSelected?(.blue)
            },
            UIAction(title: "Pink", image: UIImage(systemName: "circle.fill")?.withTintColor(.systemPink, renderingMode: .alwaysOriginal)) { [weak self] _ in
                self?.onHighlightColorSelected?(.pink)
            },
            UIAction(title: "Purple", image: UIImage(systemName: "circle.fill")?.withTintColor(.systemPurple, renderingMode: .alwaysOriginal)) { [weak self] _ in
                self?.onHighlightColorSelected?(.purple)
            }
        ]

        let highlightMenu = UIMenu(title: "Highlight", image: UIImage(systemName: "highlighter"), children: highlightActions)

        // Insert highlight menu after standardEdit (Copy, etc.) - position 3
        builder.insertSibling(highlightMenu, afterMenu: .standardEdit)
    }

    @objc func highlightYellow() { onHighlightColorSelected?(.yellow) }
    @objc func highlightGreen() { onHighlightColorSelected?(.green) }
    @objc func highlightBlue() { onHighlightColorSelected?(.blue) }
    @objc func highlightPink() { onHighlightColorSelected?(.pink) }
    @objc func highlightPurple() { onHighlightColorSelected?(.purple) }
}

// MARK: - PDFKit SwiftUI Wrapper
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument?
    @Binding var currentPage: Int
    var onSelectionChanged: ((PDFTextSelection?) -> Void)?
    var onHighlightTapped: ((HighlightTapInfo) -> Void)?
    var onHighlightColorSelected: ((HighlightColor, PDFTextSelection) -> Void)?

    func makeUIView(context: Context) -> PDFView {
        let pdfView = HighlightablePDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        pdfView.backgroundColor = UIColor.systemBackground

        // Enable text selection
        pdfView.isUserInteractionEnabled = true

        // Set up highlight color selection callback
        pdfView.onHighlightColorSelected = { [weak pdfView] color in
            guard let pdfView = pdfView,
                  let selection = pdfView.currentSelection,
                  let text = selection.string,
                  !text.isEmpty,
                  let page = selection.pages.first,
                  let document = pdfView.document else { return }

            let pageIndex = document.index(for: page)

            // Get bounds for each line of the selection
            var bounds: [CGRect] = []
            if let lineSelections = selection.selectionsByLine() as? [PDFSelection] {
                for lineSelection in lineSelections {
                    let rect = lineSelection.bounds(for: page)
                    if !rect.isEmpty {
                        bounds.append(rect)
                    }
                }
            } else {
                let rect = selection.bounds(for: page)
                if !rect.isEmpty {
                    bounds.append(rect)
                }
            }

            guard !bounds.isEmpty else { return }

            let textSelection = PDFTextSelection(
                text: text,
                page: page,
                pageIndex: pageIndex,
                bounds: bounds
            )

            DispatchQueue.main.async {
                context.coordinator.parent.onHighlightColorSelected?(color, textSelection)
                // Clear selection after highlighting
                pdfView.clearSelection()
            }
        }

        // Set delegate for page change notifications
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        // Listen for selection changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )

        // Add tap gesture for highlight detection
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(tapGesture)

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document

            // Restore reading position
            if let page = document?.page(at: currentPage) {
                pdfView.go(to: page)
            }
        } else if let currentPDFPage = pdfView.currentPage,
                  let currentPDFPageIndex = pdfView.document?.index(for: currentPDFPage),
                  currentPDFPageIndex != currentPage,
                  let targetPage = pdfView.document?.page(at: currentPage) {
            // Navigate to the requested page (e.g., from outline or search)
            pdfView.go(to: targetPage)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PDFKitView

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // Only recognize tap if it's on a highlight annotation
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let pdfView = gestureRecognizer.view as? PDFView else { return false }

            let viewLocation = touch.location(in: pdfView)

            // Check if tap is on a highlight annotation
            guard let page = pdfView.page(for: viewLocation, nearest: true) else { return false }
            let pageLocation = pdfView.convert(viewLocation, to: page)

            for annotation in page.annotations {
                if annotation.type == "Highlight" && annotation.bounds.contains(pageLocation) {
                    return true // Only handle taps on highlights
                }
            }

            return false // Let other gestures (including menu dismiss) handle it
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let pageIndex = pdfView.document?.index(for: currentPage) else { return }

            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = gesture.view as? PDFView else { return }

            let viewLocation = gesture.location(in: pdfView)

            // Get the page at the tap location
            guard let page = pdfView.page(for: viewLocation, nearest: true),
                  let document = pdfView.document else { return }

            let pageIndex = document.index(for: page)
            let pageLocation = pdfView.convert(viewLocation, to: page)

            // Check if tap is on a highlight annotation
            for annotation in page.annotations {
                if annotation.type == "Highlight" && annotation.bounds.contains(pageLocation) {
                    // Get the stored highlight ID
                    if let highlightId = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: "highlightId")) as? Int64 {
                        let tapInfo = HighlightTapInfo(
                            highlightId: highlightId,
                            pageIndex: pageIndex,
                            tapPosition: viewLocation
                        )
                        DispatchQueue.main.async {
                            self.parent.onHighlightTapped?(tapInfo)
                        }
                        return
                    }
                }
            }
        }

        @objc func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }

            guard let selection = pdfView.currentSelection,
                  let text = selection.string,
                  !text.isEmpty,
                  let page = selection.pages.first,
                  let document = pdfView.document else {
                // No selection or empty selection
                DispatchQueue.main.async {
                    self.parent.onSelectionChanged?(nil)
                }
                return
            }

            let pageIndex = document.index(for: page)

            // Get bounds for each line of the selection
            var bounds: [CGRect] = []
            if let lineSelections = selection.selectionsByLine() as? [PDFSelection] {
                for lineSelection in lineSelections {
                    let rect = lineSelection.bounds(for: page)
                    if !rect.isEmpty {
                        bounds.append(rect)
                    }
                }
            } else {
                // Fallback to single bounds
                let rect = selection.bounds(for: page)
                if !rect.isEmpty {
                    bounds.append(rect)
                }
            }

            guard !bounds.isEmpty else {
                DispatchQueue.main.async {
                    self.parent.onSelectionChanged?(nil)
                }
                return
            }

            let textSelection = PDFTextSelection(
                text: text,
                page: page,
                pageIndex: pageIndex,
                bounds: bounds
            )

            DispatchQueue.main.async {
                self.parent.onSelectionChanged?(textSelection)
            }
        }
    }
}

// MARK: - Search View
struct SearchView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var displayLimit = PDFProcessingConfig.searchResultsPerPage

    private var displayedResults: [PDFSelection] {
        Array(viewModel.searchResults.prefix(displayLimit))
    }

    private var hasMoreResults: Bool {
        viewModel.searchResults.count > displayLimit
    }

    private var remainingCount: Int {
        max(0, viewModel.searchResults.count - displayLimit)
    }

    var body: some View {
        NavigationStack {
            searchContent
                .navigationTitle(searchResultTitle)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, prompt: "Search in document")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .onChange(of: searchText) { _, newValue in
                    displayLimit = PDFProcessingConfig.searchResultsPerPage
                    viewModel.search(query: newValue)
                }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if viewModel.searchResults.isEmpty && !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            searchResultsList
        }
    }

    private var searchResultsList: some View {
        List {
            ForEach(displayedResults, id: \.self) { selection in
                SearchResultRow(
                    selection: selection,
                    document: viewModel.document,
                    onTap: {
                        viewModel.goToSelection(selection)
                        dismiss()
                    }
                )
            }

            if hasMoreResults {
                loadMoreButton
            }
        }
    }

    private var loadMoreButton: some View {
        Button {
            displayLimit += PDFProcessingConfig.searchResultsPerPage
        } label: {
            HStack {
                Spacer()
                Text("Load more (\(remainingCount) remaining)")
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }
        }
    }

    private var searchResultTitle: String {
        if viewModel.searchResults.isEmpty {
            return "Search"
        } else {
            return "Search (\(viewModel.searchResults.count) results)"
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let selection: PDFSelection
    let document: PDFDocument?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading) {
                pageLabel
                Text(selection.string ?? "")
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var pageLabel: some View {
        if let page = selection.pages.first,
           let pageIndex = document?.index(for: page) {
            Text("Page \(pageIndex + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Outline View
struct OutlineView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if let outline = viewModel.document?.outlineRoot {
                    OutlineItemView(outline: outline, viewModel: viewModel) {
                        dismiss()
                    }
                } else {
                    ContentUnavailableView(
                        "No Outline",
                        systemImage: "list.bullet.indent",
                        description: Text("This document doesn't have an outline.")
                    )
                }
            }
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct OutlineItemView: View {
    let outline: PDFOutline
    let viewModel: ReaderViewModel
    let onSelect: () -> Void
    
    var body: some View {
        ForEach(0..<outline.numberOfChildren, id: \.self) { index in
            if let child = outline.child(at: index) {
                if child.numberOfChildren > 0 {
                    DisclosureGroup {
                        OutlineItemView(outline: child, viewModel: viewModel, onSelect: onSelect)
                    } label: {
                        outlineLabel(for: child)
                    }
                } else {
                    Button {
                        if let destination = child.destination {
                            viewModel.goToDestination(destination)
                            onSelect()
                        }
                    } label: {
                        outlineLabel(for: child)
                    }
                }
            }
        }
    }
    
    private func outlineLabel(for item: PDFOutline) -> some View {
        HStack {
            Text(item.label ?? "Untitled")
            Spacer()
            if let dest = item.destination,
               let page = dest.page,
               let pageIndex = viewModel.document?.index(for: page) {
                Text("\(pageIndex + 1)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - View Model
@MainActor
final class ReaderViewModel: ObservableObject {
    let book: Book

    private(set) var document: PDFDocument?
    @Published var currentPage: Int = 0
    @Published var searchResults: [PDFSelection] = []
    @Published var isLoading = false
    @Published var highlights: [Highlight] = []

    private var saveProgressCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var appliedHighlightIds: Set<Int64> = []

    var pageCount: Int {
        document?.pageCount ?? 0
    }

    /// Highlights organized by page number for efficient rendering
    var highlightsByPage: [Int: [Highlight]] {
        Dictionary(grouping: highlights, by: { $0.pageNumber })
    }

    init(book: Book) {
        self.book = book
        self.currentPage = book.lastReadPage
        setupPageChangeObserver()
    }

    private func setupPageChangeObserver() {
        saveProgressCancellable = $currentPage
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.saveProgress()
                }
            }
    }

    /// Cancel pending operations before view disappears
    func cleanup() {
        saveProgressCancellable?.cancel()
        saveProgressCancellable = nil
    }

    func loadDocument() async {
        isLoading = true
        defer { isLoading = false }

        let url = URL(fileURLWithPath: book.filePath)
        guard FileManager.default.fileExists(atPath: book.filePath) else {
            Logger.shared.error("PDF file not found: \(book.filePath)")
            return
        }

        // Try to access security-scoped resource (may return false for sandbox files)
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        document = PDFDocument(url: url)
        if document == nil {
            Logger.shared.error("Failed to load PDF document: \(book.filePath)")
        }

        // Load highlights after document is loaded
        await loadHighlights()
    }

    /// Load all highlights for the current book
    func loadHighlights() async {
        guard let bookId = book.id else { return }

        do {
            highlights = try DatabaseService.shared.fetchHighlights(bookId: bookId)
            Logger.shared.debug("Loaded \(highlights.count) highlights for book \(bookId)")

            // Apply highlights as PDF annotations
            applyHighlightAnnotations()
        } catch {
            Logger.shared.error("Failed to load highlights: \(error.localizedDescription)")
        }
    }

    /// Apply highlight annotations to the PDF document
    private func applyHighlightAnnotations() {
        guard let document = document else { return }

        // Remove existing highlight annotations first
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let annotations = page.annotations
            for annotation in annotations where annotation.type == "Highlight" {
                page.removeAnnotation(annotation)
            }
        }
        appliedHighlightIds.removeAll()

        // Add annotations for each highlight
        for highlight in highlights {
            guard let page = document.page(at: highlight.pageNumber),
                  let highlightId = highlight.id else { continue }

            // Decode bounds from stored data
            let bounds = highlight.bounds
            guard !bounds.isEmpty else {
                Logger.shared.warning("Failed to decode bounds for highlight \(highlightId)")
                continue
            }

            // Create annotation for each rect (multi-line support)
            for rect in bounds {
                let annotation = PDFAnnotation(bounds: rect, forType: .highlight, withProperties: nil)
                annotation.color = highlight.color.uiColor.withAlphaComponent(0.4)
                // Store highlight ID for later reference
                annotation.setValue(highlightId, forAnnotationKey: PDFAnnotationKey(rawValue: "highlightId"))
                page.addAnnotation(annotation)
            }
            appliedHighlightIds.insert(highlightId)
        }

        Logger.shared.debug("Applied \(highlights.count) highlight annotations")
    }

    /// Apply a single highlight as PDF annotation
    private func applyHighlightToPage(_ highlight: Highlight) {
        guard let document = document,
              let page = document.page(at: highlight.pageNumber),
              let highlightId = highlight.id else { return }

        for rect in highlight.bounds {
            let annotation = PDFAnnotation(bounds: rect, forType: .highlight, withProperties: nil)
            annotation.color = highlight.color.uiColor.withAlphaComponent(0.4)
            annotation.setValue(highlightId, forAnnotationKey: PDFAnnotationKey(rawValue: "highlightId"))
            page.addAnnotation(annotation)
        }
        appliedHighlightIds.insert(highlightId)
    }

    /// Remove annotations for a specific highlight
    private func removeAnnotationForHighlight(_ highlightId: Int64) {
        guard let document = document else { return }

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations where annotation.type == "Highlight" {
                if let annotationHighlightId = annotation.value(forAnnotationKey: PDFAnnotationKey(rawValue: "highlightId")) as? Int64,
                   annotationHighlightId == highlightId {
                    page.removeAnnotation(annotation)
                }
            }
        }
        appliedHighlightIds.remove(highlightId)
    }

    func search(query: String) {
        guard !query.isEmpty, let document = document else {
            searchResults = []
            return
        }

        searchResults = document.findString(query, withOptions: .caseInsensitive)
    }

    func goToSelection(_ selection: PDFSelection) {
        if let page = selection.pages.first,
           let pageIndex = document?.index(for: page) {
            currentPage = pageIndex
        }
    }

    func goToDestination(_ destination: PDFDestination) {
        if let page = destination.page,
           let pageIndex = document?.index(for: page) {
            currentPage = pageIndex
        }
    }

    /// Navigate to a specific page
    func goToPage(_ pageIndex: Int) {
        guard pageIndex >= 0 && pageIndex < pageCount else { return }
        currentPage = pageIndex
    }

    func saveProgress() async {
        guard book.id != nil else { return }
        do {
            try BookService.shared.updateProgress(for: book, page: currentPage)
            Logger.shared.debug("Saved reading progress: page \(currentPage + 1)")
        } catch {
            Logger.shared.error("Failed to save progress: \(error.localizedDescription)")
        }
    }

    // MARK: - Highlight Creation

    /// Create a new highlight from the current selection
    func createHighlight(
        bookId: Int64,
        pageIndex: Int,
        text: String,
        bounds: [CGRect],
        color: HighlightColor
    ) async {
        do {
            // Encode bounds to JSON data
            let boundsData = try JSONEncoder().encode(bounds)

            var highlight = Highlight(
                id: nil,
                bookId: bookId,
                pageNumber: pageIndex,
                text: text,
                note: nil,
                color: color,
                createdAt: Date(),
                boundsData: boundsData
            )

            try DatabaseService.shared.saveHighlight(&highlight)
            Logger.shared.info("Created highlight on page \(pageIndex + 1): \(text.prefix(30))...")

            // Update local array and render (instead of loadHighlights)
            highlights.append(highlight)
            applyHighlightToPage(highlight)
        } catch {
            Logger.shared.error("Failed to create highlight: \(error.localizedDescription)")
        }
    }

    // MARK: - Highlight Management

    /// Delete a highlight
    func deleteHighlight(_ highlight: Highlight) async {
        do {
            try DatabaseService.shared.deleteHighlight(highlight)
            Logger.shared.info("Deleted highlight \(highlight.id ?? 0)")

            // Update local array and remove annotation (instead of loadHighlights)
            if let highlightId = highlight.id {
                highlights.removeAll { $0.id == highlightId }
                removeAnnotationForHighlight(highlightId)
            }
        } catch {
            Logger.shared.error("Failed to delete highlight: \(error.localizedDescription)")
        }
    }

    /// Update a highlight (e.g., change color or note)
    func updateHighlight(_ highlight: Highlight) async {
        var mutableHighlight = highlight
        do {
            try DatabaseService.shared.saveHighlight(&mutableHighlight)
            Logger.shared.info("Updated highlight \(highlight.id ?? 0)")

            // Update local array and re-render affected highlight
            if let highlightId = highlight.id,
               let index = highlights.firstIndex(where: { $0.id == highlightId }) {
                highlights[index] = mutableHighlight
                // Re-apply the annotation (remove old, add new)
                removeAnnotationForHighlight(highlightId)
                applyHighlightToPage(mutableHighlight)
            }
        } catch {
            Logger.shared.error("Failed to update highlight: \(error.localizedDescription)")
        }
    }

    /// Find highlight at a given point on a page
    func highlightAtPoint(_ point: CGPoint, onPage pageIndex: Int) -> Highlight? {
        guard let pageHighlights = highlightsByPage[pageIndex] else { return nil }

        for highlight in pageHighlights {
            for rect in highlight.bounds {
                if rect.contains(point) {
                    return highlight
                }
            }
        }
        return nil
    }
}

#Preview {
    NavigationStack {
        ReaderView(book: Book(
            id: nil,
            title: "Sample Book",
            author: nil,
            filePath: "/path/to/sample.pdf",
            fileSize: 1024,
            pageCount: 100,
            addedAt: Date(),
            lastOpenedAt: nil,
            lastReadPage: 0,
            coverImagePath: nil
        ))
        .environmentObject(AppState())
    }
}

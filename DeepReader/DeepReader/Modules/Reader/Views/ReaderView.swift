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
    @StateObject private var viewModel: ReaderViewModel
    @State private var showingSearch = false
    @State private var showingOutline = false
    @State private var currentSelection: PDFTextSelection?
    @State private var showHighlightMenu = false
    @State private var highlightMenuPosition: CGPoint = .zero
    @State private var showHighlightSuccess = false

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
                onSelectionChanged: { selection in
                    handleSelectionChanged(selection)
                }
            )
            .ignoresSafeArea(edges: .bottom)
            
            // Overlay controls
            VStack {
                Spacer()
                pageIndicator
            }

            // Highlight menu overlay
            if showHighlightMenu, currentSelection != nil {
                HighlightMenuView(
                    position: highlightMenuPosition,
                    onColorSelected: { color in
                        createHighlight(color: color)
                    },
                    onDismiss: {
                        dismissHighlightMenu()
                    }
                )
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
        .task {
            await viewModel.loadDocument()
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

    private func handleSelectionChanged(_ selection: PDFTextSelection?) {
        if let selection = selection {
            currentSelection = selection
            highlightMenuPosition = selection.menuPosition
            withAnimation(.easeInOut(duration: 0.2)) {
                showHighlightMenu = true
            }
        } else {
            // Don't dismiss menu immediately when selection is cleared
            // The menu will be dismissed when a color is selected or user taps outside
        }
    }

    private func dismissHighlightMenu() {
        withAnimation(.easeInOut(duration: 0.15)) {
            showHighlightMenu = false
        }
        currentSelection = nil
    }

    private func createHighlight(color: HighlightColor) {
        guard let selection = currentSelection,
              let bookId = book.id else {
            dismissHighlightMenu()
            return
        }

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

        dismissHighlightMenu()
    }
}

/// Represents a text selection in the PDF
struct PDFTextSelection {
    let text: String
    let page: PDFPage
    let pageIndex: Int
    let bounds: [CGRect]
    let selection: PDFSelection
    let menuPosition: CGPoint
}

// MARK: - PDFKit SwiftUI Wrapper
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument?
    @Binding var currentPage: Int
    var onSelectionChanged: ((PDFTextSelection?) -> Void)?

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        pdfView.backgroundColor = UIColor.systemBackground

        // Enable text selection
        pdfView.isUserInteractionEnabled = true

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

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document

            // Restore reading position
            if let page = document?.page(at: currentPage) {
                pdfView.go(to: page)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: PDFKitView

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let pageIndex = pdfView.document?.index(for: currentPage) else { return }

            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
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

            // Calculate menu position (top center of selection, converted to view coordinates)
            let topBound = bounds.first!
            let pdfPoint = CGPoint(x: topBound.midX, y: topBound.maxY)
            let viewPoint = pdfView.convert(pdfPoint, from: page)

            let textSelection = PDFTextSelection(
                text: text,
                page: page,
                pageIndex: pageIndex,
                bounds: bounds,
                selection: selection,
                menuPosition: viewPoint
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
    @State private var displayLimit = 50

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
                    displayLimit = 50
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
            displayLimit += 50
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

    @Published var document: PDFDocument?
    @Published var currentPage: Int = 0
    @Published var searchResults: [PDFSelection] = []
    @Published var isLoading = false

    private var saveProgressCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    var pageCount: Int {
        document?.pageCount ?? 0
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

        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            document = PDFDocument(url: url)
            if document == nil {
                Logger.shared.error("Failed to load PDF document: \(book.filePath)")
            }
        }
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
        } catch {
            Logger.shared.error("Failed to create highlight: \(error.localizedDescription)")
        }
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
    }
}

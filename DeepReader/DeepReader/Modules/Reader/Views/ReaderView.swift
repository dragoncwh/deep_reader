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
    
    init(book: Book) {
        self.book = book
        _viewModel = StateObject(wrappedValue: ReaderViewModel(book: book))
    }
    
    var body: some View {
        ZStack {
            // PDF View
            PDFKitView(
                document: viewModel.document,
                currentPage: $viewModel.currentPage
            )
            .ignoresSafeArea(edges: .bottom)
            
            // Overlay controls
            VStack {
                Spacer()
                pageIndicator
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
}

// MARK: - PDFKit SwiftUI Wrapper
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument?
    @Binding var currentPage: Int
    
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
    }
}

// MARK: - Search View
struct SearchView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(viewModel.searchResults, id: \.self) { selection in
                        Button {
                            viewModel.goToSelection(selection)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                if let page = selection.pages.first,
                                   let pageIndex = viewModel.document?.index(for: page) {
                                    Text("Page \(pageIndex + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(selection.string ?? "")
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search in document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: searchText) { _, newValue in
                viewModel.search(query: newValue)
            }
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

    private weak var pdfView: PDFView?
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
        $currentPage
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.saveProgress()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadDocument() async {
        isLoading = true
        defer { isLoading = false }
        
        let url = URL(fileURLWithPath: book.filePath)
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            document = PDFDocument(url: url)
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
        guard let bookId = book.id else { return }
        do {
            try BookService.shared.updateProgress(for: book, page: currentPage)
        } catch {
            print("Failed to save progress: \(error.localizedDescription)")
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

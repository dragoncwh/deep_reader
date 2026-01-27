//
//  ContentView.swift
//  DeepReader
//
//  Main navigation container
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            LibraryView()
                .navigationDestination(for: Book.self) { book in
                    ReaderView(book: book)
                }
        }
        .fileImporter(
            isPresented: $appState.isShowingImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls {
                    await importPDF(from: url)
                }
            }
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
    
    private func importPDF(from url: URL) async {
        // TODO: Implement PDF import using BookService
        print("Importing PDF from: \(url)")
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

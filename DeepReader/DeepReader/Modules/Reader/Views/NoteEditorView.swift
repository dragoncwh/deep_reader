//
//  NoteEditorView.swift
//  DeepReader
//
//  Editor view for adding/editing notes on highlights
//

import SwiftUI

/// Full-screen note editor for highlight annotations
struct NoteEditorView: View {
    let highlight: Highlight
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Highlight preview
                highlightPreview
                    .padding(Spacing.md)
                    .background(Color(.secondarySystemBackground))

                Divider()

                // Note editor
                TextEditor(text: $noteText)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.sm)
                    .background(Color(.systemBackground))
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(noteText)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                noteText = highlight.note ?? ""
                // Delay focus to ensure view is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isFocused = true
                }
            }
        }
    }

    // MARK: - Highlight Preview

    private var highlightPreview: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Circle()
                    .fill(highlight.color.color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                    )

                Text("Page \(highlight.pageNumber + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(highlight.text)
                .font(AppTypography.body)
                .lineLimit(3)
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(highlight.color.color)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        }
    }
}

// MARK: - Preview

#Preview {
    NoteEditorView(
        highlight: Highlight(
            id: 1,
            bookId: 1,
            pageNumber: 5,
            text: "This is a sample highlighted text that demonstrates how the note editor looks.",
            note: "Existing note content here.",
            color: .yellow,
            createdAt: Date(),
            boundsData: Data()
        ),
        onSave: { note in
            print("Saved note: \(note)")
        }
    )
}

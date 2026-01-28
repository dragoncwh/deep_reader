//
//  HighlightDetailView.swift
//  DeepReader
//
//  Detail view for viewing and editing a highlight
//

import SwiftUI

/// Detail view showing highlight information with edit and delete options
struct HighlightDetailView: View {
    let highlight: Highlight
    let onDelete: () -> Void
    let onUpdateColor: (HighlightColor) -> Void
    let onUpdateNote: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isEditingNote = false
    @State private var noteText: String = ""
    @State private var showDeleteConfirmation = false
    @State private var showColorPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Highlighted text section
                    highlightedTextSection

                    Divider()

                    // Note section
                    noteSection

                    Divider()

                    // Actions section
                    actionsSection
                }
                .padding(Spacing.md)
            }
            .navigationTitle("Highlight Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                noteText = highlight.note ?? ""
            }
            .alert("Delete Highlight?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(isPresented: $isEditingNote) {
                NoteEditorSheet(
                    noteText: $noteText,
                    onSave: {
                        onUpdateNote(noteText)
                        isEditingNote = false
                    }
                )
            }
        }
    }

    // MARK: - Sections

    private var highlightedTextSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Highlighted Text")
                    .font(AppTypography.headline)

                Spacer()

                // Color indicator with picker
                Button {
                    showColorPicker.toggle()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(highlight.color.color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                        Text(highlight.color.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .popover(isPresented: $showColorPicker) {
                    colorPickerPopover
                }
            }

            Text(highlight.text)
                .font(AppTypography.body)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(highlight.color.color)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            // Page info
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text("Page \(highlight.pageNumber + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(highlight.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Note")
                    .font(AppTypography.headline)

                Spacer()

                Button {
                    isEditingNote = true
                } label: {
                    Label(highlight.note == nil ? "Add Note" : "Edit", systemImage: "pencil")
                        .font(.caption)
                }
            }

            if let note = highlight.note, !note.isEmpty {
                Text(note)
                    .font(AppTypography.body)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            } else {
                Text("No note added")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: Spacing.sm) {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Highlight", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var colorPickerPopover: some View {
        VStack(spacing: Spacing.sm) {
            Text("Change Color")
                .font(.headline)
                .padding(.top, Spacing.sm)

            HStack(spacing: Spacing.md) {
                ForEach(HighlightColor.allCases, id: \.self) { color in
                    Button {
                        onUpdateColor(color)
                        showColorPicker = false
                    } label: {
                        Circle()
                            .fill(color.uiColor.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        color == highlight.color ? Color.primary : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
        .presentationCompactAdaptation(.popover)
    }
}

// MARK: - Note Editor Sheet

private struct NoteEditorSheet: View {
    @Binding var noteText: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $noteText)
                    .focused($isFocused)
                    .padding(Spacing.sm)
                    .scrollContentBackground(.hidden)
                    .background(Color(.secondarySystemBackground))
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
                        onSave()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

// MARK: - Color Extension for UIColor opacity

private extension UIColor {
    func opacity(_ alpha: CGFloat) -> Color {
        Color(self.withAlphaComponent(alpha))
    }
}

#Preview {
    HighlightDetailView(
        highlight: Highlight(
            id: 1,
            bookId: 1,
            pageNumber: 5,
            text: "This is a sample highlighted text that demonstrates how the highlight detail view looks with some content.",
            note: "This is my note about this highlight.",
            color: .yellow,
            createdAt: Date(),
            boundsData: Data()
        ),
        onDelete: { print("Delete") },
        onUpdateColor: { print("Color: \($0)") },
        onUpdateNote: { print("Note: \($0)") }
    )
}

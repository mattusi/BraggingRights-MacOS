//
//  DocumentPreview.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPreview: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isEditing: Bool = false
    @State private var editableMarkdown: String = ""
    @State private var showMarkdownSource: Bool = false
    @State private var autoSaveTask: Task<Void, Never>?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Document Preview")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // View mode toggle
                if !viewModel.documentMarkdown.isEmpty {
                    Picker("View Mode", selection: $showMarkdownSource) {
                        Text("Rendered").tag(false)
                        Text("Markdown").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                
                // Edit button
                if !viewModel.documentMarkdown.isEmpty && showMarkdownSource {
                    Button(action: {
                        if isEditing {
                            // Save and stop editing
                            saveEdits()
                            isEditing = false
                        } else {
                            // Start editing
                            editableMarkdown = viewModel.documentMarkdown
                            isEditing = true
                        }
                    }) {
                        Label(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "pencil")
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(action: {
                    copyToClipboard()
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.markdownPreview.isEmpty)
                .help("Copy markdown to clipboard")
                
                Button(action: {
                    exportDocument()
                }) {
                    Label("Export MD", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.markdownPreview.isEmpty)
                .help("Export as markdown file")
                
                Button(action: {
                    exportPDF()
                }) {
                    Label("Export PDF", systemImage: "doc.richtext")
                }
                .disabled(viewModel.markdownPreview.isEmpty)
                .help("Export as PDF file")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            if isEditing && showMarkdownSource {
                // Editable markdown
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Changes auto-save after 500ms of inactivity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    
                    TextEditor(text: $editableMarkdown)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: editableMarkdown) { _, newValue in
                            scheduleAutoSave()
                        }
                }
            } else if showMarkdownSource {
                // View markdown source (non-editable)
                ScrollView {
                    Text(viewModel.markdownPreview)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else {
                // Rendered markdown
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        MarkdownView(markdown: viewModel.markdownPreview)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.markdownPreview, forType: .string)
    }
    
    private func scheduleAutoSave() {
        // Cancel existing auto-save task
        autoSaveTask?.cancel()
        
        // Schedule new auto-save after 500ms
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            if !Task.isCancelled {
                await MainActor.run {
                    saveEdits()
                }
            }
        }
    }
    
    private func saveEdits() {
        viewModel.documentMarkdown = editableMarkdown
    }
    
    private func exportDocument() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "brag-document.md"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? viewModel.markdownPreview.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func exportPDF() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "brag-document.pdf"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                generatePDF(at: url)
            }
        }
    }
    
    private func generatePDF(at url: URL) {
        // Convert markdown to AttributedString
        guard let attributedString = try? AttributedString(
            markdown: viewModel.markdownPreview,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) else {
            print("Failed to convert markdown to attributed string")
            return
        }
        
        // Create NSTextView for rendering
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 595, height: 842)) // A4 size in points
        textView.textStorage?.setAttributedString(NSAttributedString(attributedString))
        textView.isEditable = false
        textView.backgroundColor = .white
        textView.textContainerInset = NSSize(width: 50, height: 50) // Margins
        
        // Configure print info
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 595, height: 842) // A4
        printInfo.topMargin = 50
        printInfo.bottomMargin = 50
        printInfo.leftMargin = 50
        printInfo.rightMargin = 50
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        
        // Create print operation
        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false
        
        // Save to PDF
        printOperation.runModal(for: NSApp.mainWindow ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
        
        // Get the PDF data and save it
        let pdfData = textView.dataWithPDF(inside: textView.bounds)
        try? pdfData.write(to: url)
        
    }
}

struct MarkdownView: View {
    let markdown: String
    
    var body: some View {
        if let attributedString = try? AttributedString(markdown: markdown, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributedString)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(markdown)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    DocumentPreview(viewModel: AppViewModel())
}


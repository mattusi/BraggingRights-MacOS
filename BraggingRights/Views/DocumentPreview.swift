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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Document Preview")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    copyToClipboard()
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.markdownPreview.isEmpty)
                
                Button(action: {
                    exportDocument()
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.markdownPreview.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Markdown Content
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
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.markdownPreview, forType: .string)
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


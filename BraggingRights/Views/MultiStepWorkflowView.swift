//
//  MultiStepWorkflowView.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import SwiftUI

enum WorkflowStep: Int, CaseIterable {
    case importMessages = 0
    case manageLibrary = 1
    case generateDocument = 2
    
    var title: String {
        switch self {
        case .importMessages:
            return "Import Messages"
        case .manageLibrary:
            return "Message Library"
        case .generateDocument:
            return "Generate Document"
        }
    }
    
    var icon: String {
        switch self {
        case .importMessages:
            return "square.and.arrow.down"
        case .manageLibrary:
            return "books.vertical"
        case .generateDocument:
            return "doc.text.magnifyingglass"
        }
    }
}

struct MultiStepWorkflowView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var currentStep: WorkflowStep = .importMessages
    
    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            stepIndicator
                .frame(maxHeight: 50)
            
            Divider()
            
            // Content for current step
            TabView(selection: $currentStep) {
                ImportMessagesView(viewModel: viewModel, onComplete: {
                    currentStep = .manageLibrary
                })
                .tag(WorkflowStep.importMessages)
                
                MessageLibraryView(viewModel: viewModel)
                    .tag(WorkflowStep.manageLibrary)
                
                GenerateDocumentView(viewModel: viewModel)
                    .tag(WorkflowStep.generateDocument)
            }
            .tabViewStyle(.automatic)
        }
    }
    
    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(WorkflowStep.allCases, id: \.rawValue) { step in
                Button(action: {
                    currentStep = step
                }) {
                    HStack {
                        Image(systemName: step.icon)
                        Text(step.title)
                            .fontWeight(currentStep == step ? .semibold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(currentStep == step ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundColor(currentStep == step ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                
                if step != WorkflowStep.allCases.last {
                    Divider()
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct ImportMessagesView: View {
    @ObservedObject var viewModel: AppViewModel
    let onComplete: () -> Void
    @State private var isLLMOptionsExpanded = false
    
    var body: some View {
        HSplitView {
            // Left side - paste and import
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Sync status
                    if let syncInfo = viewModel.lastSyncInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Sync Status")
                                    .font(.headline)
                            }
                            
                            Text(syncInfo)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Next page to import: **\(viewModel.nextPageNumber)**")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Getting Started")
                                    .font(.headline)
                            }
                            
                            Text("Start by pasting Page 1 of your Slack messages below")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to Import Messages")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Search for your messages in Slack", systemImage: "1.circle.fill")
                            Label("Sort by oldest to newest", systemImage: "2.circle.fill")
                            Label("Copy one page at a time", systemImage: "3.circle.fill")
                            Label("Paste below and click Parse", systemImage: "4.circle.fill")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Text Editor for pasting
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste Slack Messages (Page \(viewModel.nextPageNumber))")
                            .font(.headline)
                        
                        TextEditor(text: $viewModel.pastedText)
                            .frame(height: 300)
                            .font(.system(.body, design: .monospaced))
                            .border(Color.gray.opacity(0.3))
                            .overlay(
                                Group {
                                    if viewModel.pastedText.isEmpty {
                                        Text("Paste your Slack messages here...")
                                            .foregroundColor(.secondary)
                                            .padding(8)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                    
                    Divider()
                    
                    // API Configuration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Configuration")
                            .font(.headline)
                        
                        SecureField("API Key", text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: viewModel.apiKey) { _, newValue in
                                viewModel.updateAPIKey(newValue)
                            }
                        
                        if !viewModel.availableModels.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(viewModel.availableModels.count) large context models available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("Enter your API key to enable document generation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            viewModel.parseMessages()
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 4)
                                }
                                Text(viewModel.isLoading ? "Parsing..." : "Parse & Save Messages")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.pastedText.isEmpty || viewModel.isLoading)
                        
                        Button(action: {
                            viewModel.clearCurrentPaste()
                        }) {
                            Text("Clear Paste Area")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.pastedText.isEmpty)
                    }
                    
                    // Error Message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Success status
                    if !viewModel.parsedMessages.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(viewModel.parsedMessages.count) messages parsed and saved!")
                                .font(.caption)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        
                        Button(action: onComplete) {
                            Label("View Message Library", systemImage: "arrow.right")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .frame(minWidth: 400, maxWidth: 500)
            
            // Right side - sync history
            SyncHistoryView(viewModel: viewModel)
        }
    }
}

struct GenerateDocumentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isLLMOptionsExpanded = true
    
    var body: some View {
        HSplitView {
            // Left side - LLM options
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Statistics
                    if let stats = viewModel.statistics {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Data Summary")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                    Text("\(stats.totalMessages) messages")
                                }
                                HStack {
                                    Image(systemName: "calendar")
                                    Text(stats.dateRangeDescription)
                                }
                                HStack {
                                    Image(systemName: "number")
                                    Text("\(stats.totalSessions) import sessions")
                                }
                                HStack {
                                    Image(systemName: "person.2")
                                    Text("\(stats.uniqueAuthors) authors")
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // LLM Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LLM Configuration")
                            .font(.headline)
                        
                        // Model Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Model (128k+ context only)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if !viewModel.availableModels.isEmpty {
                                Picker("Model", selection: Binding(
                                    get: { viewModel.llmOptions.modelName ?? "gpt-4-turbo" },
                                    set: { viewModel.llmOptions.modelName = $0 }
                                )) {
                                    ForEach(viewModel.getAvailableModelsWithContext(), id: \.modelId) { model in
                                        Text("\(model.modelId) (\(model.contextWindow))").tag(model.modelId)
                                    }
                                }
                                .pickerStyle(.menu)
                            } else {
                                Text("Configure API key to load models")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        
                        // Temperature
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Temperature: \(viewModel.llmOptions.temperature, specifier: "%.1f")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Slider(value: $viewModel.llmOptions.temperature, in: 0...1, step: 0.1)
                        }
                        
                        // Max Tokens
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Max Tokens")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("Max Tokens", value: $viewModel.llmOptions.maxTokens, format: .number)
                                .textFieldStyle(.roundedBorder)
                            Text("Recommended: 16000-32000 for large documents")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Prompt Template
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prompt Template")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $viewModel.llmOptions.promptTemplate)
                                .frame(height: 200)
                                .font(.system(.body, design: .monospaced))
                                .border(Color.gray.opacity(0.3))
                        }
                    }
                    
                    Divider()
                    
                    // Generate Button
                    Button(action: {
                        viewModel.generateDocument()
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Text(viewModel.isLoading ? "Generating..." : "Generate Brag Document")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.allMessages.isEmpty || viewModel.apiKey.isEmpty || viewModel.isLoading)
                    
                    // Error Message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .frame(minWidth: 400, maxWidth: 500)
            
            // Right side - document preview
            DocumentPreview(viewModel: viewModel)
        }
    }
}

#Preview {
    MultiStepWorkflowView(viewModel: AppViewModel())
}


//
//  OptionsPanel.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import SwiftUI

struct OptionsPanel: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isLLMOptionsExpanded = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Paste Slack Messages")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Instructions
                Text("Copy messages from Slack and paste them below:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Text Editor for pasting
                VStack(alignment: .leading, spacing: 8) {
                    Text("Slack Messages")
                        .font(.headline)
                    
                    TextEditor(text: $viewModel.pastedText)
                        .frame(minHeight: 300)
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
                    
                    Text("Expected format: Author name, channel, date/time, and message")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                            Text("\(viewModel.availableModels.count) models available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Enter your Fuelix API key to enable document generation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // LLM Options (Expandable)
                DisclosureGroup("LLM Options", isExpanded: $isLLMOptionsExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Model Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Model")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if !viewModel.availableModels.isEmpty {
                                Picker("Model", selection: Binding(
                                    get: { viewModel.llmOptions.modelName ?? "gpt-4" },
                                    set: { viewModel.llmOptions.modelName = $0 }
                                )) {
                                    ForEach(viewModel.availableModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                            } else {
                                Picker("Model", selection: $viewModel.llmOptions.model) {
                                    ForEach(LLMOptions.LLMModel.allCases) { model in
                                        Text(model.rawValue).tag(model)
                                    }
                                }
                                .pickerStyle(.menu)
                                .disabled(true)
                                
                                Text("Configure API key to load models")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                        }
                        
                        // Prompt Template
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prompt Template")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextEditor(text: $viewModel.llmOptions.promptTemplate)
                                .frame(height: 120)
                                .font(.system(.body, design: .monospaced))
                                .border(Color.gray.opacity(0.3))
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.headline)
                
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
                            Text(viewModel.isLoading ? "Parsing..." : "Parse Messages")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.pastedText.isEmpty || viewModel.isLoading)
                    
                    Button(action: {
                        viewModel.generateDocument()
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Text(viewModel.isLoading ? "Generating..." : "Generate Document")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.parsedMessages.isEmpty || viewModel.apiKey.isEmpty || viewModel.isLoading)
                    
                    Button(action: {
                        viewModel.clearData()
                    }) {
                        Text("Clear All")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.pastedText.isEmpty && viewModel.parsedMessages.isEmpty)
                }
                
                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Status
                if !viewModel.parsedMessages.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(viewModel.parsedMessages.count) messages parsed")
                            .font(.caption)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .frame(minWidth: 300, maxWidth: 400)
    }
}

#Preview {
    OptionsPanel(viewModel: AppViewModel())
}


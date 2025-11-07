//
//  AppViewModel.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AppViewModel: ObservableObject {
    @Published var pastedText: String = ""
    @Published var llmOptions = LLMOptions()
    @Published var parsedMessages: [SlackMessage] = []
    @Published var documentMarkdown: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var apiKey: String = ""
    @Published var availableModels: [String] = []
    
    private var apiService: APIService?
    private let keychainService = KeychainService.shared
    
    init() {
        // Load API key from keychain on initialization
        loadAPIKeyFromKeychain()
    }
    
    // Computed property for markdown preview
    var markdownPreview: String {
        if documentMarkdown.isEmpty && parsedMessages.isEmpty {
            return """
            # Brag Document
            
            No data yet. Paste your Slack messages in the left panel to get started.
            """
        } else if documentMarkdown.isEmpty && !parsedMessages.isEmpty {
            return generatePlaceholderDocument()
        }
        return documentMarkdown
    }
    
    // Generate a placeholder document from parsed messages
    private func generatePlaceholderDocument() -> String {
        var markdown = "# Brag Document\n\n"
        markdown += "## Parsed Messages (\(parsedMessages.count))\n\n"
        markdown += "_This is a placeholder. In the future, an LLM will process these messages into a proper brag document._\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        for message in parsedMessages.sorted(by: { $0.timestamp > $1.timestamp }) {
            markdown += "### \(message.author) in \(message.channel)\n"
            markdown += "_\(dateFormatter.string(from: message.timestamp))_\n\n"
            markdown += "\(message.text)\n\n"
            markdown += "---\n\n"
        }
        
        return markdown
    }
    
    // Parse pasted messages
    func parseMessages() {
        isLoading = true
        errorMessage = nil
        
        // Parse in background to avoid blocking UI
        Task {
            let messages = SlackMessageParser.parse(pastedText)
            
            await MainActor.run {
                if messages.isEmpty {
                    errorMessage = "No messages could be parsed. Please check the format."
                } else {
                    parsedMessages = messages
                    documentMarkdown = "" // Reset to regenerate
                }
                isLoading = false
            }
        }
    }
    
    // Clear all data
    func clearData() {
        parsedMessages = []
        documentMarkdown = ""
        pastedText = ""
        errorMessage = nil
    }
    
    // Load API key from keychain
    private func loadAPIKeyFromKeychain() {
        do {
            let key = try keychainService.getAPIKey()
            apiKey = key
            if !key.isEmpty {
                apiService = APIService(apiKey: key)
                // Optionally fetch available models
                Task {
                    await fetchModels()
                }
            }
        } catch KeychainError.itemNotFound {
            // No API key stored yet, this is normal on first launch
            apiKey = ""
        } catch {
            // Log error but don't block initialization
            print("Error loading API key from keychain: \(error.localizedDescription)")
            apiKey = ""
        }
    }
    
    // Update API key and save to keychain
    func updateAPIKey(_ key: String) {
        apiKey = key
        
        // Save to keychain
        do {
            if !key.isEmpty {
                try keychainService.updateAPIKey(key)
                apiService = APIService(apiKey: key)
                // Optionally fetch available models
                Task {
                    await fetchModels()
                }
            } else {
                try keychainService.deleteAPIKey()
                apiService = nil
                availableModels = []
            }
        } catch {
            errorMessage = "Failed to save API key: \(error.localizedDescription)"
        }
    }
    
    // Fetch available models
    func fetchModels() async {
        guard let service = apiService else { return }
        
        do {
            let models = try await service.listModels()
            await MainActor.run {
                availableModels = models.map { $0.id }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch models: \(error.localizedDescription)"
            }
        }
    }
    
    // Generate brag document using LLM
    func generateDocument() {
        guard !parsedMessages.isEmpty else {
            errorMessage = "No messages to process. Please parse messages first."
            return
        }
        
        guard let service = apiService else {
            errorMessage = "Please configure your API key first."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let document = try await service.generateBragDocument(
                    from: parsedMessages,
                    promptTemplate: llmOptions.promptTemplate,
                    modelName: llmOptions.modelName
                )
                
                await MainActor.run {
                    documentMarkdown = document
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate document: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}


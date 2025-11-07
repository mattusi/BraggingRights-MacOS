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
    @Published var parsedMessages: [SlackMessage] = [] // Messages from current paste
    @Published var allMessages: [SlackMessage] = [] // All accumulated messages
    @Published var syncSessions: [SyncSession] = []
    @Published var documentMarkdown: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var apiKey: String = ""
    @Published var availableModels: [String] = []
    @Published var statistics: DataStatistics?
    
    private var apiService: APIService?
    private let keychainService = KeychainService.shared
    private let persistenceManager = PersistenceManager.shared
    
    init() {
        // Load API key from keychain on initialization
        loadAPIKeyFromKeychain()
        // Load persisted data
        loadPersistedData()
    }
    
    // Computed property for markdown preview
    var markdownPreview: String {
        if documentMarkdown.isEmpty && allMessages.isEmpty {
            return """
            # Brag Document
            
            No data yet. Import your Slack messages to get started.
            """
        } else if documentMarkdown.isEmpty && !allMessages.isEmpty {
            return generatePlaceholderDocument()
        }
        return documentMarkdown
    }
    
    var nextPageNumber: Int {
        if let lastSession = syncSessions.max(by: { $0.pageNumber < $1.pageNumber }) {
            return lastSession.pageNumber + 1
        }
        return 1
    }
    
    var lastSyncInfo: String? {
        guard let lastSession = syncSessions.max(by: { $0.importedAt < $1.importedAt }) else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return "Last synced: Page \(lastSession.pageNumber) on \(formatter.string(from: lastSession.importedAt)), \(lastSession.messageCount) messages from \(lastSession.dateRangeDescription)"
    }
    
    // Generate a placeholder document from all messages
    private func generatePlaceholderDocument() -> String {
        var markdown = "# Brag Document\n\n"
        markdown += "## All Messages (\(allMessages.count))\n\n"
        
        if let stats = statistics {
            markdown += "**Statistics:**\n\n"
            markdown += "- Total Messages: \(stats.totalMessages)\n"
            markdown += "- Date Range: \(stats.dateRangeDescription)\n"
            markdown += "- Unique Channels: \(stats.uniqueChannels)\n"
            markdown += "- Unique Authors: \(stats.uniqueAuthors)\n"
            markdown += "- Import Sessions: \(stats.totalSessions)\n\n"
        }
        
        markdown += "_Click 'Generate Document' to process these messages into a professional brag document using AI._\n\n"
        
        return markdown
    }
    
    // Parse pasted messages and add to library
    func parseMessages() {
        isLoading = true
        errorMessage = nil
        
        // Parse in background to avoid blocking UI
        Task {
            var messages = SlackMessageParser.parse(pastedText)
            
            await MainActor.run {
                if messages.isEmpty {
                    errorMessage = "No messages could be parsed. Please check the format."
                    isLoading = false
                } else {
                    // Create a new session
                    let sessionId = UUID().uuidString
                    let pageNumber = nextPageNumber
                    
                    // Calculate date range
                    let sortedByDate = messages.sorted { $0.timestamp < $1.timestamp }
                    let dateRangeStart = sortedByDate.first?.timestamp
                    let dateRangeEnd = sortedByDate.last?.timestamp
                    
                    let session = SyncSession(
                        id: sessionId,
                        pageNumber: pageNumber,
                        importedAt: Date(),
                        messageCount: messages.count,
                        dateRangeStart: dateRangeStart,
                        dateRangeEnd: dateRangeEnd
                    )
                    
                    // Assign session ID to messages
                    for index in messages.indices {
                        messages[index].sessionId = sessionId
                    }
                    
                    // Check for duplicates
                    let newMessages = messages.filter { newMsg in
                        !allMessages.contains { existingMsg in
                            existingMsg.text == newMsg.text &&
                            existingMsg.timestamp == newMsg.timestamp &&
                            existingMsg.author == newMsg.author
                        }
                    }
                    
                    if newMessages.count < messages.count {
                        let duplicateCount = messages.count - newMessages.count
                        errorMessage = "Skipped \(duplicateCount) duplicate message(s)"
                    }
                    
                    parsedMessages = newMessages
                    allMessages.append(contentsOf: newMessages)
                    syncSessions.append(session)
                    
                    // Save to persistence
                    saveData()
                    
                    // Update statistics
                    updateStatistics()
                    
                    documentMarkdown = "" // Reset to regenerate
                    pastedText = "" // Clear text field after successful parse
                    isLoading = false
                }
            }
        }
    }
    
    // Clear all data
    func clearAllData() {
        parsedMessages = []
        allMessages = []
        syncSessions = []
        documentMarkdown = ""
        pastedText = ""
        errorMessage = nil
        statistics = nil
        
        // Clear from persistence
        do {
            try persistenceManager.clearAllData()
        } catch {
            errorMessage = "Failed to clear data: \(error.localizedDescription)"
        }
    }
    
    // Clear only current paste
    func clearCurrentPaste() {
        pastedText = ""
        parsedMessages = []
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
    
    // Fetch available models (filtered to large context window models only)
    func fetchModels() async {
        guard let service = apiService else { return }
        
        do {
            let models = try await service.listModels()
            await MainActor.run {
                // Filter to only show models with 128k+ context window
                let largeContextModels = models
                    .map { $0.id }
                    //.filter { ModelInfo.hasLargeContext(modelId: $0, minimumTokens: 128000) }
                
                // If no large context models found, show all models (API might have new ones)
                if largeContextModels.isEmpty {
                    availableModels = models.map { $0.id }
                } else {
                    availableModels = largeContextModels
                }
                
                // Auto-select first model if none selected
                if llmOptions.modelName == nil && !availableModels.isEmpty {
                    llmOptions.modelName = availableModels.first
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch models: \(error.localizedDescription)"
            }
        }
    }
    
    // Get available models with their context window info
    func getAvailableModelsWithContext() -> [(modelId: String, contextWindow: String)] {
        return availableModels.compactMap { modelId in
            guard let contextSize = ModelInfo.contextWindow(for: modelId) else {
                return (modelId, "Unknown")
            }
            let formatted = ModelInfo.formatContextWindow(contextSize)
            return (modelId, formatted)
        }
    }
    
    // Generate brag document using LLM
    func generateDocument() {
        guard !allMessages.isEmpty else {
            errorMessage = "No messages to process. Please import messages first."
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
                    from: allMessages,
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
    
    // MARK: - Persistence Methods
    
    private func loadPersistedData() {
        do {
            let appData = try persistenceManager.loadData()
            allMessages = appData.messages
            syncSessions = appData.sessions
            updateStatistics()
        } catch {
            // No saved data or error loading - start fresh
            print("No persisted data found or error loading: \(error)")
        }
    }
    
    private func saveData() {
        do {
            try persistenceManager.saveMessages(allMessages, sessions: syncSessions)
        } catch {
            errorMessage = "Failed to save data: \(error.localizedDescription)"
        }
    }
    
    private func updateStatistics() {
        do {
            statistics = try persistenceManager.getStatistics()
        } catch {
            print("Failed to update statistics: \(error)")
        }
    }
    
    // MARK: - Message Management
    
    func deleteMessage(_ messageId: String) {
        allMessages.removeAll { $0.id == messageId }
        parsedMessages.removeAll { $0.id == messageId }
        
        // Update session message counts
        updateSessionCounts()
        
        saveData()
        updateStatistics()
    }
    
    func deleteMessages(_ messageIds: [String]) {
        allMessages.removeAll { messageIds.contains($0.id) }
        parsedMessages.removeAll { messageIds.contains($0.id) }
        
        // Update session message counts
        updateSessionCounts()
        
        saveData()
        updateStatistics()
    }
    
    func deleteSession(_ sessionId: String) {
        // Remove all messages from this session
        allMessages.removeAll { $0.sessionId == sessionId }
        parsedMessages.removeAll { $0.sessionId == sessionId }
        
        // Remove the session
        syncSessions.removeAll { $0.id == sessionId }
        
        saveData()
        updateStatistics()
    }
    
    private func updateSessionCounts() {
        // Update message counts for each session
        for index in syncSessions.indices {
            let sessionId = syncSessions[index].id
            let messageCount = allMessages.filter { $0.sessionId == sessionId }.count
            
            // Create updated session with new count
            syncSessions[index] = SyncSession(
                id: syncSessions[index].id,
                pageNumber: syncSessions[index].pageNumber,
                importedAt: syncSessions[index].importedAt,
                messageCount: messageCount,
                dateRangeStart: syncSessions[index].dateRangeStart,
                dateRangeEnd: syncSessions[index].dateRangeEnd
            )
        }
        
        // Remove sessions with zero messages
        syncSessions.removeAll { session in
            allMessages.filter { $0.sessionId == session.id }.isEmpty
        }
    }
    
    // MARK: - Export/Import
    
    func exportData(to url: URL) {
        do {
            try persistenceManager.exportToURL(url)
        } catch {
            errorMessage = "Failed to export data: \(error.localizedDescription)"
        }
    }
    
    func importData(from url: URL) {
        do {
            let appData = try persistenceManager.importFromURL(url)
            allMessages = appData.messages
            syncSessions = appData.sessions
            updateStatistics()
        } catch {
            errorMessage = "Failed to import data: \(error.localizedDescription)"
        }
    }
}


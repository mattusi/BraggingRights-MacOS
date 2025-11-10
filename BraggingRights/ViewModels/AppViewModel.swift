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
    
    // Summarization properties
    @Published var messageSummaries: [MessageSummary] = []
    @Published var selectedTimePeriod: TimePeriod = .week
    @Published var useSummariesForGeneration: Bool = false
    @Published var isSummarizing: Bool = false
    @Published var summariesGenerated: Int = 0
    @Published var totalSummariesToGenerate: Int = 0
    
    private var apiService: APIService?
    private let keychainService = KeychainService.shared
    private let persistenceManager = PersistenceManager.shared
    private var summaryGenerationTask: Task<Void, Never>?
    
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
                let document: String
                
                if useSummariesForGeneration && !messageSummaries.isEmpty {
                    // Use summaries instead of full messages
                    document = try await service.generateBragDocumentFromSummaries(
                        summaries: messageSummaries,
                        promptTemplate: llmOptions.promptTemplate,
                        modelName: llmOptions.modelName
                    )
                } else {
                    // Use full messages
                    document = try await service.generateBragDocument(
                        from: allMessages,
                        promptTemplate: llmOptions.promptTemplate,
                        modelName: llmOptions.modelName
                    )
                }
                
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
            messageSummaries = appData.summaries
            updateStatistics()
        } catch {
            // No saved data or error loading - start fresh
            print("No persisted data found or error loading: \(error)")
        }
    }
    
    private func saveData() {
        do {
            try persistenceManager.saveMessages(allMessages, sessions: syncSessions, summaries: messageSummaries)
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
    
    // MARK: - Message Summarization
    
    func getMessageGroupCount(for timePeriod: TimePeriod) -> Int? {
        guard !allMessages.isEmpty else { return nil }
        let groups = groupMessagesByTimePeriod(timePeriod)
        return groups.count
    }
    
    private func groupMessagesByTimePeriod(_ timePeriod: TimePeriod) -> [[SlackMessage]] {
        let sortedMessages = allMessages.sorted { $0.timestamp < $1.timestamp }
        var groups: [[SlackMessage]] = []
        var currentGroup: [SlackMessage] = []
        var currentPeriodStart: Date?
        
        let calendar = Calendar.current
        
        for message in sortedMessages {
            if let periodStart = currentPeriodStart {
                let shouldStartNewGroup: Bool
                
                switch timePeriod {
                case .day:
                    shouldStartNewGroup = !calendar.isDate(message.timestamp, inSameDayAs: periodStart)
                case .week:
                    let periodWeek = calendar.component(.weekOfYear, from: periodStart)
                    let messageWeek = calendar.component(.weekOfYear, from: message.timestamp)
                    let periodYear = calendar.component(.year, from: periodStart)
                    let messageYear = calendar.component(.year, from: message.timestamp)
                    shouldStartNewGroup = (periodWeek != messageWeek) || (periodYear != messageYear)
                case .month:
                    let periodMonth = calendar.component(.month, from: periodStart)
                    let messageMonth = calendar.component(.month, from: message.timestamp)
                    let periodYear = calendar.component(.year, from: periodStart)
                    let messageYear = calendar.component(.year, from: message.timestamp)
                    shouldStartNewGroup = (periodMonth != messageMonth) || (periodYear != messageYear)
                }
                
                if shouldStartNewGroup {
                    if !currentGroup.isEmpty {
                        groups.append(currentGroup)
                    }
                    currentGroup = [message]
                    currentPeriodStart = message.timestamp
                } else {
                    currentGroup.append(message)
                }
            } else {
                currentGroup = [message]
                currentPeriodStart = message.timestamp
            }
        }
        
        // Add the last group
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    func generateAllSummaries() {
        guard let service = apiService else {
            errorMessage = "Please configure your API key first."
            return
        }
        
        guard !allMessages.isEmpty else {
            errorMessage = "No messages to summarize. Please import messages first."
            return
        }
        
        // Cancel any existing summarization task
        summaryGenerationTask?.cancel()
        
        isSummarizing = true
        errorMessage = nil
        summariesGenerated = 0
        
        let groups = groupMessagesByTimePeriod(selectedTimePeriod)
        totalSummariesToGenerate = groups.count
        
        // Clear existing summaries for this time period
        messageSummaries.removeAll { $0.timePeriod == selectedTimePeriod }
        
        summaryGenerationTask = Task {
            // Process summaries with max 3 concurrent requests
            await withTaskGroup(of: (Int, MessageSummary?).self) { group in
                var activeTaskCount = 0
                let maxConcurrentTasks = 3
                
                for (index, messages) in groups.enumerated() {
                    // Wait if we have too many active tasks
                    while activeTaskCount >= maxConcurrentTasks {
                        if let (_, result) = await group.next() {
                            activeTaskCount -= 1
                            if let summary = result {
                                await MainActor.run {
                                    messageSummaries.append(summary)
                                    summariesGenerated += 1
                                    saveData()
                                }
                            }
                        }
                    }
                    
                    // Check if task was cancelled
                    if Task.isCancelled {
                        break
                    }
                    
                    activeTaskCount += 1
                    group.addTask {
                        do {
                            let summary = try await service.generateSummary(
                                messages: messages,
                                timePeriod: self.selectedTimePeriod,
                                modelName: self.llmOptions.modelName
                            )
                            return (index, summary)
                        } catch {
                            print("Failed to generate summary for group \(index): \(error)")
                            return (index, nil)
                        }
                    }
                }
                
                // Collect remaining results
                for await (_, result) in group {
                    if let summary = result {
                        await MainActor.run {
                            messageSummaries.append(summary)
                            summariesGenerated += 1
                            saveData()
                        }
                    }
                }
            }
            
            await MainActor.run {
                isSummarizing = false
                let successCount = messageSummaries.filter({ $0.timePeriod == selectedTimePeriod }).count
                if successCount == 0 {
                    errorMessage = "Failed to generate summaries. Please verify your API key is valid and you have access to the selected model (\(llmOptions.modelName ?? "default"))."
                } else if successCount < totalSummariesToGenerate {
                    errorMessage = "Generated \(successCount) of \(totalSummariesToGenerate) summaries. Some failed - check API key and model access."
                }
            }
        }
    }
    
    func refreshSummary(summaryId: String) {
        guard let service = apiService else {
            errorMessage = "Please configure your API key first."
            return
        }
        
        guard let summaryIndex = messageSummaries.firstIndex(where: { $0.id == summaryId }) else {
            return
        }
        
        let summary = messageSummaries[summaryIndex]
        let messages = allMessages.filter { summary.messageIds.contains($0.id) }
        
        guard !messages.isEmpty else {
            errorMessage = "No messages found for this summary."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let updatedSummary = try await service.generateSummary(
                    messages: messages,
                    timePeriod: summary.timePeriod,
                    existingSummaryId: summary.id,
                    modelName: llmOptions.modelName
                )
                
                await MainActor.run {
                    messageSummaries[summaryIndex] = updatedSummary
                    saveData()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to refresh summary: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func deleteSummary(summaryId: String) {
        messageSummaries.removeAll { $0.id == summaryId }
        saveData()
    }
    
    func clearAllSummaries() {
        messageSummaries.removeAll()
        saveData()
    }
    
    // MARK: - Export/Import
    
    func exportData(to url: URL) {
        errorMessage = nil
        do {
            try persistenceManager.exportToURL(url)
            // Success feedback - could be displayed in the UI
            print("Successfully exported data to \(url.lastPathComponent)")
        } catch {
            errorMessage = "Failed to export data: \(error.localizedDescription)"
        }
    }
    
    func importData(from url: URL) {
        errorMessage = nil
        isLoading = true
        
        do {
            let appData = try persistenceManager.importFromURL(url)
            allMessages = appData.messages
            syncSessions = appData.sessions
            messageSummaries = appData.summaries
            updateStatistics()
            isLoading = false
            
            // Success feedback
            print("Successfully imported \(appData.messages.count) messages, \(appData.sessions.count) sessions, and \(appData.summaries.count) summaries")
        } catch {
            errorMessage = "Failed to import data: \(error.localizedDescription)"
            isLoading = false
        }
    }
}


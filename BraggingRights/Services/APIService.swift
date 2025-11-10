//
//  APIService.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized. Please check your API key"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionRequest: Codable {
    let messages: [ChatMessage]
    let model: String
}

struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [ChatCompletionChoice]
}

struct ChatCompletionChoice: Codable {
    let index: Int
    let message: ChatMessage
}

struct ModelResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let ownedBy: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case ownedBy = "owned_by"
    }
}

struct ModelListResponse: Codable {
    let object: String
    let data: [ModelResponse]
}

class APIService {
    private let baseURL = "https://api.fuelix.ai"
    private var apiKey: String
    private let chatCompletionSession: URLSession
    
    init(apiKey: String) {
        self.apiKey = apiKey
        
        // Configure URLSession with 5-minute timeout for chat completions
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 minutes
        configuration.timeoutIntervalForResource = 300 // 5 minutes
        self.chatCompletionSession = URLSession(configuration: configuration)
    }
    
    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }
    
    // MARK: - Chat Completions
    
    func createChatCompletion(messages: [ChatMessage], model: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ChatCompletionRequest(messages: messages, model: model)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        do {
            let (data, response) = try await chatCompletionSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let completionResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                guard let firstChoice = completionResponse.choices.first else {
                    throw APIError.invalidResponse
                }
                return firstChoice.message.content
                
            case 401:
                throw APIError.unauthorized
                
            case 400, 500:
                if let errorString = String(data: data, encoding: .utf8) {
                    throw APIError.serverError(errorString)
                }
                throw APIError.invalidResponse
                
            default:
                throw APIError.invalidResponse
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Models
    
    func listModels() async throws -> [ModelResponse] {
        guard let url = URL(string: "\(baseURL)/v1/models") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let modelList = try JSONDecoder().decode(ModelListResponse.self, from: data)
                return modelList.data
                
            case 401:
                throw APIError.unauthorized
                
            default:
                throw APIError.invalidResponse
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    func generateBragDocument(from messages: [SlackMessage], promptTemplate: String, modelName: String? = nil) async throws -> String {
        // Format the Slack messages for the prompt
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var formattedMessages = ""
        for message in messages.sorted(by: { $0.timestamp < $1.timestamp }) {
            formattedMessages += "[\(dateFormatter.string(from: message.timestamp))] "
            formattedMessages += "\(message.author) in \(message.channel):\n"
            formattedMessages += "\(message.text)\n\n"
        }
        
        // Replace placeholder in template
        let fullPrompt = promptTemplate.replacingOccurrences(of: "{messages}", with: formattedMessages)
        
        // Create chat messages
        let chatMessages = [
            ChatMessage(role: "system", content: "You are a professional technical writer who helps create brag documents from Slack messages. Focus on achievements, contributions, and impact."),
            ChatMessage(role: "user", content: fullPrompt)
        ]
        
        // Use provided model or default to gpt-4
        let selectedModel = modelName ?? "gpt-4"
        
        // Call the API
        return try await createChatCompletion(messages: chatMessages, model: selectedModel)
    }
    
    func generateSummary(messages: [SlackMessage], timePeriod: TimePeriod, existingSummaryId: String? = nil, modelName: String? = nil) async throws -> MessageSummary {
        guard !messages.isEmpty else {
            throw APIError.serverError("No messages to summarize")
        }
        
        // Format the Slack messages for the prompt
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var formattedMessages = ""
        for message in messages.sorted(by: { $0.timestamp < $1.timestamp }) {
            formattedMessages += "[\(dateFormatter.string(from: message.timestamp))] "
            formattedMessages += "\(message.author) in \(message.channel):\n"
            formattedMessages += "\(message.text)\n\n"
        }
        
        // Create summarization prompt
        let promptTemplate = """
        Summarize the following Slack messages for a \(timePeriod.rawValue.lowercased()) period.
        
        Focus on:
        - Key accomplishments and achievements
        - Technical contributions and implementations
        - Collaboration and teamwork
        - Problem-solving and decision-making
        - Project milestones and progress
        - Team interactions and people mentioned
        
        Be concise but preserve important details. Use bullet points where appropriate.
        The summary will be used later to generate a comprehensive brag document.
        
        Messages:
        \(formattedMessages)
        
        Provide a well-structured summary in markdown format.
        """
        
        let chatMessages = [
            ChatMessage(role: "system", content: "You are an expert at analyzing and summarizing professional communications. Create concise, information-dense summaries that preserve key accomplishments and interactions."),
            ChatMessage(role: "user", content: promptTemplate)
        ]
        
        // Use provided model or default to gpt-4
        let selectedModel = modelName ?? "gpt-4"
        
        // Call the API
        let summaryText = try await createChatCompletion(messages: chatMessages, model: selectedModel)
        
        // Create the summary object
        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
        let dateRangeStart = sortedMessages.first?.timestamp ?? Date()
        let dateRangeEnd = sortedMessages.last?.timestamp ?? Date()
        let messageIds = messages.map { $0.id }
        
        return MessageSummary(
            id: existingSummaryId ?? UUID().uuidString,
            timePeriod: timePeriod,
            dateRangeStart: dateRangeStart,
            dateRangeEnd: dateRangeEnd,
            messageIds: messageIds,
            summaryText: summaryText,
            generatedAt: Date()
        )
    }
    
    func generateBragDocumentFromSummaries(summaries: [MessageSummary], promptTemplate: String, modelName: String? = nil) async throws -> String {
        guard !summaries.isEmpty else {
            throw APIError.serverError("No summaries to process")
        }
        
        // Format the summaries for the prompt
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        var formattedSummaries = ""
        for summary in summaries.sorted(by: { $0.dateRangeStart < $1.dateRangeStart }) {
            formattedSummaries += "## \(summary.timePeriod.rawValue): \(summary.dateRangeDescription)\n"
            formattedSummaries += "(\(summary.messageCount) messages)\n\n"
            formattedSummaries += "\(summary.summaryText)\n\n"
            formattedSummaries += "---\n\n"
        }
        
        // Replace placeholder in template
        let fullPrompt = promptTemplate.replacingOccurrences(of: "{messages}", with: formattedSummaries)
        
        // Create chat messages
        let chatMessages = [
            ChatMessage(role: "system", content: "You are a professional technical writer who helps create brag documents from time-based summaries of work. Focus on synthesizing the summaries into a coherent narrative highlighting achievements, contributions, and impact."),
            ChatMessage(role: "user", content: fullPrompt)
        ]
        
        // Use provided model or default to gpt-4
        let selectedModel = modelName ?? "gpt-4"
        
        // Call the API
        return try await createChatCompletion(messages: chatMessages, model: selectedModel)
    }
}


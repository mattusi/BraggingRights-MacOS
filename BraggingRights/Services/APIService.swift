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
    
    init(apiKey: String) {
        self.apiKey = apiKey
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
            let (data, response) = try await URLSession.shared.data(for: request)
            
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
}


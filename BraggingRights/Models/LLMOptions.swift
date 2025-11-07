//
//  LLMOptions.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import Foundation

struct LLMOptions {
    var model: LLMModel = .gpt4
    var modelName: String? = nil // Actual model ID from API
    var promptTemplate: String = """
    Based on the following Slack messages, create a professional brag document highlighting achievements, contributions, and impact.
    
    Format the document with:
    - A summary of key accomplishments
    - Specific examples of technical contributions
    - Evidence of collaboration and teamwork
    - Impact on projects and team
    
    Messages:
    {messages}
    
    Please create a well-structured markdown document.
    """
    var temperature: Double = 0.7
    var maxTokens: Int = 16000 // Increased for large documents
    
    enum LLMModel: String, CaseIterable, Identifiable {
        case gpt4 = "GPT-4"
        case gpt35 = "GPT-3.5"
        case claude = "Claude"
        case custom = "Custom"
        
        var id: String { rawValue }
    }
}

struct ModelInfo {
    let id: String
    let contextWindow: Int
    
    static let knownModels: [String: Int] = [
        // GPT-4 Turbo models (128k context)
        "gpt-4-turbo": 128000,
        "gpt-4-turbo-preview": 128000,
        "gpt-4-turbo-2024-04-09": 128000,
        "gpt-4-1106-preview": 128000,
        "gpt-4-0125-preview": 128000,
        
        // Claude 3+ models (200k context)
        "claude-3-opus": 200000,
        "claude-3-sonnet": 200000,
        "claude-3-haiku": 200000,
        "claude-3-5-sonnet": 200000,
        "claude-3.5-sonnet": 200000,
        
        // Gemini models (1M+ context)
        "gemini-pro-1.5": 1000000,
        "gemini-1.5-pro": 1000000,
        
        // Standard models (smaller context - below threshold)
        "gpt-4": 8192,
        "gpt-4-32k": 32768,
        "gpt-3.5-turbo": 16385,
        "gpt-3.5-turbo-16k": 16385,
        "claude-2": 100000,
        "claude-2.1": 100000,
        "claude-instant": 100000
    ]
    
    static func contextWindow(for modelId: String) -> Int? {
        // Try exact match first
        if let window = knownModels[modelId] {
            return window
        }
        
        // Try partial match (e.g., "gpt-4-turbo-something" should match "gpt-4-turbo")
        for (knownModelId, window) in knownModels {
            if modelId.hasPrefix(knownModelId) {
                return window
            }
        }
        
        return nil
    }
    
    static func hasLargeContext(modelId: String, minimumTokens: Int = 128000) -> Bool {
        guard let window = contextWindow(for: modelId) else {
            return false
        }
        return window >= minimumTokens
    }
    
    static func formatContextWindow(_ tokens: Int) -> String {
        if tokens >= 1000000 {
            return "\(tokens / 1000000)M"
        } else if tokens >= 1000 {
            return "\(tokens / 1000)k"
        } else {
            return "\(tokens)"
        }
    }
}


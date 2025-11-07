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
    var maxTokens: Int = 2000
    
    enum LLMModel: String, CaseIterable, Identifiable {
        case gpt4 = "GPT-4"
        case gpt35 = "GPT-3.5"
        case claude = "Claude"
        case custom = "Custom"
        
        var id: String { rawValue }
    }
}


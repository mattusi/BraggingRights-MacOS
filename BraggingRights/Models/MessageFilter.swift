//
//  MessageFilter.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import Foundation

struct MessageFilter {
    var searchText: String = ""
    var selectedChannel: String?
    var selectedAuthor: String?
    var dateRangeStart: Date?
    var dateRangeEnd: Date?
    var selectedSessionId: String?
    
    func matches(_ message: SlackMessage) -> Bool {
        // Search text filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            let textMatches = message.text.lowercased().contains(searchLower)
            let authorMatches = message.author.lowercased().contains(searchLower)
            let channelMatches = message.channel.lowercased().contains(searchLower)
            
            if !textMatches && !authorMatches && !channelMatches {
                return false
            }
        }
        
        // Channel filter
        if let channel = selectedChannel, message.channel != channel {
            return false
        }
        
        // Author filter
        if let author = selectedAuthor, message.author != author {
            return false
        }
        
        // Session filter
        if let sessionId = selectedSessionId, message.sessionId != sessionId {
            return false
        }
        
        // Date range filter
        if let startDate = dateRangeStart, message.timestamp < startDate {
            return false
        }
        
        if let endDate = dateRangeEnd, message.timestamp > endDate {
            return false
        }
        
        return true
    }
    
    var isActive: Bool {
        !searchText.isEmpty || 
        selectedChannel != nil || 
        selectedAuthor != nil || 
        dateRangeStart != nil || 
        dateRangeEnd != nil ||
        selectedSessionId != nil
    }
    
    mutating func reset() {
        searchText = ""
        selectedChannel = nil
        selectedAuthor = nil
        dateRangeStart = nil
        dateRangeEnd = nil
        selectedSessionId = nil
    }
}

enum MessageSortOption: String, CaseIterable, Identifiable {
    case dateNewest = "Date (Newest First)"
    case dateOldest = "Date (Oldest First)"
    case author = "Author"
    case channel = "Channel"
    
    var id: String { rawValue }
    
    func sort(_ messages: [SlackMessage]) -> [SlackMessage] {
        switch self {
        case .dateNewest:
            return messages.sorted { $0.timestamp > $1.timestamp }
        case .dateOldest:
            return messages.sorted { $0.timestamp < $1.timestamp }
        case .author:
            return messages.sorted { $0.author < $1.author }
        case .channel:
            return messages.sorted { $0.channel < $1.channel }
        }
    }
}


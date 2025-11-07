//
//  SyncSession.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import Foundation

struct SyncSession: Identifiable, Codable, Hashable {
    let id: String
    let pageNumber: Int
    let importedAt: Date
    let messageCount: Int
    let dateRangeStart: Date?
    let dateRangeEnd: Date?
    
    init(id: String = UUID().uuidString,
         pageNumber: Int,
         importedAt: Date = Date(),
         messageCount: Int,
         dateRangeStart: Date?,
         dateRangeEnd: Date?) {
        self.id = id
        self.pageNumber = pageNumber
        self.importedAt = importedAt
        self.messageCount = messageCount
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
    }
    
    var dateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        guard let start = dateRangeStart, let end = dateRangeEnd else {
            return "Unknown date range"
        }
        
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return formatter.string(from: start)
        } else {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
}


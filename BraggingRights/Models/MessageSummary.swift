//
//  MessageSummary.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 10/11/25.
//

import Foundation

enum TimePeriod: String, CaseIterable, Codable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .day:
            return "calendar.day.timeline.left"
        case .week:
            return "calendar"
        case .month:
            return "calendar.badge.clock"
        }
    }
}

struct MessageSummary: Identifiable, Codable, Hashable {
    let id: String
    let timePeriod: TimePeriod
    let dateRangeStart: Date
    let dateRangeEnd: Date
    let messageIds: [String]
    var summaryText: String
    let generatedAt: Date
    
    init(id: String = UUID().uuidString,
         timePeriod: TimePeriod,
         dateRangeStart: Date,
         dateRangeEnd: Date,
         messageIds: [String],
         summaryText: String = "",
         generatedAt: Date = Date()) {
        self.id = id
        self.timePeriod = timePeriod
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.messageIds = messageIds
        self.summaryText = summaryText
        self.generatedAt = generatedAt
    }
    
    var dateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if Calendar.current.isDate(dateRangeStart, inSameDayAs: dateRangeEnd) {
            return formatter.string(from: dateRangeStart)
        } else {
            return "\(formatter.string(from: dateRangeStart)) - \(formatter.string(from: dateRangeEnd))"
        }
    }
    
    var messageCount: Int {
        return messageIds.count
    }
    
    var isEmpty: Bool {
        return summaryText.isEmpty
    }
}


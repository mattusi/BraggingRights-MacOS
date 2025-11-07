//
//  SlackMessage.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import Foundation

struct SlackMessage: Identifiable, Codable, Hashable {
    let id: String
    let text: String
    let timestamp: Date
    let author: String
    let authorId: String
    let channel: String
    let channelId: String
    let permalink: String?
    var sessionId: String? // Track which import session this message belongs to
    
    init(id: String = UUID().uuidString, 
         text: String, 
         timestamp: Date, 
         author: String, 
         authorId: String, 
         channel: String, 
         channelId: String,
         permalink: String? = nil,
         sessionId: String? = nil) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.author = author
        self.authorId = authorId
        self.channel = channel
        self.channelId = channelId
        self.permalink = permalink
        self.sessionId = sessionId
    }
}


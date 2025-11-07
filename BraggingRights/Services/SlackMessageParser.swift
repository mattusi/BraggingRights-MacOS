//
//  SlackMessageParser.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import Foundation

struct SlackMessageParser {
    static func parse(_ text: String) -> [SlackMessage] {
        var messages: [SlackMessage] = []
        
        // Split text into lines
        let lines = text.components(separatedBy: "\n")
        
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if line.isEmpty {
                i += 1
                continue
            }
            
            // Check if this line looks like an author name (not starting with special characters)
            // and the next non-empty line is a channel indicator
            if !line.isEmpty && !line.hasPrefix(" ") && !line.contains(" at ") {
                let potentialAuthor = line
                
                // Look ahead for channel and date
                var j = i + 1
                var channelLine: String?
                var dateLine: String?
                var messageStartIndex: Int?
                
                // Skip empty lines and find channel
                while j < lines.count {
                    let nextLine = lines[j].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if nextLine.isEmpty {
                        j += 1
                        continue
                    }
                    
                    // Check if it's a channel line (contains "Direct Message" or "Thread in")
                    if channelLine == nil && (nextLine.contains("Direct Message") || nextLine.contains("Thread in") || nextLine.contains("Channel")) {
                        channelLine = nextLine
                        j += 1
                        continue
                    }
                    
                    // Check if it's a date line (contains " at " and looks like a date)
                    if channelLine != nil && dateLine == nil && nextLine.contains(" at ") && isDateLine(nextLine) {
                        dateLine = nextLine
                        messageStartIndex = j + 1
                        break
                    }
                    
                    // If we found channel but next line doesn't look like date or channel, break
                    if channelLine != nil {
                        break
                    }
                    
                    j += 1
                }
                
                // If we found both channel and date, extract the message
                if let channel = channelLine, let dateStr = dateLine, let msgStart = messageStartIndex {
                    // Collect message lines until we hit the next author
                    var messageLines: [String] = []
                    var k = msgStart
                    
                    while k < lines.count {
                        let msgLine = lines[k]
                        
                        // Check if this is the start of a new message (author line)
                        // by looking ahead to see if there's a channel and date pattern
                        if k > msgStart && !msgLine.isEmpty && !msgLine.hasPrefix(" ") {
                            // Peek ahead to see if this looks like a new message
                            if k + 1 < lines.count {
                                var lookAhead = k + 1
                                var foundChannel = false
                                var foundDate = false
                                
                                while lookAhead < min(k + 5, lines.count) {
                                    let peekLine = lines[lookAhead].trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !peekLine.isEmpty {
                                        if peekLine.contains("Direct Message") || peekLine.contains("Thread in") {
                                            foundChannel = true
                                        } else if foundChannel && peekLine.contains(" at ") && isDateLine(peekLine) {
                                            foundDate = true
                                            break
                                        }
                                    }
                                    lookAhead += 1
                                }
                                
                                if foundChannel && foundDate {
                                    // This is a new message, stop collecting
                                    break
                                }
                            }
                        }
                        
                        messageLines.append(msgLine)
                        k += 1
                    }
                    
                    // Clean up message text
                    let messageText = messageLines
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n")
                    
                    // Filter out image attachments and "Show more" lines
                    let cleanedMessage = messageText
                        .components(separatedBy: "\n")
                        .filter { !$0.hasPrefix("IMG_") && !$0.contains("Shared by") && !$0.contains("Show more") }
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !cleanedMessage.isEmpty {
                        if let timestamp = parseDate(dateStr) {
                            let message = SlackMessage(
                                text: cleanedMessage,
                                timestamp: timestamp,
                                author: potentialAuthor,
                                authorId: potentialAuthor.lowercased().replacingOccurrences(of: " ", with: "-"),
                                channel: channel,
                                channelId: channel.lowercased().replacingOccurrences(of: " ", with: "-")
                            )
                            messages.append(message)
                        }
                    }
                    
                    // Move to the position where we stopped collecting message lines
                    i = k
                    continue
                }
            }
            
            i += 1
        }
        
        return messages
    }
    
    private static func isDateLine(_ line: String) -> Bool {
        // Check if line looks like a date (e.g., "Jul 15th, 2024 at 15:52")
        let datePattern = #"[A-Z][a-z]{2}\s+\d{1,2}[a-z]{2},\s+\d{4}\s+at\s+\d{1,2}:\d{2}"#
        return line.range(of: datePattern, options: .regularExpression) != nil
    }
    
    private static func parseDate(_ dateString: String) -> Date? {
        // Example: "Jul 15th, 2024 at 15:52"
        let formatter = DateFormatter()
        
        // Remove ordinal suffixes for easier parsing
        var cleanedString = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanedString = cleanedString.replacingOccurrences(of: "st,", with: ",")
        cleanedString = cleanedString.replacingOccurrences(of: "nd,", with: ",")
        cleanedString = cleanedString.replacingOccurrences(of: "rd,", with: ",")
        cleanedString = cleanedString.replacingOccurrences(of: "th,", with: ",")
        
        formatter.dateFormat = "MMM d, yyyy 'at' HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = formatter.date(from: cleanedString) {
            return date
        }
        
        // Fallback to current date
        return Date()
    }
}


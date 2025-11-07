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
                var foundIndicatorLine = false
                while j < lines.count {
                    let nextLine = lines[j].trimmingCharacters(in: .whitespacesAndNewlines)
                    let rawLine = lines[j]
                    
                    // Check if this is the indicator line (line with spaces or prefix)
                    if !foundIndicatorLine && j == i + 1 {
                        // This should be the line after author - check if it's an indicator
                        if rawLine.hasPrefix(" ") || rawLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            foundIndicatorLine = true
                            
                            // Check if it contains "Direct Message" or "Thread in"
                            if nextLine.contains("Direct Message") {
                                channelLine = nextLine
                                j += 1
                                continue
                            } else if nextLine.contains("Thread in") {
                                // Next line will be the channel name
                                j += 1
                                if j < lines.count {
                                    let channelName = lines[j].trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !channelName.isEmpty {
                                        channelLine = channelName
                                    }
                                }
                                j += 1
                                continue
                            } else {
                                // Regular channel message - next line is channel name
                                j += 1
                                if j < lines.count {
                                    let potentialChannel = lines[j].trimmingCharacters(in: .whitespacesAndNewlines)
                                    // Make sure it's not a date line
                                    if !potentialChannel.isEmpty && !isDateLine(potentialChannel) {
                                        channelLine = potentialChannel
                                        j += 1
                                        continue
                                    }
                                }
                            }
                        }
                    }
                    
                    if nextLine.isEmpty {
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
                                var foundIndicator = false
                                var foundDate = false
                                
                                // First line after potential author should be indicator line (with spaces)
                                let rawPeekLine = lines[lookAhead]
                                if rawPeekLine.hasPrefix(" ") || rawPeekLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    foundIndicator = true
                                    lookAhead += 1
                                    
                                    // Now look for channel name and date
                                    while lookAhead < min(k + 6, lines.count) {
                                        let peekLine = lines[lookAhead].trimmingCharacters(in: .whitespacesAndNewlines)
                                        if !peekLine.isEmpty {
                                            // Check if it's a date line - if so, we found a complete message pattern
                                            if peekLine.contains(" at ") && isDateLine(peekLine) {
                                                foundDate = true
                                                break
                                            }
                                        }
                                        lookAhead += 1
                                    }
                                }
                                
                                if foundIndicator && foundDate {
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
                    
                    // Filter out image attachments, link previews, and metadata lines
                    let cleanedMessage = messageText
                        .components(separatedBy: "\n")
                        .filter { line in
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            // Filter out common non-message content
                            return !trimmed.hasPrefix("IMG_") 
                                && !trimmed.hasPrefix("Screenshot ")
                                && !trimmed.hasPrefix("Image from ")
                                && !trimmed.contains("Shared by")
                                && !trimmed.contains("Show more")
                                && !trimmed.hasSuffix(".png")
                                && !trimmed.hasSuffix(".jpg")
                                && !trimmed.hasSuffix(".jpeg")
                                && !trimmed.hasSuffix(".gif")
                                // Filter out duplicate link preview titles (e.g., "YouTubeYouTube")
                                && !isLinkPreviewDuplicate(trimmed)
                        }
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
        // Check if line looks like a date
        // Format 1: "Jul 15th, 2024 at 15:52" (with year)
        // Format 2: "Jan 30th at 10:51" (without year)
        let datePatternWithYear = #"[A-Z][a-z]{2}\s+\d{1,2}[a-z]{2},\s+\d{4}\s+at\s+\d{1,2}:\d{2}"#
        let datePatternWithoutYear = #"[A-Z][a-z]{2}\s+\d{1,2}[a-z]{2}\s+at\s+\d{1,2}:\d{2}"#
        
        return line.range(of: datePatternWithYear, options: .regularExpression) != nil ||
               line.range(of: datePatternWithoutYear, options: .regularExpression) != nil
    }
    
    private static func isLinkPreviewDuplicate(_ line: String) -> Bool {
        // Detect lines like "YouTubeYouTube | Apple" or "Apple MusicApple Music"
        // These are Slack link preview artifacts where the title appears twice
        let words = line.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // Check for repeated words pattern (common in link previews)
        if words.count >= 2 {
            for i in 0..<words.count - 1 {
                if words[i] == words[i + 1] && words[i].count > 3 {
                    return true
                }
            }
        }
        
        // Check if line contains common link preview patterns
        let linkPreviewPatterns = ["YouTube", "X (formerly Twitter)", " | ", " - Web Player"]
        for pattern in linkPreviewPatterns {
            if line.contains(pattern) && line.count < 100 {
                // Short lines with these patterns are likely link previews
                return true
            }
        }
        
        return false
    }
    
    private static func parseDate(_ dateString: String) -> Date? {
        // Example formats:
        // "Jul 15th, 2024 at 15:52" (with year)
        // "Jan 30th at 10:51" (without year)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Remove ordinal suffixes for easier parsing
        var cleanedString = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanedString = cleanedString.replacingOccurrences(of: "st,", with: ",")
        cleanedString = cleanedString.replacingOccurrences(of: "nd,", with: ",")
        cleanedString = cleanedString.replacingOccurrences(of: "rd,", with: ",")
        cleanedString = cleanedString.replacingOccurrences(of: "th,", with: ",")
        cleanedString = cleanedString.replacingOccurrences(of: "st ", with: " ")
        cleanedString = cleanedString.replacingOccurrences(of: "nd ", with: " ")
        cleanedString = cleanedString.replacingOccurrences(of: "rd ", with: " ")
        cleanedString = cleanedString.replacingOccurrences(of: "th ", with: " ")
        
        // Try parsing with year first
        formatter.dateFormat = "MMM d, yyyy 'at' HH:mm"
        if let date = formatter.date(from: cleanedString) {
            return date
        }
        
        // Try parsing without year
        formatter.dateFormat = "MMM d 'at' HH:mm"
        if let date = formatter.date(from: cleanedString) {
            // Add the current year
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            var components = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
            components.year = currentYear
            
            if let dateWithYear = calendar.date(from: components) {
                return dateWithYear
            }
        }
        
        // Fallback to current date
        return Date()
    }
}


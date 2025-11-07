//
//  PersistenceManager.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import Foundation

enum PersistenceError: Error, LocalizedError {
    case fileNotFound
    case encodingFailed
    case decodingFailed
    case directoryCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Data file not found"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        case .directoryCreationFailed:
            return "Failed to create data directory"
        }
    }
}

struct AppData: Codable {
    var messages: [SlackMessage]
    var sessions: [SyncSession]
    var lastUpdated: Date
    
    init(messages: [SlackMessage] = [], sessions: [SyncSession] = []) {
        self.messages = messages
        self.sessions = sessions
        self.lastUpdated = Date()
    }
}

class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let fileName = "bragging-rights-data.json"
    private var fileURL: URL {
        get throws {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let appDirectory = appSupport.appendingPathComponent("BraggingRights", isDirectory: true)
            
            // Create directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: appDirectory.path) {
                try FileManager.default.createDirectory(
                    at: appDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            
            return appDirectory.appendingPathComponent(fileName)
        }
    }
    
    private init() {}
    
    // MARK: - Load Data
    
    func loadData() throws -> AppData {
        let url = try fileURL
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Return empty data if file doesn't exist yet
            return AppData()
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let appData = try decoder.decode(AppData.self, from: data)
            return appData
        } catch {
            print("Failed to load data: \(error)")
            throw PersistenceError.decodingFailed
        }
    }
    
    // MARK: - Save Data
    
    func saveData(_ appData: AppData) throws {
        let url = try fileURL
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(appData)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Failed to save data: \(error)")
            throw PersistenceError.encodingFailed
        }
    }
    
    // MARK: - Convenience Methods
    
    func saveMessages(_ messages: [SlackMessage], sessions: [SyncSession]) throws {
        var appData = (try? loadData()) ?? AppData()
        appData.messages = messages
        appData.sessions = sessions
        appData.lastUpdated = Date()
        try saveData(appData)
    }
    
    func loadMessages() throws -> [SlackMessage] {
        let appData = try loadData()
        return appData.messages
    }
    
    func loadSessions() throws -> [SyncSession] {
        let appData = try loadData()
        return appData.sessions
    }
    
    // MARK: - Export/Import
    
    func exportToURL(_ url: URL) throws {
        let appData = try loadData()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(appData)
        try data.write(to: url, options: [.atomic])
    }
    
    func importFromURL(_ url: URL) throws -> AppData {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let appData = try decoder.decode(AppData.self, from: data)
        try saveData(appData)
        return appData
    }
    
    // MARK: - Statistics
    
    func getStatistics() throws -> DataStatistics {
        let appData = try loadData()
        
        let uniqueChannels = Set(appData.messages.map { $0.channel })
        let uniqueAuthors = Set(appData.messages.map { $0.author })
        
        let oldestMessage = appData.messages.min(by: { $0.timestamp < $1.timestamp })
        let newestMessage = appData.messages.max(by: { $0.timestamp < $1.timestamp })
        
        return DataStatistics(
            totalMessages: appData.messages.count,
            totalSessions: appData.sessions.count,
            uniqueChannels: uniqueChannels.count,
            uniqueAuthors: uniqueAuthors.count,
            oldestMessageDate: oldestMessage?.timestamp,
            newestMessageDate: newestMessage?.timestamp,
            lastUpdated: appData.lastUpdated
        )
    }
    
    // MARK: - Clear Data
    
    func clearAllData() throws {
        let url = try fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

struct DataStatistics {
    let totalMessages: Int
    let totalSessions: Int
    let uniqueChannels: Int
    let uniqueAuthors: Int
    let oldestMessageDate: Date?
    let newestMessageDate: Date?
    let lastUpdated: Date
    
    var dateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        guard let oldest = oldestMessageDate, let newest = newestMessageDate else {
            return "No messages"
        }
        
        if Calendar.current.isDate(oldest, inSameDayAs: newest) {
            return formatter.string(from: oldest)
        } else {
            return "\(formatter.string(from: oldest)) - \(formatter.string(from: newest))"
        }
    }
}


//
//  MessageLibraryView.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import SwiftUI

struct MessageLibraryView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var filter = MessageFilter()
    @State private var sortOption: MessageSortOption = .dateNewest
    @State private var selectedMessages = Set<String>()
    @State private var showDeleteConfirmation = false
    @State private var groupBySession = false
    
    var filteredAndSortedMessages: [SlackMessage] {
        let filtered = viewModel.allMessages.filter { filter.matches($0) }
        return sortOption.sort(filtered)
    }
    
    var availableChannels: [String] {
        Array(Set(viewModel.allMessages.map { $0.channel })).sorted()
    }
    
    var availableAuthors: [String] {
        Array(Set(viewModel.allMessages.map { $0.author })).sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with statistics
            headerView
            
            Divider()
            
            // Filters and search
            filterBar
            
            Divider()
            
            // Messages list
            if filteredAndSortedMessages.isEmpty {
                emptyStateView
            } else {
                messagesList
            }
        }
        .alert("Delete Messages", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedMessages()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedMessages.count) message(s)?")
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Message Library")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let stats = viewModel.statistics {
                    Text("\(stats.totalMessages) messages • \(stats.dateRangeDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                if !selectedMessages.isEmpty {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete Selected (\(selectedMessages.count))", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                }
                
                Button(action: {
                    selectedMessages.removeAll()
                }) {
                    Label("Clear Selection", systemImage: "xmark.circle")
                }
                .disabled(selectedMessages.isEmpty)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var filterBar: some View {
        VStack(spacing: 12) {
            HStack {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search messages, authors, channels...", text: $filter.searchText)
                        .textFieldStyle(.plain)
                    
                    if !filter.searchText.isEmpty {
                        Button(action: { filter.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                
                // Sort picker
                Picker("Sort", selection: $sortOption) {
                    ForEach(MessageSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                
                // Group by session toggle
                Toggle("Group by Session", isOn: $groupBySession)
                    .toggleStyle(.switch)
            }
            
            // Advanced filters
            HStack {
                // Channel filter
                Picker("Channel", selection: $filter.selectedChannel) {
                    Text("All Channels").tag(nil as String?)
                    Divider()
                    ForEach(availableChannels, id: \.self) { channel in
                        Text(channel).tag(channel as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                
                // Author filter
                Picker("Author", selection: $filter.selectedAuthor) {
                    Text("All Authors").tag(nil as String?)
                    Divider()
                    ForEach(availableAuthors, id: \.self) { author in
                        Text(author).tag(author as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                
                Spacer()
                
                // Reset filters button
                if filter.isActive {
                    Button(action: {
                        filter.reset()
                    }) {
                        Label("Clear Filters", systemImage: "xmark.circle")
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if groupBySession {
                    messagesBySession
                } else {
                    messagesFlat
                }
            }
        }
    }
    
    private var messagesFlat: some View {
        ForEach(filteredAndSortedMessages) { message in
            MessageRow(
                message: message,
                isSelected: selectedMessages.contains(message.id),
                onToggle: { toggleSelection(message.id) },
                onDelete: { deleteMessage(message.id) }
            )
            Divider()
        }
    }
    
    private var messagesBySession: some View {
        ForEach(groupedMessages, id: \.session.id) { group in
            VStack(alignment: .leading, spacing: 0) {
                // Session header
                HStack {
                    Text("Page \(group.session.pageNumber)")
                        .font(.headline)
                    Text("• \(group.session.messageCount) messages")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("• \(group.session.dateRangeDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                
                // Messages in this session
                ForEach(group.messages) { message in
                    MessageRow(
                        message: message,
                        isSelected: selectedMessages.contains(message.id),
                        onToggle: { toggleSelection(message.id) },
                        onDelete: { deleteMessage(message.id) }
                    )
                    Divider()
                }
            }
        }
    }
    
    private var groupedMessages: [(session: SyncSession, messages: [SlackMessage])] {
        var groups: [(session: SyncSession, messages: [SlackMessage])] = []
        
        for session in viewModel.syncSessions.sorted(by: { $0.pageNumber > $1.pageNumber }) {
            let sessionMessages = filteredAndSortedMessages.filter { $0.sessionId == session.id }
            if !sessionMessages.isEmpty {
                groups.append((session: session, messages: sessionMessages))
            }
        }
        
        // Add messages without a session
        let orphanMessages = filteredAndSortedMessages.filter { $0.sessionId == nil }
        if !orphanMessages.isEmpty {
            let orphanSession = SyncSession(
                id: "orphan",
                pageNumber: 0,
                importedAt: Date(),
                messageCount: orphanMessages.count,
                dateRangeStart: nil,
                dateRangeEnd: nil
            )
            groups.append((session: orphanSession, messages: orphanMessages))
        }
        
        return groups
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No messages found")
                .font(.title3)
                .fontWeight(.medium)
            
            if filter.isActive {
                Text("Try adjusting your filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Clear Filters") {
                    filter.reset()
                }
            } else {
                Text("Import messages from Slack to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func toggleSelection(_ messageId: String) {
        if selectedMessages.contains(messageId) {
            selectedMessages.remove(messageId)
        } else {
            selectedMessages.insert(messageId)
        }
    }
    
    private func deleteMessage(_ messageId: String) {
        viewModel.deleteMessage(messageId)
    }
    
    private func deleteSelectedMessages() {
        viewModel.deleteMessages(Array(selectedMessages))
        selectedMessages.removeAll()
    }
}

struct MessageRow: View {
    let message: SlackMessage
    let isSelected: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection checkbox
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 8) {
                // Header: author, channel, date
                HStack {
                    Text(message.author)
                        .font(.headline)
                    
                    Text("in \(message.channel)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatDate(message.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Message text
                Text(message.text)
                    .font(.body)
                    .lineLimit(isHovered ? nil : 3)
                    .textSelection(.enabled)
            }
            
            // Delete button (shown on hover)
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    MessageLibraryView(viewModel: AppViewModel())
}


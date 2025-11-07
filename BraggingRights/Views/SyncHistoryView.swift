//
//  SyncHistoryView.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 07/11/25.
//

import SwiftUI

struct SyncHistoryView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedSession: SyncSession?
    @State private var showDeleteConfirmation = false
    @State private var sessionToDelete: SyncSession?
    
    var sortedSessions: [SyncSession] {
        viewModel.syncSessions.sorted { $0.pageNumber > $1.pageNumber }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Sessions list
            if sortedSessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
            }
        }
        .alert("Delete Session", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    deleteSession(session)
                }
            }
        } message: {
            if let session = sessionToDelete {
                Text("Are you sure you want to delete Page \(session.pageNumber) with \(session.messageCount) message(s)?")
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sync History")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(sortedSessions.count) import sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let lastSession = sortedSessions.first {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next Page: \(lastSession.pageNumber + 1)")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    
                    Text("Last import: \(formatDate(lastSession.importedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedSessions) { session in
                    SessionRow(
                        session: session,
                        isSelected: selectedSession?.id == session.id,
                        onSelect: { selectedSession = session },
                        onDelete: {
                            sessionToDelete = session
                            showDeleteConfirmation = true
                        }
                    )
                    Divider()
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No import history")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Import messages from Slack to start tracking your sync history")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func deleteSession(_ session: SyncSession) {
        viewModel.deleteSession(session.id)
        if selectedSession?.id == session.id {
            selectedSession = nil
        }
        sessionToDelete = nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SessionRow: View {
    let session: SyncSession
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Page number badge
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text("\(session.pageNumber)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Session title
                HStack {
                    Text("Page \(session.pageNumber)")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(formatDate(session.importedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Message count
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundColor(.secondary)
                    Text("\(session.messageCount) messages")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Date range
                if let _ = session.dateRangeStart {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        Text(session.dateRangeDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Import date
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("Imported \(relativeDate(session.importedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Delete button (shown on hover)
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
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
    
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    SyncHistoryView(viewModel: AppViewModel())
}


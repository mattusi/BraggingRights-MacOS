//
//  MessageSummarizationView.swift
//  BraggingRights
//
//  Created by Matheus Tusi on 10/11/25.
//

import SwiftUI

struct MessageSummarizationView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedSummaryId: String?
    
    var body: some View {
        HSplitView {
            // Left panel - Configuration and controls
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Info section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Message Summarization")
                                .font(.headline)
                        }
                        
                        Text("Generate AI summaries of your messages grouped by time period. This helps manage context when generating the final document.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    Divider()
                    
                    // Time period selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time Period")
                            .font(.headline)
                        
                        Picker("Group by", selection: $viewModel.selectedTimePeriod) {
                            ForEach(TimePeriod.allCases) { period in
                                Label(period.rawValue, systemImage: period.icon)
                                    .tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // Show statistics for selected period
                        if let groupCount = viewModel.getMessageGroupCount(for: viewModel.selectedTimePeriod) {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .foregroundColor(.secondary)
                                Text("\(groupCount) \(viewModel.selectedTimePeriod.rawValue.lowercased())\(groupCount == 1 ? "" : "s") with messages")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Generate summaries button
                    VStack(spacing: 12) {
                        // Model warning
                        if !viewModel.availableModels.isEmpty && viewModel.llmOptions.modelName == nil {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Please select a model in the Generate Document step before summarizing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        Button(action: {
                            viewModel.generateAllSummaries()
                        }) {
                            HStack {
                                if viewModel.isSummarizing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 4)
                                }
                                Text(viewModel.isSummarizing ? "Generating Summaries..." : "Generate All Summaries")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.allMessages.isEmpty || viewModel.apiKey.isEmpty || viewModel.isSummarizing)
                        
                        // Progress indicator
                        if viewModel.isSummarizing {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Progress: \(viewModel.summariesGenerated)/\(viewModel.totalSummariesToGenerate)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(Int((Double(viewModel.summariesGenerated) / Double(max(viewModel.totalSummariesToGenerate, 1))) * 100))%")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.accentColor)
                                }
                                
                                ProgressView(value: Double(viewModel.summariesGenerated), total: Double(max(viewModel.totalSummariesToGenerate, 1)))
                            }
                            .padding()
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Error Message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Existing summaries list
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Generated Summaries (\(viewModel.messageSummaries.count))")
                                .font(.headline)
                            
                            Spacer()
                            
                            if !viewModel.messageSummaries.isEmpty {
                                Button(action: {
                                    viewModel.clearAllSummaries()
                                }) {
                                    Text("Clear All")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        if viewModel.messageSummaries.isEmpty {
                            Text("No summaries generated yet. Select a time period and click 'Generate All Summaries'.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            ForEach(viewModel.messageSummaries.sorted(by: { $0.dateRangeStart < $1.dateRangeStart })) { summary in
                                SummaryRowView(
                                    summary: summary,
                                    isSelected: selectedSummaryId == summary.id,
                                    onSelect: {
                                        selectedSummaryId = summary.id
                                    },
                                    onRefresh: {
                                        viewModel.refreshSummary(summaryId: summary.id)
                                    },
                                    onDelete: {
                                        viewModel.deleteSummary(summaryId: summary.id)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(minWidth: 400, maxWidth: 500)
            
            // Right panel - Summary preview
            SummaryPreviewView(
                viewModel: viewModel,
                selectedSummaryId: $selectedSummaryId
            )
        }
    }
}

struct SummaryRowView: View {
    let summary: MessageSummary
    let isSelected: Bool
    let onSelect: () -> Void
    let onRefresh: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: summary.timePeriod.icon)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    
                    Text(summary.dateRangeDescription)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                }
                
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.caption2)
                    Text("\(summary.messageCount) messages")
                    
                    Spacer()
                    
                    if !summary.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Refresh summary")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete summary")
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture(perform: onSelect)
    }
}

struct SummaryPreviewView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var selectedSummaryId: String?
    
    var selectedSummary: MessageSummary? {
        guard let id = selectedSummaryId else { return nil }
        return viewModel.messageSummaries.first { $0.id == id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Summary Preview")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let summary = selectedSummary, !summary.isEmpty {
                    Button(action: {
                        copySummaryToClipboard()
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            if let summary = selectedSummary {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Metadata
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: summary.timePeriod.icon)
                                    .foregroundColor(.accentColor)
                                Text(summary.dateRangeDescription)
                                    .font(.headline)
                            }
                            
                            HStack(spacing: 16) {
                                Label("\(summary.messageCount) messages", systemImage: "bubble.left.and.bubble.right")
                                
                                let formatter = DateFormatter()
                                let _ = {
                                    formatter.dateStyle = .medium
                                    formatter.timeStyle = .short
                                }()
                                
                                Label("Generated \(formatter.string(from: summary.generatedAt))", systemImage: "clock")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                        
                        Divider()
                        
                        // Summary text
                        if summary.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("Summary not yet generated")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(40)
                        } else {
                            Text(summary.summaryText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Select a Summary")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Choose a summary from the list to view its details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
    }
    
    private func copySummaryToClipboard() {
        guard let summary = selectedSummary else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary.summaryText, forType: .string)
    }
}

#Preview {
    MessageSummarizationView(viewModel: AppViewModel())
}


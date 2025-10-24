//
//  TAPrettyLogViewer.swift
//  TADebugTools
//
//  Created by Robert Tataru on 24.10.2025.
//

import SwiftUI
import Combine

import SwiftUI
import UniformTypeIdentifiers

public struct TAPrettyLogViewer: View {
    // MARK: Inputs
    private let fileURL: URL?
    private let initialText: String?
    private let title: String

    // MARK: State
    @State private var contents: String = ""
    @State private var isLoading: Bool = false
    @State private var isGeneratingReport: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // MARK: Init
    /// Display from a file URL
    public init(fileURL: URL, title: String = "Analytics Report") {
        self.fileURL = fileURL
        self.initialText = nil
        self.title = title
    }

    /// Display from a raw string (useful for previews or piping the report directly)
    public init(text: String, title: String = "Analytics Report") {
        self.fileURL = nil
        self.initialText = text
        self.title = title
        // Don't generate report immediately in init - do it in task
    }

    public var body: some View {
        NavigationView {
            Group {
                if isLoading || isGeneratingReport {
                    loadingView
                } else if contents.isEmpty {
                    emptyState
                } else {
                    viewer
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadIfNeeded() }
            .alert("Couldn't Open File", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !contents.isEmpty {
                        copyButton
                        ShareLink(item: contentsData(), preview: .init("analytics_report.txt"))
                    }
                }
            }
        }
    }

    // MARK: Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(isGeneratingReport ? "Generating Report..." : "Loading...")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if isGeneratingReport {
                Text("Parsing log entries and building analytics")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var viewer: some View {
        ScrollView {
            Text(contents)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.background.opacity(0.6))
                        .shadow(radius: 6, y: 2)
                )
                .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .imageScale(.large)
                .font(.system(size: 40))
            Text("No report to display")
                .font(.headline)
            Text("Generate the report and pass its file URL (or the raw text) to TAPrettyLogViewer.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var copyButton: some View {
        Button {
            #if os(iOS)
            UIPasteboard.general.string = contents
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(contents, forType: .string)
            #endif
        } label: {
            Image(systemName: "doc.on.doc")
        }
        .help("Copy to clipboard")
        .disabled(contents.isEmpty)
    }

    // MARK: Loading

    @MainActor
    private func loadIfNeeded() async {
        // Handle initial text case
        if let initialText = initialText, contents.isEmpty {
            isGeneratingReport = true
            defer { isGeneratingReport = false }
            
            // Generate report on background queue to avoid blocking UI
            let report = await generateReportAsync(from: initialText)
            
            contents = report
            return
        }
        
        // Handle file URL case
        guard contents.isEmpty, let fileURL else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try Data(contentsOf: fileURL)
            if let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) {
                isGeneratingReport = true
                
                // Generate report on background queue to avoid blocking UI
                let report = await generateReportAsync(from: str)
                
                isGeneratingReport = false
                contents = report
            } else {
                throw NSError(domain: "TAPrettyLogViewer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unsupported text encoding."])
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: Helpers

    /// Build the human-readable analytics report from raw log text - runs off main actor
    private func generateReportAsync(from rawText: String) async -> String {
        return await Task.detached(priority: .userInitiated) {
            Self.generateReport(from: rawText)
        }.value
    }
    
    /// Static method to generate report - not tied to main actor
    nonisolated
    private static func generateReport(from rawText: String) -> String {
        let parser = PrettyLogParser()
        let sessions = parser.parse(rawText)
        let generator = ReportGenerator()
        
        // If no sessions found, add debug information
        if sessions.isEmpty {
            var debugReport = """
            📊 SESSION ANALYTICS - DEBUG MODE
            ══════════════════════════════════
            
            ❌ No sessions found.
            
            📋 DEBUG INFORMATION:
            ────────────────────
            
            """
            
            // Count total lines
            let lines = rawText.components(separatedBy: .newlines)
            let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            debugReport += "Total lines: \(lines.count)\n"
            debugReport += "Non-empty lines: \(nonEmptyLines.count)\n\n"
            
            // Sample the first few lines
            debugReport += "📄 FIRST 10 NON-EMPTY LINES:\n"
            debugReport += "─────────────────────────────\n"
            let sampleLines = Array(nonEmptyLines.prefix(10))
            for (index, line) in sampleLines.enumerated() {
                debugReport += "\(index + 1). \(line)\n"
            }
            
            // Check for analytics lines specifically
            let analyticsLines = lines.filter { $0.lowercased().contains("analytics") }
            debugReport += "\n🔍 ANALYTICS LINES FOUND: \(analyticsLines.count)\n"
            debugReport += "─────────────────────────────────────\n"
            for (index, line) in Array(analyticsLines.prefix(5)).enumerated() {
                debugReport += "\(index + 1). \(line)\n"
            }
            
            if analyticsLines.isEmpty {
                debugReport += "\n⚠️ No lines containing 'analytics' found.\n"
                debugReport += "The parser filters for analytics events only.\n"
                debugReport += "Check if your logs use a different category name.\n"
            }
            
            return debugReport
        }
        
        return generator.generate(sessions: sessions)
    }

    private func contentsData() -> SharePreviewItem {
        // Export as UTF-8 .txt for easy sharing
        let data = contents.data(using: .utf8) ?? Data()
        return SharePreviewItem(data: data, filename: "analytics_report.txt", contentType: .plainText)
    }
}

// MARK: - Share helper

private struct SharePreviewItem: Transferable {
    let data: Data
    let filename: String
    let contentType: UTType

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { item in
            item.data
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TAPrettyLogViewer_Previews: PreviewProvider {
    static var sampleLog: String {
        """
        ///
        """
    }

    static var previews: some View {
        TAPrettyLogViewer(text: sampleLog, title: "Improved Analytics Report")
    }
}
#endif

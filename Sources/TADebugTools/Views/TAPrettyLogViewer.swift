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
    @State private var wrapLines: Bool = true

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
                        wrapToggle  
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
        // Two modes: wrapped (single vertical scroll) vs unwrapped (both axes)
        Group {
            if wrapLines {
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
            } else {
                ScrollView([.vertical, .horizontal]) {
                    Text(verbatim: contents) // verbatim to preserve spacing when not wrapping
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.background.opacity(0.6))
                                .shadow(radius: 6, y: 2)
                        )
                        .padding()
                }
            }
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

    private var wrapToggle: some View {
        Toggle(isOn: $wrapLines) {
            Image(systemName: wrapLines ? "line.3.horizontal.decrease" : "arrow.left.and.right.square")
        }
        .toggleStyle(.button)
        .help(wrapLines ? "Disable line wrap" : "Enable line wrap")
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
            let report = await Task.detached(priority: .userInitiated) {
                generateReport(from: initialText)
            }.value
            
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
                let report = await Task.detached(priority: .userInitiated) {
                    generateReport(from: str)
                }.value
                
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

    /// Build the human-readable analytics report from raw log text
    private func generateReport(from rawText: String) -> String {
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
        2025-10-24T14:45:37+0300 info [EasyStickyNotes.main] : [EasyStickyNotes] App launch completed successfully
        2025-10-24T14:45:37+0300 info [EasyStickyNotes.main] : launchCount=1 [EasyStickyNotes] App launched
        2025-10-24T14:45:41+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: onboarding_enter, params: timeDelta:4.086461901664734
        2025-10-24T14:45:41+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_view_show, params: name:WELCOMESCREEN, timeDelta:4.0837050676345825
        2025-10-24T14:45:41+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_button_tap, params: name:CONTINUE, timeDelta:3.276497006416321, view_name:WELCOMESCREEN
        2025-10-24T14:45:41+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_view_show, params: name:TESTIMONIALS, timeDelta:3.2487510442733765
        2025-10-24T14:45:41+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_button_tap, params: name:CONTINUE, timeDelta:1.3085170984268188, view_name:TESTIMONIALS
        2025-10-24T14:45:41+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_view_show, params: name:ONBOARDING_PREMIUM, timeDelta:1.2831809520721436
        2025-10-24T14:45:41+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: paywall_show, params: name:Paywall #1, placement:onboarding, timeDelta:0.31248998641967773
        2025-10-24T14:45:44+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_view_show, params: name:DASHBOARD
        2025-10-24T14:45:45+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_button_tap, params: name:CREATE_NOTE, view_name:DASHBOARD
        2025-10-24T14:45:45+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_view_show, params: name:CREATE_NOTE
        2025-10-24T14:46:03+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_button_tap, params: name:BACKGROUND_COLOR_CHANGED, view_name:EDIT_NOTE
        2025-10-24T14:46:07+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: FONT_FAMILY_CHANGED, params: font_family:markerFelt
        2025-10-24T14:46:10+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: FONT_SIZE_CHANGED, params: font_size:16
        2025-10-24T14:46:17+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_button_tap, params: name:SAVE_NOTE, view_name:CREATE_NOTE
        2025-10-24T14:46:18+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: NOTE_OPENED, params: nil
        2025-10-24T14:46:18+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_view_show, params: name:EDIT_NOTE
        2025-10-24T14:46:23+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: app_close, params: view_name:EDIT_NOTE
        -- ** ** ** --
        2025-10-24T14:46:24+0300 info [EasyStickyNotes.main] : [EasyStickyNotes] App launch completed successfully
        2025-10-24T14:46:24+0300 info [EasyStickyNotes.main] : launchCount=2 [EasyStickyNotes] App launched
        2025-10-24T14:46:28+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_view_show, params: name:DASHBOARD, timeDelta:4.228966951370239
        2025-10-24T14:46:28+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: NOTE_OPENED, params: timeDelta:3.4334700107574463
        2025-10-24T14:46:28+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_view_show, params: name:EDIT_NOTE, timeDelta:3.3983709812164307
        2025-10-24T14:46:28+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: NOTE_MODE_CHANGED, params: from:plainText, timeDelta:1.678725004196167, to:affirmation
        2025-10-24T14:46:32+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_button_tap, params: name:MULTIPLE_AFFIRMATIONS_ADDED, view_name:EDIT_NOTE
        2025-10-24T14:46:36+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: AFFIRMATION_REFRESH_INTERVAL_CHANGED, params: refresh_interval:4
        2025-10-24T14:46:41+0300 info [EasyStickyNotes.analytics] : [EasyStickyNotes] sendEvent: ui_button_tap, params: name:NOTE_UPDATED, view_name:EDIT_NOTE
        2025-10-24T14:46:43+0300 info [EasyStickyNotes.analytics] : [
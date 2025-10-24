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
        self._contents = State(initialValue: generateReport(from: text))
    }

    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading…")
                    .padding()
            } else if contents.isEmpty {
                emptyState
            } else {
                viewer
            }
        }
        .navigationTitle(title)
        .task { await loadIfNeeded() }
        .alert("Couldn’t Open File", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                wrapToggle
                ShareLink(item: contentsData(), preview: .init("analytics_report.txt"))
            }
            ToolbarItem(placement: .topBarLeading) { copyButton }
        }
    }

    // MARK: Subviews

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
        .padding()
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
        guard contents.isEmpty, let fileURL else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try Data(contentsOf: fileURL)
            if let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) {
                contents = generateReport(from: str)
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
    static var sample: String {
        """
        ╔════════════════════════════════════════════════════════════════════╗
        ║                    USER SESSION ANALYTICS REPORT                    ║
        ╚════════════════════════════════════════════════════════════════════╝

        Total Sessions: 2
        Average Session Duration: 2m 14s
        Average Screens per Session: 3.5

        ┌────────────────────────────────────────────────────────────────────┐
        │ SESSION #1
        │ Started: 12:04:33
        │ Duration: 1m 03s
        │ App_Version: 1.4.0
        │ Device: iPhone16,1
        └────────────────────────────────────────────────────────────────────┘

        📱 User Journey:

          1. Home
             ⏱  Time spent: 24s
             📍 Actions (2):
                👆 Play Button (Mode: Classic)
                💳 Subscribe (Placement: Paywall A)

          2. Game Screen
             ⏱  Time spent: 39s
             📍 Actions (3):
                👆 Start ×2
                ❌ Pause
                📤 Share (Channel: Messages)

        ────────────────────────────────────────────────────────────────────────
        """
    }

    static var previews: some View {
        NavigationStack {
            TAPrettyLogViewer(text: sample)
        }
    }
}
#endif

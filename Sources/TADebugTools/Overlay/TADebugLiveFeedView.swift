/*
MIT License

Copyright (c) 2025 Tech Artists Agency

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import SwiftUI

enum TADebugLiveFeedSourceFilter: String, CaseIterable, Identifiable {
    case all
    case logs
    case analytics

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .logs:
            return "Logs"
        case .analytics:
            return "Analytics"
        }
    }

    func includes(_ item: TADebugLiveFeedItem) -> Bool {
        switch self {
        case .all:
            return true
        case .logs:
            return item.sourceID == TADebugLiveFeedSource.logsSourceID
        case .analytics:
            return item.sourceID == TADebugLiveFeedSource.analyticsSourceID
        }
    }
}

struct TADebugLiveFeedQuery {
    var sourceFilter: TADebugLiveFeedSourceFilter = .all
    var searchText: String = ""

    func filteredItems(from items: [TADebugLiveFeedItem]) -> [TADebugLiveFeedItem] {
        let normalizedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return items.filter { item in
            guard sourceFilter.includes(item) else {
                return false
            }

            guard !normalizedSearchText.isEmpty else {
                return true
            }

            return item.message.localizedCaseInsensitiveContains(normalizedSearchText)
                || item.sourceTitle.localizedCaseInsensitiveContains(normalizedSearchText)
                || (item.metadataText?.localizedCaseInsensitiveContains(normalizedSearchText) ?? false)
        }
    }
}

struct TADebugLiveFeedBuffer {
    let capacity: Int
    private(set) var items: [TADebugLiveFeedItem]

    init(
        capacity: Int = 500,
        items: [TADebugLiveFeedItem] = []
    ) {
        self.capacity = max(1, capacity)
        self.items = Array(items.suffix(max(1, capacity)))
    }

    mutating func append(_ item: TADebugLiveFeedItem) {
        items.append(item)

        if items.count > capacity {
            items.removeFirst(items.count - capacity)
        }
    }
}

@MainActor
final class TADebugLiveFeedStore: ObservableObject {
    static let defaultCapacity = 500

    @Published private(set) var items: [TADebugLiveFeedItem] = []

    private var buffer = TADebugLiveFeedBuffer(capacity: defaultCapacity)
    private var sourceTasks: [String: Task<Void, Never>] = [:]
    private var connectedSourceIDs: [String] = []

    deinit {
        sourceTasks.values.forEach { $0.cancel() }
    }

    func connect(to sources: [TADebugLiveFeedSource]) {
        let newSourceIDs = sources.map(\.id)

        guard newSourceIDs != connectedSourceIDs else {
            return
        }

        disconnect()
        connectedSourceIDs = newSourceIDs
        buffer = TADebugLiveFeedBuffer(capacity: Self.defaultCapacity)
        items = []

        for source in sources {
            sourceTasks[source.id] = Task { [weak self] in
                let stream = source.makeStream()

                for await item in stream {
                    guard !Task.isCancelled else {
                        break
                    }

                    self?.append(item)
                }
            }
        }
    }

    func disconnect() {
        sourceTasks.values.forEach { $0.cancel() }
        sourceTasks.removeAll()
        connectedSourceIDs.removeAll()
    }

    private func append(_ item: TADebugLiveFeedItem) {
        buffer.append(item)
        items = buffer.items
    }
}

struct TADebugLiveFeedView: View {
    @ObservedObject var liveFeedStore: TADebugLiveFeedStore

    @State private var searchText: String = ""
    @State private var sourceFilter: TADebugLiveFeedSourceFilter = .all
    @State private var autoScrollEnabled = true

    private var filteredItems: [TADebugLiveFeedItem] {
        TADebugLiveFeedQuery(
            sourceFilter: sourceFilter,
            searchText: searchText
        )
        .filteredItems(from: liveFeedStore.items)
    }

    var body: some View {
        VStack(spacing: 12) {
            controls

            if filteredItems.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    List(filteredItems) { item in
                        TADebugLiveFeedRow(item: item)
                            .id(item.id)
                            .onAppear {
                                handleRowAppear(itemID: item.id)
                            }
                            .onDisappear {
                                handleRowDisappear(itemID: item.id)
                            }
                            .listRowSeparator(.visible)
                    }
                    .listStyle(.plain)
                    .onChange(of: filteredItems.last?.id) { lastItemID in
                        guard autoScrollEnabled, let lastItemID else {
                            return
                        }

                        withAnimation {
                            proxy.scrollTo(lastItemID, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search live feed")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Source", selection: $sourceFilter) {
                ForEach(TADebugLiveFeedSourceFilter.allCases) { filter in
                    Text(filter.title)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Text(autoScrollEnabled ? "Auto-scroll is on" : "Auto-scroll is paused until you return to the bottom")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func handleRowAppear(itemID: TADebugLiveFeedItem.ID) {
        guard itemID == filteredItems.last?.id else {
            return
        }

        setAutoScrollEnabled(true)
    }

    private func handleRowDisappear(itemID: TADebugLiveFeedItem.ID) {
        guard itemID == filteredItems.last?.id else {
            return
        }

        setAutoScrollEnabled(false)
    }

    private func setAutoScrollEnabled(_ isEnabled: Bool) {
        guard autoScrollEnabled != isEnabled else {
            return
        }

        autoScrollEnabled = isEnabled
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "waveform.and.magnifyingglass" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty ? "Waiting for live events" : "No matching live events")
                .font(.headline)

            Text(searchText.isEmpty ? "New logs and analytics events will appear here in real time." : "Try a different search term or source filter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct TADebugLiveFeedRow: View {
    let item: TADebugLiveFeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(item.sourceTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.sourceID == TADebugLiveFeedSource.analyticsSourceID ? .blue : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill((item.sourceID == TADebugLiveFeedSource.analyticsSourceID ? Color.blue : Color.green).opacity(0.14))
                    )

                Spacer()

                Text(item.timestamp, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(item.message)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)

            if let metadataText = item.metadataText, !metadataText.isEmpty {
                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }
}
